# Dream Force — Google OAuth and Vercel Setup

This guide configures Android Google OAuth and deploys the Next.js API. Never add real credentials to a tracked file. The previously exposed database and Upstash values must be rotated before deployment.

## 1. Confirm the Android identity

The current Android application ID is:

| Google field | Dream Force value |
| --- | --- |
| Package name | `com.dreamforce.dream_force` |
| Debug signing certificate SHA-1 | Obtain in the next step |
| Release signing certificate SHA-1 | Obtain from the release keystore or Google Play App Signing |

The package name comes from `apps/mobile/android/app/build.gradle.kts`. It must match Google Cloud exactly.

## 2. Find the Android SHA-1

From PowerShell:

```powershell
Set-Location "D:\Mobile Apps\Dream Force\apps\mobile\android"
.\gradlew signingReport
```

Find the `Variant: debug` section and copy its `SHA1:` value. For the standard Flutter debug certificate, this equivalent command is:

```powershell
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

For a Play Store release using Play App Signing, copy the **App signing key certificate SHA-1** from Google Play Console → **Release** → **Setup** → **App integrity**. Register both debug and release certificates as separate Android OAuth clients. Google requires the Android package/SHA-1 pair for the client. [Google Cloud OAuth client guidance](https://support.google.com/cloud/answer/15549257) and [Google Play client authentication guidance](https://developers.google.com/android/guides/client-auth) describe this flow.

## 3. Create Google OAuth credentials

1. Open [Google Cloud Console](https://console.cloud.google.com/).
2. Create or select the dedicated Dream Force project.
3. Configure **Google Auth platform** branding, audience, support email, privacy-policy URL, and terms URL. Add test users while the app is in testing.
4. Open **Google Auth platform → Clients → Create client**.
5. Choose **Android**.
6. Enter the package name `com.dreamforce.dream_force` and paste the debug SHA-1. Create it.
7. Repeat step 4–6 for the release/Play App Signing SHA-1 before publishing.
8. Copy the Android client ID. It ends in `.apps.googleusercontent.com`.

Set this in the untracked `apps/api/.env.local` file:

```dotenv
GOOGLE_CLIENT_ID=your-android-client-id.apps.googleusercontent.com
GOOGLE_ISSUER=https://accounts.google.com
```

`GOOGLE_CLIENT_SECRET` is intentionally **not used** by Dream Force’s Android PKCE flow. Android is a public client: a secret embedded in an app would not be secret. Leave any such variable unset; do not create or ship an Android client secret.

Google requires the package name and SHA-1 when creating Android credentials, and production should use its production signing certificate. [Official Android OAuth instructions](https://developers.google.com/workspace/guides/create-credentials) explain the same console fields.

## 4. Create the remaining local environment values

From the repository root:

```powershell
Copy-Item .env.example apps/api/.env.local
```

Fill the new, untracked file:

| Variable | Where it comes from | Notes |
| --- | --- | --- |
| `DATABASE_URL` | Neon pooled connection string | API runtime only |
| `DATABASE_URL_UNPOOLED` | Neon direct connection string | CI migrations only; never Vercel runtime |
| `UPSTASH_REDIS_REST_URL`, `UPSTASH_REDIS_REST_TOKEN` | Upstash Redis REST dashboard | Rate limiting/idempotency |
| `QSTASH_TOKEN`, `QSTASH_CURRENT_SIGNING_KEY`, `QSTASH_NEXT_SIGNING_KEY` | Upstash QStash dashboard | Job publishing/signature verification |
| `GOOGLE_CLIENT_ID`, `GOOGLE_ISSUER` | Google Cloud, step 3 | Android PKCE client |
| `JWT_ACCESS_TOKEN_SECRET` | Generate locally | Random 32+ character secret |
| `ADMIN_SESSION_SECRET` | Generate locally | Independent random 32+ character secret |

Generate the two application secrets in PowerShell:

```powershell
1..2 | ForEach-Object { [Convert]::ToBase64String((1..48 | ForEach-Object { Get-Random -Maximum 256 })) }
```

## 5. Apply migrations before deploying

The migration runner is intentionally not implemented yet. Apply `apps/api/db/migrations/0001_android_mvp.sql` through a protected CI migration job using `DATABASE_URL_UNPOOLED`. Do not run the direct Neon URL in Vercel Functions and do not alter production tables manually.

## 6. Deploy the backend to Vercel

1. Push this repository to a private Git repository.
2. In Vercel, choose **Add New → Project** and import the repository.
3. Set **Root Directory** to `apps/api`.
4. Keep the detected **Next.js** framework preset.
5. Add every required variable from section 4 under **Settings → Environment Variables**. Use separate values for Development, Preview, and Production; use production-only credentials for Production.
6. Deploy. Vercel uses `apps/api/vercel.json`, which pins the Next.js framework, region, and API function duration.
7. After changing any variable, redeploy; environment updates apply to new deployments.

Vercel documents environment-specific variables and redeployment behavior in its [project settings guide](https://vercel.com/academy/vercel-foundations/vercel-settings).

### Optional CLI deployment

```powershell
npm install --global vercel
Set-Location "D:\Mobile Apps\Dream Force\apps\api"
vercel login
vercel link
vercel --prod
```

Enter environment values through the Vercel dashboard or `vercel env add`; never paste them into `vercel.json`.

## 7. Verify deployment

Replace `<deployment-url>` with the Vercel deployment URL:

```powershell
Invoke-RestMethod https://<deployment-url>/v1/health
Start-Process https://<deployment-url>/swagger
```

Expected health response:

```json
{ "status": "ok", "service": "dream-force-api" }
```

Swagger UI is available at `/swagger`, and the generated OpenAPI 3.1 document is available at `/openapi.json`. Swagger UI renders an OpenAPI document as interactive API documentation. [Swagger UI documentation](https://swagger.io/open-source/swagger-ui/) describes this integration.

## 8. Before real-user testing

- Confirm the production SHA-1 client is registered.
- Confirm the consent screen has production branding and policy links.
- Rotate any credentials that were previously exposed.
- Apply the production migration through CI.
- Provision one test admin with the script; do not add an admin by SQL or public signup.
- Test Google sign-in, token refresh, logout, and a `403 ADMIN_ROLE_REQUIRED` response for a standard user calling `/v1/admin/health`.
