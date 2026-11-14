# Dream Force — Technical Requirements Document

**Status:** Technical baseline — v1  
**Date:** 12 November 2026  
**Companion document:** `PRODUCT_REQUIREMENTS.md`  
**Audience:** Mobile, backend, platform, QA, security, and DevOps engineers

## 1. Purpose and decision record

This document locks the implementation choices for the Dream Force MVP. Product behavior, API payload examples, and the logical data model remain defined by the PRD; this document specifies how those requirements are built and operated.

### Locked decisions

| Area | Decision |
| --- | --- |
| Mobile app | Flutter and Dart, one shared codebase for Android and iOS |
| State management | Riverpod with immutable feature state and repository interfaces |
| Navigation | `go_router`, using declarative routes and deep-link support |
| HTTP client | Dio with token and idempotency interceptors |
| Local persistence | Drift over encrypted SQLite; platform key storage protects the database key and OAuth tokens |
| Backend | TypeScript on Node.js LTS, Vercel Functions using Next.js Route Handlers, Zod request/response validation, and Clean Architecture |
| API contract | REST JSON at `/v1`, described by OpenAPI 3.1; generated client models only |
| Identity | Google OIDC authorization-code flow with PKCE for standard users; script-provisioned email/password credentials for admins; role-based authorization in every use case |
| Primary database | Neon serverless PostgreSQL using the Backend Schema and versioned migration files |
| Cache / idempotency | Upstash Redis over its REST client; PostgreSQL remains the durable source of truth |
| Background jobs | Upstash QStash invokes protected Vercel job routes for exports, deletion workflow, retryable notifications, and cleanup |
| Hosting | Vercel Functions with Fluid Compute, Vercel Cron, managed secrets, centralized logs, Neon PostgreSQL, Upstash Redis/QStash, and object storage |
| Android app usage | Android `UsageStatsManager`; encrypted device cache plus optional owner-private daily aggregates in Neon after versioned consent and Android Usage Access; no raw timeline; admins cannot read per-user usage |
| iOS external app usage | Not implemented in this release |

Every dependency must be pinned in its lockfile. The team chooses the current supported stable release at project bootstrap and records exact versions in the repository’s `docs/versions.md`; this TRD deliberately does not freeze transient package versions.

## 2. System architecture

```text
Flutter mobile app
 ├─ Domain timer and plan logic
 ├─ Encrypted local database / offline outbox
 ├─ Google OIDC SDK and secure token storage
 ├─ Android: UsageStats + notification/foreground execution
 └─ iOS: ActivityKit / WidgetKit
             │ HTTPS + OAuth bearer token
             ▼
Vercel Functions (Route Handlers)
 ├─ Clean Architecture application/use-case layer
 ├─ Neon PostgreSQL (durable relational records)
 ├─ Upstash Redis (rate limits, idempotency, short-lived cache)
 └─ Upstash QStash → protected Vercel job routes → object storage / notification provider
```

The timer is client-authoritative for live presentation and offline recovery. The API validates legal state transitions and stores an audit-quality session history; it does not drive a per-second timer loop.

## 3. Repository layout

```text
dream-force/
├─ apps/mobile/                 # Flutter application
├─ apps/api/                    # Next.js Route Handlers deployed to Vercel
├─ packages/api-contract/       # OpenAPI source and generated models
├─ packages/domain/             # shared TypeScript domain schemas where useful
├─ infra/                       # IaC, deployment definitions, monitoring
├─ docs/                        # ADRs, runbooks, exact dependency versions
└─ Plan/PRODUCT_REQUIREMENTS.md
```

The mobile app is feature-oriented: `auth`, `profile`, `activities`, `plans`, `timer`, `reviews`, and `insights`. Each feature has presentation, application, domain, and data layers. Platform code is isolated behind Dart interfaces so Android-only usage tracking cannot leak into the iOS build.

