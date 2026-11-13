# Dream Force — Agent Working Guide

## First read

Before implementing or changing behavior, read `Plan/README.md`, then the relevant source document in `Plan/`.

## Source-of-truth order

1. `Plan/PRODUCT_REQUIREMENTS.md` for product scope and acceptance criteria.
2. `Plan/TECHNICAL_REQUIREMENTS.md` for technical decisions.
3. `Plan/Backend Schema.md` for data schema and access control.
4. `Plan/Session State Machine Specification.md` for session/timer behavior. This document wins if another plan document conflicts on timer persistence.
5. `Plan/frontend_reference.html` for visual reference only; do not infer backend behavior from it.

## Implementation rules

- Preserve Clean Architecture: presentation/interface → application/use case → domain → infrastructure.
- Keep Next.js Route Handlers thin; do not place business rules or raw SQL in them.
- Use append-only migrations in `apps/api/db/migrations`; never modify an applied migration or manually alter production schema.
- Never commit secrets. Use `.env.local` locally and Vercel environment variables in deployed environments.
- Run relevant validation after each change: `npm run typecheck`, `npm run build`, and Flutter checks where applicable.
- Do not add Skip phase or Finish now actions. Session behavior must follow the state-machine specification.

## Delivery sequence

Follow `Plan/Implementation Plan.md`: Android MVP first, CRM second, iOS third.
