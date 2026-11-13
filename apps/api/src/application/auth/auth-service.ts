import { createHash, randomBytes, randomUUID } from 'node:crypto';

import { hash, verify } from '@node-rs/argon2';
import { SignJWT, createRemoteJWKSet, jwtVerify } from 'jose';

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

const accessTokenLifetimeSeconds = 15 * 60;
const refreshTokenLifetimeDays = 30;

function normalizeEmail(email: string) {
  return email.trim().toLowerCase();
}

function refreshTokenHash(token: string) {
  return createHash('sha256').update(token).digest();
}

function secretKey() {
  return new TextEncoder().encode(readServerEnvironment().JWT_ACCESS_TOKEN_SECRET);
}

async function accessTokenFor(user: AuthUser, sessionId: string) {
  return new SignJWT({ role: user.role, sid: sessionId })
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject(user.id)
    .setIssuer('dream-force-api')
    .setAudience('dream-force-mobile')
    .setIssuedAt()
    .setExpirationTime(`${accessTokenLifetimeSeconds}s`)
    .sign(secretKey());
}

async function issueSession(user: AuthUser): Promise<SessionTokens> {
  const sql = createDatabaseClient();
  const sessionId = randomUUID();
  const refreshToken = randomBytes(48).toString('base64url');
  const expiresAt = new Date(Date.now() + refreshTokenLifetimeDays * 86400 * 1000);

  await sql`
    INSERT INTO auth_sessions (id, user_id, refresh_token_hash, expires_at)
    VALUES (${sessionId}::uuid, ${user.id}::uuid, ${refreshTokenHash(refreshToken)}, ${expiresAt})
  `;

  return {
    accessToken: await accessTokenFor(user, sessionId),
    refreshToken,
    expiresIn: accessTokenLifetimeSeconds,
  };
}

export async function exchangeGoogleAuthorizationCode(input: {
  authorizationCode: string;
  codeVerifier: string;
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

  const jwks = createRemoteJWKSet(new URL('https://www.googleapis.com/oauth2/v3/certs'));
  const verified = await jwtVerify(tokenBody.id_token, jwks, {
    issuer: environment.GOOGLE_ISSUER,
    audience: environment.GOOGLE_CLIENT_ID,
  });
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
  });
  return issueSession(user);
}

async function findOrCreateGoogleUser(identity: {
  subject: string;
  email: string;
  displayName: string | null;
  avatarUrl: string | null;
}): Promise<AuthUser> {
  const sql = createDatabaseClient();
  const existing = (await sql`
    SELECT id, email, role, status FROM users WHERE google_subject = ${identity.subject} LIMIT 1
  `) as AuthUser[];
  if (existing[0]) return assertActive(existing[0]);

  const normalizedEmail = normalizeEmail(identity.email);
  const created = (await sql`
    WITH new_user AS (
      INSERT INTO users (email, email_normalized, email_verified_at, role, google_subject, display_name, avatar_url)
      VALUES (${identity.email}, ${normalizedEmail}, now(), 'user', ${identity.subject}, ${identity.displayName}, ${identity.avatarUrl})
      ON CONFLICT (google_subject) DO NOTHING
      RETURNING id, email, role, status
    ), new_profile AS (
      INSERT INTO user_profiles (user_id)
      SELECT id FROM new_user
    ), new_settings AS (
      INSERT INTO user_settings (user_id)
      SELECT id FROM new_user
    )
    SELECT id, email, role, status FROM new_user
  `) as AuthUser[];
  if (created[0]) return created[0];

  const raced = (await sql`
    SELECT id, email, role, status FROM users WHERE google_subject = ${identity.subject} LIMIT 1
  `) as AuthUser[];
  if (!raced[0]) throw new Error('Google user creation did not return a user');
  return assertActive(raced[0]);
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
  const rows = (await sql`
    SELECT sessions.id AS session_id, users.id, users.email, users.role, users.status
    FROM auth_sessions AS sessions
    JOIN users ON users.id = sessions.user_id
    WHERE sessions.refresh_token_hash = ${refreshTokenHash(refreshToken)}
      AND sessions.revoked_at IS NULL AND sessions.expires_at > now()
    LIMIT 1
  `) as (AuthUser & { session_id: string })[];
  const current = rows[0];
  if (!current) throw new AuthenticationError('REFRESH_TOKEN_INVALID');
  const replacementId = randomUUID();
  const revoked = (await sql`
    UPDATE auth_sessions
    SET revoked_at = now(), replaced_by_session_id = ${replacementId}::uuid
    WHERE id = ${current.session_id}::uuid AND revoked_at IS NULL
    RETURNING id
  `) as { id: string }[];
  if (!revoked[0]) throw new AuthenticationError('REFRESH_TOKEN_REPLAYED');

  const nextRefreshToken = randomBytes(48).toString('base64url');
  const expiresAt = new Date(Date.now() + refreshTokenLifetimeDays * 86400 * 1000);
  await sql`
    INSERT INTO auth_sessions (id, user_id, refresh_token_hash, expires_at)
    VALUES (${replacementId}::uuid, ${current.id}::uuid, ${refreshTokenHash(nextRefreshToken)}, ${expiresAt})
  `;
  const user = assertActive(current);
  return { accessToken: await accessTokenFor(user, replacementId), refreshToken: nextRefreshToken, expiresIn: accessTokenLifetimeSeconds };
}

export async function revokeRefreshToken(refreshToken: string) {
  const sql = createDatabaseClient();
  await sql`
    UPDATE auth_sessions SET revoked_at = now()
    WHERE refresh_token_hash = ${refreshTokenHash(refreshToken)} AND revoked_at IS NULL
  `;
}

export async function authenticateAccessToken(token: string) {
  const verified = await jwtVerify(token, secretKey(), {
    issuer: 'dream-force-api',
    audience: 'dream-force-mobile',
  });
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
  if (user.status !== 'active') throw new AuthenticationError('ACCOUNT_UNAVAILABLE');
  return user;
}

export class AuthenticationError extends Error {
  constructor(readonly code: string) {
    super(code);
  }
}