The backend follows the same dependency direction: `domain` contains entities and repository ports; `application` contains use cases; `infrastructure` implements Neon, Upstash, Google OIDC, Argon2id admin credentials, object storage, and notification adapters; `interfaces/http` contains thin Route Handlers and Zod DTO mapping. Route Handlers must not contain domain logic or direct SQL.

## 4. Mobile requirements

### 4.1 Required packages and tools

- Flutter stable and Dart stable, managed with FVM in CI and developer setup.
- Riverpod, `go_router`, Dio, Freezed/JSON serialization, Drift, and `flutter_secure_storage`.
- Google’s supported Flutter identity SDK for OIDC sign-in.
- `flutter_local_notifications` with a native Android foreground-service integration.
- Native Swift/Objective-C bridge for iOS ActivityKit/WidgetKit; native Kotlin bridge for Android UsageStats and notification channels.
- `flutter_test`, `integration_test`, and Maestro for end-to-end smoke tests.

### 4.2 Timer and automatic scheduling

The schedule generator accepts only total duration and produces immutable phase entries before a session starts.

- Standard allocation: `focus_seconds = round(total_seconds * 5 / 6)` and `rest_seconds = total_seconds - focus_seconds`; the two values always sum exactly to the chosen total. Phase transitions and final completion are automatic; the user cannot skip a phase or finish early.
- Special 90-minute allocation: focus 40 minutes, rest 5 minutes, focus 40 minutes, rest 5 minutes.
- After a completed 90-minute session, show a dismissible 20–30 minute long-rest recommendation.
- Persist the generated phase schedule with the local session and the session-start API request. Future algorithm updates must never change historical sessions.
- Countdown rendering derives from persisted target timestamps plus monotonic elapsed time; periodic callbacks are never the only clock.

### 4.3 Offline synchronization

- All writes receive a local UUID and an outbox entry before network submission.
- Retry order is deterministic per resource. Session events are append-only and idempotent; mutable templates, plans, profile data, and reviews use a version/ETag. Dio uses a `QueuedInterceptor` and single-flight refresh operation so concurrent 401 responses cannot race refresh-token rotation or cause outbox deadlock.
- Show “Saved on this device; sync pending” until the server acknowledges a write.
- Reconcile authentication failure by pausing protected synchronization, not deleting local data.

### 4.4 Platform integrations

**Android:** Use a foreground service only while a timer session needs it and present a user-visible ongoing notification. Declare and justify the exact Android 14+/15 foreground-service type in the manifest and Play policy submission before release; validate the choice against the target SDK and current policy. Use a local notification for phase completion, respecting system notification permissions. Screen-time collection requires Android Usage Access. The Kotlin bridge queries Android's calendar-aligned `UsageStatsManager.INTERVAL_DAILY` aggregates and stores daily app totals locally. A separate versioned account-sync consent is required before uploading `(local_date, timezone_id, package_name, app_label, usage_seconds)` records to the signed-in user's account. Do not upload raw foreground events or timelines. CRM Top 10 remains a separate anonymous analytics consent and aggregate.

**iOS:** Use Live Activities when supported and authorized. Keep an in-app timer fully functional when Live Activities or notification permission is unavailable. Do not expose other-app screen-time features on iOS.

## 5. Backend requirements

### 5.1 API service

- Next.js Route Handlers deployed as Vercel Functions expose JSON-only HTTPS endpoints under `/v1`.
- Zod validates all inputs and serializes known response shapes; unknown writable properties are rejected.
- Zod schemas are the contract source. Generate OpenAPI 3.1 with `@asteasolutions/zod-to-openapi` in CI, reject contract drift, and generate Freezed Dart DTOs into `packages/api-contract`; generated files are never hand-edited.
- Authentication middleware validates issuer, audience, signature, expiry, nonce/authorized party where applicable, maps the Google subject to `users.google_subject`, and validates the separate Argon2id-admin session cookie.
- Authorization occurs in every query scope; a client-supplied `user_id` is never trusted.
- Use RFC 9457 `application/problem+json` for errors with a stable application `code` and request ID.

### 5.2 API catalogue

