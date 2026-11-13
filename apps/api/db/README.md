# Database migrations

`migrations/` is append-only. Run migrations against Neon with the unpooled CI-only connection string, never from a Vercel request handler. Runtime code uses the pooled `DATABASE_URL` only.

To apply pending migrations locally or from protected CI:

```powershell
npm run db:migrate --workspace=@dream-force/api
```

The runner loads `apps/api/.env.local`, records each file and SHA-256 checksum in `schema_migrations`, and rejects changed applied migrations.

Verify the applied tables and key session index with:

```powershell
npm run db:verify --workspace=@dream-force/api
```

The initial migration implements the Android MVP tables: identity/session records, profile/settings, activities, weekly plans, sessions/phases/events, reviews, and idempotency records.
