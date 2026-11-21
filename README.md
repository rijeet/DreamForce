# Dream Force

Android-first focus and planning app with a Flutter client and a Vercel-hosted Next.js API.

## Repository layout

- `apps/mobile` — Flutter Android application.
- `apps/api` — Next.js Route Handlers, Swagger UI, and future CRM.
- `apps/api/db/migrations` — append-only Neon PostgreSQL migrations.
- `packages/api-contract` — Zod API contracts.
- `Plan` — approved product, technical, design, backend, implementation, and deployment documents.
- `AGENTS.md` — concise source-of-truth and implementation guide for AI agents.

## Prerequisites

- Node.js 22+
- npm 10+
- Flutter 3.50+
- An Android emulator or device for the mobile application

## Run the API locally

From the repository root in PowerShell:

```powershell
npm install
Copy-Item .env.example apps/api/.env.local
```

Fill `apps/api/.env.local` with your local Neon, Upstash, Google OAuth, and JWT values. Do not put real values in `.env.example` or commit `.env.local`.

```powershell
npm run dev:api
```

Useful local URLs:

- API health: `http://localhost:3000/v1/health`
- OpenAPI JSON: `http://localhost:3000/openapi.json`
- Swagger UI: `http://localhost:3000/swagger`

Current production API: `https://dream-force-backend.vercel.app`  
Current production Swagger UI: `https://dream-force-backend.vercel.app/swagger`

Validate the backend before committing:

```powershell
npm run typecheck
npm run build
```

## Run the Android app

The app defaults to the deployed API at `https://dream-force-backend.vercel.app`, so a local backend is not required for ordinary device use. `API_BASE_URL` can override it for local development.

```powershell
Set-Location "D:\Mobile Apps\Dream Force\apps\mobile"
flutter pub get
flutter analyze
flutter test
flutter run
```

To explicitly select the deployed backend when launching:

```powershell
flutter run --dart-define=API_BASE_URL=https://dream-force-backend.vercel.app
```

For a local API on the same Wi-Fi network, replace the URL with the computer's LAN IP and API port (for example `http://192.168.0.102:3000`). Do not use `127.0.0.1` on a physical Android phone; it refers to the phone itself.

## Admin provisioning

After migrations are applied and `apps/api/.env.local` is configured, create an admin only with the protected script:

```powershell
$env:DREAM_FORCE_ADMIN_PASSWORD = "use-a-unique-long-password"
npm run provision:admin --workspace=@dream-force/api -- admin@example.com
Remove-Item Env:DREAM_FORCE_ADMIN_PASSWORD
```

There is no public admin registration or reset endpoint.

## Setup and deployment

Follow [Google OAuth and Vercel Setup.md](<Plan/Google OAuth and Vercel Setup.md>) for Android package/SHA-1 registration, OAuth configuration, local environment variables, Vercel deployment, and deployment verification.