| Resource | Required endpoints |
| --- | --- |
| Profile | `GET /me`, `PATCH /me`, `GET /user-profile`, `PATCH /user-profile`, `DELETE /me` |
| Activities | `GET/POST /activity-templates`, `GET/PATCH/DELETE /activity-templates/{id}` |
| Weekly plans | `GET/POST /plans`, `GET/PUT /plans/{id}`, `GET /plan-occurrences`, `PATCH /plan-occurrences/{id}` |
| Sessions | `POST /sessions`, `GET /sessions/{id}`, `POST /sessions/{id}/events` for `pause`, `resume`, or `cancel`; completion is generated automatically |
| Reviews | `GET/PUT /daily-reviews/{localDate}`, `DELETE /daily-reviews/{localDate}` |
| Account | `POST /exports`, `GET /exports/{id}`, `POST /account-deletion` |
| Admin CRM | `GET /admin/overview`, `GET/PATCH /admin/tickets/{id}`, `POST /admin/templates/activity`, `POST /admin/templates/weekly-plan`, `POST /admin/notification-campaigns`, `GET /admin/top-apps` |

`POST /sessions`, session event submission, exports, and deletion requests require an `Idempotency-Key`. Writes to mutable resources require `If-Match` or a version field and return `412 Precondition Failed` for a stale mutation.

### 5.3 Background work

Upstash QStash delivers signed requests to protected Vercel job routes for account exports, staged account deletion, delivery retries, expired-export cleanup, and retention cleanup. Vercel Cron triggers scheduled cleanup routes. Each job must be idempotent, verify the `Upstash-Signature` with the QStash Receiver against the raw request body before JSON parsing, use ID-only payloads, emit structured job logs, and use finite retries/dead-letter handling. Do not depend on in-memory queues, long-lived WebSocket sessions, or a permanently running worker.

## 6. Data and storage

### 6.1 PostgreSQL

- Use Neon PostgreSQL migrations only; never alter production schema manually. Runtime traffic uses Neon’s pooled/serverless connection endpoint; direct unpooled connections are restricted to CI migration tooling.
- Enforce ownership, uniqueness, foreign keys, checks, and indexes from the PRD schema.
- Use UUID primary keys and `timestamptz` for instants. Weekly plans additionally store IANA timezones and local dates/times. Materialize recurring occurrences lazily for the requested range (maximum rolling 14 days), resolving local date/time with Luxon or `date-fns-tz` on the server and the Dart `timezone` package on mobile. Test spring-forward gaps and fall-back ambiguities; never precompute unbounded future UTC timestamps.
- Store user-specific profile details in `user_profiles` with one row per `app_user`.
- Activity icons are stable `icon_key` values, never image binaries in the relational database.
- Store export archives in encrypted object storage with short-lived signed download URLs.

### 6.2 Local mobile data

Encrypted SQLite stores cached API resources, active-session recovery state, outbox items, and Android usage aggregates. Google tokens, admin/user session tokens, encryption keys, and database-key material belong in Android Keystore or iOS Keychain only. Android disables backups for the encrypted database (`android:allowBackup="false"`, `android:fullBackupContent="false"`). If key material is invalidated or decryption fails (for example `AEADBadTagException`), preserve recoverable auth state when possible, delete only the unreadable local database, re-create it, and resync; never loop on an unreadable key. Clearing local Android usage history removes device rows; cloud rows are separate and are deleted when screen-time sync is revoked or the account is deleted.

## 7. Security and privacy

