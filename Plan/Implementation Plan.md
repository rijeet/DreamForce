# Implementation Plan: Dream Force

**Delivery order:** Android MVP → Admin CRM → iOS  
**Scope rule:** Build the smallest usable version first. Do not start the next phase until the current phase passes its validation checks.

## Rules for the agent

- Build one step at a time.
- After each step, run the relevant app/service checks and confirm the acceptance criteria before moving on.
- Keep the implementation aligned with `TECHNICAL_REQUIREMENTS.md`, `Backend Schema.md`, `PRODUCT_REQUIREMENTS.md`, `UI-UX DesignBrief.md`, and `3. App Flow.md`.
- Do not add features outside the current phase.
- Use Clean Architecture: presentation → application/use case → domain → infrastructure. Route handlers and widgets must not contain business rules or direct database access.
- Use migrations for every persistent-schema change; never change production data manually.
- Preserve privacy boundaries: raw Android app usage remains local; Top 10 app reporting uses only explicit-consent, non-identifiable daily aggregates.

## Phase 1 — Android MVP

### Step 1. Repository and project setup

Create the monorepo, Flutter Android app, Next.js Vercel API, shared OpenAPI contract package, CI, linting, formatting, environment templates, and Clean Architecture folders.

**Validate:**

- Flutter Android app launches on an emulator.
- API health route returns `200` locally.
- CI runs formatter, static analysis, and unit-test commands.
- No production secrets are committed.

### Step 2. Serverless database and infrastructure

Create Neon PostgreSQL, Upstash Redis, Upstash QStash, Vercel project configuration, and migration tooling. Apply the minimal Android-MVP schema: users, profiles, settings, sessions, templates, plans, reviews, idempotency, and auth sessions.

**Validate:**

- Migrations apply cleanly to an empty database and are repeatable in CI.
- Required indexes and the one-open-session constraint exist.
- Vercel environment variables are configured separately for development, preview, and production.
- Redis rate-limit test and QStash signature-verification test pass.
- The session state-machine migration and OpenAPI contract pass their schema tests before timer code begins.

### Step 3. Authentication and roles

Implement Google OIDC with PKCE for standard users. Create the protected admin provisioning script, which creates only `role = admin` users with Argon2id password hashes. Implement JWT access tokens, refresh-token rotation, logout, middleware, and RBAC guards. Use a queued, single-flight Dio refresh flow.

**Validate:**

- New Google user receives role `user` and cannot access `/admin/*` routes.
- Provisioned admin can authenticate and access a guarded admin health route.
- Invalid/expired/rotated token is rejected.
- Password, refresh token, and Google credential never appear in logs.

### Step 4. Android app shell and design system

Implement the Flutter design tokens, light/dark theme, shared cards, buttons, fields, navigation, and floating action button from the Design Brief. Build Today, Plan, Insights (Activity only), and Profile shell routes.

**Validate:**

- App works at 320 logical-pixel width and the standard Android test device size.
- Bottom navigation and FAB route correctly; FAB opens Choose activity.
- Light/dark/system theme selections render with readable contrast.
- Screen-reader labels exist for navigation, FAB, and icon-only controls.

### Step 5. Activities and automatic timer

Build Choose activity, Create activity, reusable activity templates, automatic focus/rest schedule generation, active timer, pause/resume, automatic phase transitions, session completion, and Delete-session confirmation, using `Session State Machine Specification.md` as the source of truth. Do not implement Skip phase or Finish now.

**Validate:**

- A user creates an activity with name, icon, and duration only.
- A 60-minute session generates 50 minutes focus and 10 minutes rest.
- A 90-minute session generates 40/5 + 40/5 and shows long-rest recommendation after completion.
- Pause/resume survives app backgrounding and process restart within the target recovery time.
- Delete session requires confirmation and records `cancelled`, preserving elapsed time.
- A second active session is rejected or returns the user to the existing session.

### Step 6. Weekly plan and daily review

Build weekly-plan create/edit flows, selected-day entries, add activity, reorder, optional local start time, skip planned occurrence, and daily review.

**Validate:**

- Plan edits affect future occurrences only.
- A plan can add an existing activity and preserve selected duration/time.
- A daily review saves with zero completed activities.
- Offline review/plan writes queue locally and sync after connectivity returns.

### Step 7. Android notifications and local screen-time insights

