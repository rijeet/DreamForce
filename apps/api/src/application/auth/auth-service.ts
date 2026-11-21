import { createHash, randomBytes, randomUUID } from 'node:crypto';

import { hash, verify } from '@node-rs/argon2';
import { SignJWT, createRemoteJWKSet, jwtVerify } from 'jose';

import { finalizeDueAccountDeletion } from '../account/account-deletion';
import { createDatabaseClient } from '../../infrastructure/database/neon';
import { readServerEnvironment } from '../../infrastructure/env';

export type UserRole = 'user' | 'admin';

type AuthUser = {
  id: string;
  email: string;
  role: UserRole;
  status: string;
};

export type SessionTokens = {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
};

function normalizeEmail(email: string) {
  return email.trim().toLowerCase();
}

function refreshTokenHashHex(token: string) {
  // Hex is decoded in SQL. Neon's HTTP driver does not round-trip a Node Buffer into bytea reliably.
  return createHash('sha256').update(token).digest('hex');
}

function secretKey() {
  return new TextEncoder().encode(readServerEnvironment().JWT_ACCESS_TOKEN_SECRET);
}

async function accessTokenFor(user: AuthUser, sessionId: string) {
  const lifetimeSeconds = readServerEnvironment().JWT_ACCESS_TOKEN_TTL_SECONDS;
  return new SignJWT({ role: user.role, sid: sessionId })
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject(user.id)
    .setIssuer('dream-force-api')
    .setAudience('dream-force-mobile')
    .setIssuedAt()
    .setExpirationTime(`${lifetimeSeconds}s`)
    .sign(secretKey());
}

async function issueSession(user: AuthUser): Promise<SessionTokens> {
  const sql = createDatabaseClient();
  const environment = readServerEnvironment();
  const sessionId = randomUUID();
  const refreshToken = randomBytes(48).toString('base64url');
  const expiresAt = new Date(Date.now() + environment.JWT_REFRESH_TOKEN_TTL_DAYS * 86400 * 1000);

  await sql`
    INSERT INTO auth_sessions (id, user_id, refresh_token_hash, expires_at)
    VALUES (${sessionId}::uuid, ${user.id}::uuid, decode(${refreshTokenHashHex(refreshToken)}, 'hex'), ${expiresAt})
  `;

  return {
    accessToken: await accessTokenFor(user, sessionId),
    refreshToken,
    expiresIn: environment.JWT_ACCESS_TOKEN_TTL_SECONDS,
  };
}

export async function exchangeGoogleAuthorizationCode(input: {
  authorizationCode: string;
  codeVerifier: string;
  timezone?: string;
  termsAcceptedVersion: string;
  screenTimeConsentVersion?: string;
}): Promise<SessionTokens> {
  const environment = readServerEnvironment();
  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      code: input.authorizationCode,
      code_verifier: input.codeVerifier,
      client_id: environment.GOOGLE_CLIENT_ID,
      grant_type: 'authorization_code',
    }),
  });

  if (!tokenResponse.ok) throw new AuthenticationError('GOOGLE_CODE_REJECTED');
  const tokenBody = (await tokenResponse.json()) as { id_token?: string };
  if (!tokenBody.id_token) throw new AuthenticationError('GOOGLE_ID_TOKEN_MISSING');

  return signInWithGoogleIdToken(tokenBody.id_token, {
    timezone: input.timezone,
    termsAcceptedVersion: input.termsAcceptedVersion,
    screenTimeConsentVersion: input.screenTimeConsentVersion,
  });
}

/** Verifies a native Android Google ID token before issuing Dream Force tokens. */
export async function signInWithGoogleIdToken(idToken: string, preferences: { timezone?: string; termsAcceptedVersion: string; screenTimeConsentVersion?: string }): Promise<SessionTokens> {
  // Country and time zone are fixed for every account. preferences.timezone is ignored.
  const environment = readServerEnvironment();
  const jwks = createRemoteJWKSet(new URL('https://www.googleapis.com/oauth2/v3/certs'));
  let verified;
  try {
    verified = await jwtVerify(idToken, jwks, {
      issuer: environment.GOOGLE_ISSUER,
      audience: environment.GOOGLE_CLIENT_ID,
    });
  } catch (error) {
    const code = error && typeof error === 'object' && 'code' in error ? String(error.code) : '';
    if (code === 'ERR_JWT_EXPIRED') throw new AuthenticationError('GOOGLE_TOKEN_EXPIRED');
    if (code === 'ERR_JWT_CLAIM_VALIDATION_FAILED') {
      const claim = error && typeof error === 'object' && 'claim' in error ? String(error.claim) : '';
      throw new AuthenticationError(claim === 'aud' ? 'GOOGLE_AUDIENCE_MISMATCH' : 'GOOGLE_ISSUER_MISMATCH');
    }
    throw new AuthenticationError('GOOGLE_TOKEN_INVALID');
  }
  const subject = verified.payload.sub;
  const email = verified.payload.email;
  const emailVerified = verified.payload.email_verified === true;
  if (!subject || typeof email !== 'string' || !emailVerified) {
    throw new AuthenticationError('GOOGLE_IDENTITY_INVALID');
  }

  const user = await findOrCreateGoogleUser({
    subject,
    email,
    displayName: typeof verified.payload.name === 'string' ? verified.payload.name : null,
    avatarUrl: typeof verified.payload.picture === 'string' ? verified.payload.picture : null,
    termsAcceptedVersion: preferences.termsAcceptedVersion,
    screenTimeConsentVersion: preferences.screenTimeConsentVersion,
  });
  return issueSession(user);
}