- HTTPS only; HSTS at the edge; no secrets in mobile binaries, source control, logs, or crash reports.
- Google OAuth uses PKCE and platform-supported browser/app flows; the app never handles a Google password. Admin credentials are created only by a protected provisioning script, stored as Argon2id hashes, rate-limited, and never exposed through public registration.
- Encrypt data at rest through managed service encryption and encrypt mobile local storage. Rotate secrets using a managed secret store.
- Rate-limit sign-in callback validation, session creation, exports, account deletion, and other write-heavy operations.
- Redact access tokens, email, profile fields, review text, Android package names, and usage totals from application logs and telemetry.
- Profile gender and date of birth are optional, private, and excluded from notifications, support tooling, analytics, and lock-screen content by default.
- Per-user Android usage uploads are disabled by default and require versioned affirmative consent plus Android Usage Access. Only local-day per-app aggregates are stored; no raw event timeline is uploaded. Revoking sync blocks future writes and deletes that user's uploaded rows. Admins and support cannot read these rows. CRM Top 10 remains a separately consented, anonymous aggregate.
- Follow the OWASP API Security Top 10 as a release threat-model checklist.

## 8. Observability and operations

- Structured JSON logs include timestamp, service, environment, request ID, route, status, duration, and error code; they must omit private content.
- Publish metrics for request rate, p50/p95 latency, error rate, database pool saturation, queue depth/failure, outbox backlog, and session-recovery failures.
- Alert on API availability, elevated 5xx rate, failed migrations, QStash delivery/dead-letter failures, backup failure, and abnormal authentication verification failures.
- Daily encrypted backups target an RPO of 24 hours and RTO of 8 hours. Restore tests occur at least quarterly.
- Use separate development, staging, and production accounts/projects. Production data cannot be copied into ordinary test environments.

## 9. Quality gates

| Layer | Required checks |
| --- | --- |
| Mobile | analyzer, formatter, unit tests, widget tests, integration tests, accessibility semantics review |
| API | TypeScript checks, lint, unit/integration tests, OpenAPI validation, authentication/authorization tests |
| Database | migration-up/down test where possible, schema constraint tests, query-plan checks for indexed paths |
| End-to-end | Google sign-in mock flow, script-provisioned admin login, RBAC denial, offline session recovery, idempotent session creation, plan conflict, profile save, CRM ticket workflow, notification campaign delivery, Android Usage Access declined/granted/revoked |
| Security | dependency vulnerability scanning, secret scanning, SAST, API authorization regression suite |
| Release | staged rollout, crash-free threshold, smoke tests, rollback-ready immutable image |

CI blocks a merge when formatting, static checks, unit tests, contract validation, or security scans fail. CD promotes the same immutable artifact from staging to production after approved checks.

## 10. Non-functional targets

- API p95: at most 300 ms for normal reads and 500 ms for ordinary writes, excluding identity-provider latency and export downloads.
- Cold start: at most 3 seconds on the supported mid-range device baseline under normal conditions.
- Session state recovery: reconstruct phase and remaining time within 2 seconds after ordinary process restart.
- Accessibility: WCAG 2.2 AA contrast targets, logical screen-reader labels, dynamic-type support, and non-color state cues.
- Supported viewport: 320 logical pixels and above, portrait-first with functional landscape behavior.

## 11. Implementation sequence

1. Bootstrap repository, CI, environment configuration, OpenAPI pipeline, database migrations, and Google OIDC verification.
2. Build profile, activity-template, plan, and review API resources with authorization tests.
3. Build Flutter authentication, encrypted persistence, outbox, profile editor, activity picker/creator, and weekly plan editing.
4. Implement the deterministic timer engine, session APIs, background recovery, Android notification service, and iOS Live Activity bridge.
5. Deliver Insights using completed focus sessions and Android-only UsageStats daily aggregates; implement Usage Access, versioned per-user sync consent, owner-scoped API sync/revocation, then the separate anonymous Top 10 report.
6. Deliver the admin CRM: RBAC, ticket resolution, global activity/weekly-plan templates, notification campaigns, aggregate activity metrics, top performers, and Top 10 app reports.
7. Run security review, migration/restore test, accessibility test pass, staged beta, and production readiness review.

## 12. Explicitly out of scope

- Raw Android usage timelines or CRM inspection of an individual user's app-usage records.
- iOS third-party-app screen-time tracking.
- A guaranteed per-second lock-screen redraw while an app is suspended.
- Rewards, social features, billing, ads, and AI analysis of review text.