Add Android foreground/ongoing timer notification and phase-completion local notifications. Validate Android 14+/15 foreground-service declaration and Play policy suitability. Add Android Usage Access explanation, on-device `UsageEvents` reconstruction over local calendar-day boundaries, Activity Insights, Screen Time Insights, heatmap, yearly/quarter navigation, and local-only clear-history action.

**Validate:**

- Timer remains usable if notification permission is denied.
- Usage Access decline/revocation does not affect timer, plans, or reviews.
- Screen-time data stays encrypted on device; no raw package name/duration appears in API logs or network payloads.
- Insights period selectors, heatmap selection, and app/category breakdowns update correctly.

### Step 8. Android MVP quality pass and beta deployment

Run unit, widget, API integration, migration, authorization, offline, and Android emulator/device tests. Fix blockers, publish a closed Android beta, and deploy the Vercel API production environment.

**Validate:**

- Core user journeys from App Flow pass end-to-end.
- API authorization, idempotency, and rate-limit tests pass.
- Database restore/migration smoke test passes.
- No critical crash, data-loss, privacy, or authorization defect remains.

## Phase 2 — Admin CRM

### Step 9. Admin CRM API and audit foundation

Add role-gated admin use cases/routes, support tickets/messages, audit records, global activity templates, weekly-plan templates, notification campaigns, notification deliveries, and daily aggregate activity tables.

**Validate:**

- Standard user receives `403` for every admin route.
- Admin can create, assign, reply to, resolve, and close a ticket.
- Internal ticket notes never appear in user responses.
- Admin-created templates are publishable and copied into, not shared with, a user’s plan.

### Step 10. Admin CRM interface

Build the role-gated Admin CRM dashboard: Overview, Tickets, Templates, and Notify. Include day/week/month/year filters, aggregate completed focus time, active users, top performers, ticket status, and campaign status.

**Validate:**

- Admin dashboard renders only after verified admin authorization.
- Metrics are aggregate-only; private review text and profile details are absent.
- Top performers use the approved minimal/pseudonymous presentation.
- Ticket resolution and template publication update UI state correctly.

### Step 11. Notification campaigns and Top 10 app aggregates

Use QStash for signed, idempotent campaign delivery jobs. Add explicit default-off Android analytics consent for anonymous daily app aggregates; aggregate reports support day/week/month/year Top 10 Apps.

**Validate:**

- Campaign sends respect user notification preference and OS permission.
- QStash duplicate delivery cannot duplicate a notification-delivery record.
- Users who do not opt in contribute no app data.
- CRM cannot query an individual app timeline, installed-app list, user ID, or device ID from Top 10 data.

## Phase 3 — iOS

### Step 12. iOS shell, authentication, and core flows

Enable the Flutter iOS target, Google OIDC flow, theme/navigation, activities, timer, weekly plan, review, profile, and Activity Insights.

**Validate:**

- Core user journeys work on supported iOS simulator/device versions.
- Secure token storage uses Keychain.
- iOS behavior meets the same authorization, offline, and recovery checks as Android MVP.

### Step 13. iOS timer surfaces and release readiness

Implement ActivityKit/WidgetKit Live Activity where supported, fallback in-app timer behavior, notification handling, accessibility, TestFlight deployment, and release review.

**Validate:**

- Timer remains fully usable when Live Activities or notification permission is unavailable.
- No Android Usage Access, Screen Time, or Top 10 app UI is shipped on iOS.
- TestFlight smoke tests, privacy review, accessibility review, and production rollback plan are complete.

## Done when

- **Step 1:** Android app/API scaffold builds and CI is green.
- **Step 2:** Neon/Upstash/Vercel infrastructure and schema migrations are verified.
- **Step 3:** Google users and script-provisioned admins authenticate with correct RBAC.
- **Step 4:** Shared Android UI shell matches the Design Brief and routes work.
- **Step 5:** Automatic focus/rest timer works, recovers, and supports Pause/Resume/Delete only.
- **Step 6:** Plans and daily reviews sync safely, including offline cases.
- **Step 7:** Android notification and local screen-time features pass privacy checks.
- **Step 8:** Android MVP is deployed to closed beta with no critical defects.
- **Step 9:** CRM data/actions are role-gated and auditable.
- **Step 10:** Admin CRM supports tickets, templates, monitoring, and campaign operations.
- **Step 11:** Notifications and opt-in aggregate Top 10 reporting work without individual monitoring.
- **Step 12:** iOS supports all shared core user features.
- **Step 13:** iOS release candidate passes platform, privacy, and accessibility checks.