async function findOrCreateGoogleUser(identity: {
  subject: string;
  email: string;
  displayName: string | null;
  avatarUrl: string | null;
  termsAcceptedVersion: string;
  screenTimeConsentVersion?: string;
}): Promise<AuthUser> {
  const sql = createDatabaseClient();
  const existing = (await sql`
    SELECT id, email, role, status FROM users WHERE google_subject = ${identity.subject} LIMIT 1
  `) as AuthUser[];
  if (existing[0] && !(await finalizeDueAccountDeletion(existing[0].id))) {
    await pinFixedProfile(existing[0].id);
    await saveGoogleConsent(existing[0].id, identity);
    return assertActive(existing[0]);
  }

  const normalizedEmail = normalizeEmail(identity.email);
  const created = (await sql`
    WITH new_user AS (
      INSERT INTO users (email, email_normalized, email_verified_at, role, google_subject, display_name, avatar_url)
      VALUES (${identity.email}, ${normalizedEmail}, now(), 'user', ${identity.subject}, ${identity.displayName}, ${identity.avatarUrl})
      ON CONFLICT (google_subject) DO NOTHING
      RETURNING id, email, role, status
    ), new_profile AS (
      INSERT INTO user_profiles (user_id, country, timezone)
      SELECT id, 'Bangladesh', 'Asia/Dhaka' FROM new_user
    ), new_settings AS (
      INSERT INTO user_settings (user_id)
      SELECT id FROM new_user
    )
    SELECT id, email, role, status FROM new_user
  `) as AuthUser[];
  if (created[0]) {
    await saveGoogleConsent(created[0].id, identity);
    return created[0];
  }

  const raced = (await sql`
    SELECT id, email, role, status FROM users WHERE google_subject = ${identity.subject} LIMIT 1
  `) as AuthUser[];
  if (!raced[0]) throw new Error('Google user creation did not return a user');
  if (await finalizeDueAccountDeletion(raced[0].id)) {
    return findOrCreateGoogleUser(identity);
  }
  await pinFixedProfile(raced[0].id);
  await saveGoogleConsent(raced[0].id, identity);
  return assertActive(raced[0]);
}

async function pinFixedProfile(userId: string) {
  await createDatabaseClient()`
    UPDATE user_profiles
    SET country = 'Bangladesh', timezone = 'Asia/Dhaka'
    WHERE user_id = ${userId}::uuid
  `;
}

async function saveGoogleConsent(userId: string, identity: { termsAcceptedVersion: string; screenTimeConsentVersion?: string }) {
  await createDatabaseClient()`
    UPDATE user_settings SET
      terms_accepted_version=COALESCE(${identity.termsAcceptedVersion ?? null}, terms_accepted_version),
      terms_accepted_at=CASE WHEN ${Boolean(identity.termsAcceptedVersion)} THEN now() ELSE terms_accepted_at END,
      screen_time_sync_enabled=CASE WHEN ${Boolean(identity.screenTimeConsentVersion)} THEN true ELSE screen_time_sync_enabled END,
      screen_time_consent_version=COALESCE(${identity.screenTimeConsentVersion ?? null}, screen_time_consent_version),
      screen_time_consent_at=CASE WHEN ${Boolean(identity.screenTimeConsentVersion)} THEN now() ELSE screen_time_consent_at END,
      screen_time_sync_revoked_at=CASE WHEN ${Boolean(identity.screenTimeConsentVersion)} THEN NULL ELSE screen_time_sync_revoked_at END
    WHERE user_id=${userId}::uuid
  `;
}

export async function signInAdmin(email: string, password: string): Promise<SessionTokens> {
  const sql = createDatabaseClient();
  const rows = (await sql`
    SELECT id, email, role, status, password_hash
    FROM users
    WHERE email_normalized = ${normalizeEmail(email)} AND role = 'admin'
    LIMIT 1
  `) as (AuthUser & { password_hash: string | null })[];
  const user = rows[0];
  if (!user || !user.password_hash || !(await verify(user.password_hash, password))) {
    throw new AuthenticationError('ADMIN_CREDENTIALS_INVALID');
  }
  return issueSession(assertActive(user));
}

