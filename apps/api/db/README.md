# Database migrations

`migrations/` is append-only. Run migrations against Neon with the unpooled CI-only connection string, never from a Vercel request handler. Runtime code uses the pooled `DATABASE_URL` only.

The initial migration implements the Android MVP tables: identity/session records, profile/settings, activities, weekly plans, sessions/phases/events, reviews, and idempotency records.