export async function rotateRefreshToken(refreshToken: string): Promise<SessionTokens> {
  const sql = createDatabaseClient();
  const environment = readServerEnvironment();
  const rows = (await sql`
    SELECT sessions.id AS session_id, users.id, users.email, users.role, users.status
    FROM auth_sessions AS sessions
    JOIN users ON users.id = sessions.user_id
    WHERE sessions.refresh_token_hash = decode(${refreshTokenHashHex(refreshToken)}, 'hex')
      AND sessions.revoked_at IS NULL AND sessions.expires_at > now()
    LIMIT 1
  `) as (AuthUser & { session_id: string })[];
  const current = rows[0];
  if (!current) throw new AuthenticationError('REFRESH_TOKEN_INVALID');
  if (await finalizeDueAccountDeletion(current.id)) throw new AuthenticationError('ACCOUNT_UNAVAILABLE');
  const replacementId = randomUUID();
  const nextRefreshToken = randomBytes(48).toString('base64url');
  const expiresAt = new Date(Date.now() + environment.JWT_REFRESH_TOKEN_TTL_DAYS * 86400 * 1000);
  const rotated = (await sql`
    WITH revoked AS (
      UPDATE auth_sessions
      SET revoked_at = now()
      WHERE id = ${current.session_id}::uuid AND revoked_at IS NULL
      RETURNING user_id
    ), replacement AS (
      INSERT INTO auth_sessions (id, user_id, refresh_token_hash, expires_at)
      SELECT ${replacementId}::uuid, user_id, decode(${refreshTokenHashHex(nextRefreshToken)}, 'hex'), ${expiresAt}
      FROM revoked
      RETURNING id
    ), linked AS (
      UPDATE auth_sessions AS old_session
      SET replaced_by_session_id = replacement.id
      FROM replacement
      WHERE old_session.id = ${current.session_id}::uuid
      RETURNING old_session.id
    )
    SELECT id FROM linked
  `) as { id: string }[];
  if (!rotated[0]) throw new AuthenticationError('REFRESH_TOKEN_REPLAYED');
  const user = assertActive(current);
  return { accessToken: await accessTokenFor(user, replacementId), refreshToken: nextRefreshToken, expiresIn: environment.JWT_ACCESS_TOKEN_TTL_SECONDS };
}

export async function revokeRefreshToken(refreshToken: string) {
  const sql = createDatabaseClient();
  await sql`
    UPDATE auth_sessions SET revoked_at = now()
    WHERE refresh_token_hash = decode(${refreshTokenHashHex(refreshToken)}, 'hex') AND revoked_at IS NULL
  `;
}

export async function authenticateAccessToken(token: string) {
  let verified;
  try {
    verified = await jwtVerify(token, secretKey(), {
      issuer: 'dream-force-api',
      audience: 'dream-force-mobile',
    });
  } catch (error) {
    const code = error && typeof error === 'object' && 'code' in error
      ? String(error.code)
      : '';
    throw new AuthenticationError(
      code === 'ERR_JWT_EXPIRED' ? 'ACCESS_TOKEN_EXPIRED' : 'ACCESS_TOKEN_INVALID',
    );
  }
  const role = verified.payload.role;
  if (!verified.payload.sub || (role !== 'user' && role !== 'admin')) {
    throw new AuthenticationError('ACCESS_TOKEN_INVALID');
  }
  return { userId: verified.payload.sub, role, sessionId: verified.payload.sid };
}

export async function provisionAdmin(email: string, password: string) {
  const sql = createDatabaseClient();
  const passwordHash = await hash(password, { algorithm: 2 });
  const normalizedEmail = normalizeEmail(email);
  const rows = (await sql`
    WITH new_user AS (
      INSERT INTO users (email, email_normalized, email_verified_at, role, password_hash)
      VALUES (${email}, ${normalizedEmail}, now(), 'admin', ${passwordHash})
      RETURNING id, email, role, status
    ), new_profile AS (INSERT INTO user_profiles (user_id) SELECT id FROM new_user),
    new_settings AS (INSERT INTO user_settings (user_id) SELECT id FROM new_user)
    SELECT id, email, role, status FROM new_user
  `) as AuthUser[];
  return rows[0];
}

function assertActive(user: AuthUser): AuthUser {
  if (user.status !== 'active' && user.status !== 'deletion_pending') {
    throw new AuthenticationError('ACCOUNT_UNAVAILABLE');
  }
  return user;
}

export class AuthenticationError extends Error {
  constructor(readonly code: string) {
    super(code);
  }
}
