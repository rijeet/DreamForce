# Dream Force — Product Requirements Document

**Status:** Draft for product and engineering review  
**Version:** 0.1  
**Date:** 10 November 2026  
**Platforms:** Android first, iOS from the same cross-platform product codebase  
**Audience:** Product, design, mobile, backend, data, QA, security, and support

> This document turns the supplied “App Idea Comparison” conversation into an implementation-ready baseline. Items marked **Assumption** or **Decision needed** were not fully settled in that conversation and should be confirmed before release. “Industry standard” is not one formal certification; the design uses widely adopted HTTP, OpenAPI, PostgreSQL, and OWASP guidance and still requires implementation-specific security and privacy review.

## 1. Product summary

Dream Force helps a person plan focused work, run a timer with planned rest intervals, keep a repeatable weekly schedule, and reflect on how each day went. The user can start, skip, pause, or finish planned activities. Sessions and reviews sync to the user’s account so they can later understand patterns and reasons for missed plans.

The first release is a personal productivity tool. Rewards, daily good deeds, and outcome tracking are explicitly outside the MVP experience. The database should leave a clean extension point for a future reward system without making rewards part of current flows.

### Product principles

1. Starting an activity should take only a few taps; templates and recent activities avoid repeated setup. A user chooses an activity and a total duration, not a focus/rest format.
2. A timer should remain useful offline and should not depend on a continuously running server request. Focus and rest blocks are calculated automatically from the total duration.
3. Rest is an explicit phase in an activity plan, not an unrelated activity the user must create.
4. A schedule is guidance; skipping an item must be easy and must not shame the user.
5. Daily review supports positive, negative, and neutral reflection. The user controls what they write.
6. Account data is private to the account owner. Support access to email is controlled and auditable.
7. Android and iOS share product behavior and backend contracts; platform-specific lock-screen surfaces are implemented with native platform APIs where required.

## 2. Goals, non-goals, and success measures

### Goals for MVP

- Create, edit, archive, and reuse activity templates.
- Select an activity and total duration; receive an automatic, inspectable focus/rest schedule.
- Run one active session at a time, including focus, rest, pause, resume, complete, cancel, and interruption recovery.
- Show a live timer surface on Android and iOS lock screen when supported and permitted by the OS.
- Create a weekly plan with day-specific activities and optional planned start times.
- Mark planned items as started, skipped, or left unstarted; record actual sessions separately from planned items.
- Capture an end-of-day review with free text and optional structured reasons/tags, including days when no activities were completed.
- Sync profile, templates, plans, sessions, and reviews to the signed-in user’s account.
- Provide a privacy-respecting profile and account data export/deletion path.

### Not in MVP

- Reward catalog, reward earning, reward redemption, candy/gaming balance, or enforcement of “one reward at a time” in user-facing flows.
- Daily good deeds, outcome scoring, social sharing, leaderboards, teams, or coaching recommendations.
- AI analysis of journal text.
- Billing, subscriptions, ads, or third-party analytics tied to journal content.
- Guaranteeing that a countdown continues visually updating every second while an app is suspended. The OS owns background execution and lock-screen refresh behavior.

### Success measures (initial targets; validate with analytics and research)

| Measure | Initial target | Definition |
| --- | ---: | --- |
| Onboarding completion | ≥70% | New installs completing account/profile setup ÷ onboarding starts |
| First session start | ≥60% | New accounts starting a session within 24 hours |
| Template reuse | ≥50% | Sessions started from a saved or built-in template by week 4 |
| Session completion reliability | ≥99% | Sessions that recover to a correct final state after process/app restart |
| Weekly plan usage | ≥30% | Weekly active users with at least one planned item |
| Daily review adoption | ≥20% | Eligible user-days with a submitted review |
| API availability | ≥99.9% monthly target | Production API success/availability SLO, excluding planned maintenance |

Do not use completion time, number of breaks, or journal sentiment as a proxy for personal worth or health. Instrument only events needed for product reliability and aggregate feature use.

## 3. Users and jobs to be done

### Primary user

A student, independent learner, or knowledge worker who wants structure for focused tasks and breaks without configuring a timer from scratch every time.

### Core jobs

- “When I’m ready to work, let me choose a familiar task and start quickly.”
- “While I’m working, show me the current focus/rest phase and what happens next.”
- “Help me make a weekly plan, while allowing me to skip a day or task without losing the plan.”
- “At the end of the day, let me record what happened and why, even if I did nothing.”
- “Let me see my own history across devices, with control over my personal notes.”

## 4. MVP functional requirements

Priority: **P0** required for MVP; **P1** desirable for MVP; **Future** post-MVP.

### 4.1 Account, identity, and profile

- **P0** Standard users sign in through Google using OpenID Connect/OAuth authorization code with PKCE. Standard users have role `user` by default and the app must never collect or store a Google password. The Create account screen requires acknowledgement of the Privacy Policy and Terms and Conditions before enabling sign-in.
- **P0** Admin accounts have role `admin` and are created only by a protected provisioning script with email and password. Store only an Argon2id password hash; do not offer public admin registration. Every admin route enforces role-based authorization and records sensitive actions in an audit log.
- **P0** Backend maps a verified identity `(issuer, subject)` to an internal random UUID. Email is a contact/account attribute, not the primary database key.
- **P0** Store a normalized email address for account recovery and customer support. Encrypt it at rest through managed database/storage encryption; restrict support access by role, require a support reason, and audit access. Never put email, tokens, or journal content in ordinary application logs.
- **P0** Store the user’s preferred display name and avatar URL or provider reference only if needed. Do not download or persist a profile image unnecessarily; allow the user to remove/change display details.
- **P0** Allow timezone and locale to be set or inferred from device settings, with an editable setting.
- **P0** The editable user profile stores optional gender, date of birth, country, city, profession, and timezone. These fields are private to the account owner, excluded from analytics/support by default, and absent from lock-screen/notification content. Date of birth and gender are never required to create an account.
- **P0** Account export and account deletion must be available from settings. Deletion must remove or anonymize personal data in a documented, time-bounded process, except legally required records. Confirm deletion in-app before the final irreversible step.
- **Decision needed:** The source chat says gender and date of birth are required but gives no product reason. They are excluded from MVP account creation. If a lawful age restriction or a validated product need exists, collect only the minimum needed, document purpose/retention, and allow correction. Gender is not needed for focus planning and should remain uncollected unless a specific feature justifies it.

### 4.2 Activity templates

- **P0** Ship starter templates: Study (45 min, Standard 45/15), Coding (60 min, Extended 50/10), Exercise (30 min, no scheduled rest by default or selected format), and Reading (30 min, Pomodoro 25/5). Product can edit the built-in catalog without changing client code.
- **P0** Users can create custom templates with a name, user-selected icon, optional category, and planned total duration. Focus and rest are automatic; users do not choose a format or enter focus/rest values.
- **P0** Users can choose a prior activity/template and edit it before starting without changing the saved template unless they explicitly save changes.
- **P0** Template fields: name (1–80 characters), icon identifier, category (optional; enum or user-defined label), and planned duration (1–480 minutes). The service persists the resulting calculated phase schedule with each session so a later algorithm revision cannot rewrite history.
- **P0** Automatic cycle rule: the default allocation is five-sixths focus and one-sixth rest for a complete total duration. Round phase boundaries to whole seconds and ensure the schedule never exceeds the selected total. Example: 30 minutes becomes 25 focus + 5 rest; 60 becomes 50 focus + 10 rest.
- **P0** Long-session rule: for a 90-minute selection, split the plan into two 40-minute focus blocks with 5-minute breaks. After a completed 90-minute session, present a non-blocking prompt recommending a 20–30 minute long rest before the next session. This prompt is not another activity and may be dismissed.
- **P0** Validate name and planned duration. Do not present Pomodoro, Standard, Extended, Deep Work, Custom, focus-duration, rest-duration, cycle-count, or final-rest controls in the activity-creation UI.
- **P1** Archive templates rather than hard-delete when they have historical sessions. Historical sessions snapshot the values used at session start.

### 4.3 Session timer and lock-screen presentation

- **P0** Only one non-terminal session per user may be active at once. If a user starts a second, ask whether to return to the existing session or end it before creating another.
- **P0** Session states: `running`, `paused`, `completed`, `cancelled`, `interrupted`. Phase states: `focus`, `rest`, `finished`.
- **P0** Session actions: start, pause, resume, delete (cancel) the active session, and recover after app/process restart. Focus/rest phase transitions and completion occur automatically from the generated schedule; users cannot skip a phase or finish early.
- **P0** Use monotonic elapsed time on-device for countdown display. Persist authoritative state transitions and wall-clock timestamps locally and to the backend. On resume/restart, reconcile with `started_at`, accumulated paused duration, phase schedule, and the device clock; explain and allow correction if a large clock/time discrepancy is detected.
- **P0** Timer works without network after session setup. Queue session events and retry sync with an idempotency key. The server validates legal state transitions and ensures one open session per user.
- **P0** Android: provide a persistent, user-visible ongoing notification for a running session if required by selected implementation; expose safe actions such as pause/resume/open app. Use the appropriate foreground-service type only where platform policy and actual feature behavior permit it. Do not launch an intrusive full-screen activity just to show a timer.
- **P0** iOS: provide a Live Activity using ActivityKit/WidgetKit for supported devices and user settings. Start, update, and end it with the session; handle disabled/unavailable activities and stale content gracefully.
- **P0** Show a concise, privacy-safe activity label and phase/time remaining. Do not show journal notes, email, or sensitive text on lock screens.
- **P1** Local notifications when focus/rest phase changes, subject to user permission and OS delivery behavior. Do not promise exact second-level notifications.
- **P1** Keep the countdown moving across app backgrounding and device restart as reliably as supported. UI should derive remaining time from timestamps rather than counting callbacks.

### 4.4 Weekly plans

- **P0** User can create one or more plans, with a day-of-week schedule, ordered activities, optional local start times, and optional planned duration/template reference.
- **P0** Each planned occurrence is materialized for a date in the user’s timezone, or derived deterministically from a plan revision. A plan edit must not rewrite already completed session history.
- **P0** For each date’s item, user can start, skip, or leave it unstarted. Skipping can have an optional short reason; end-of-day review can add a broader reason.
- **P0** Plan time-zone behavior must be explicit: recurring weekday/time uses the user’s current selected timezone; already materialized occurrences retain the timezone and local date used at creation. Changing timezone affects future occurrences.
- **P1** Duplicate/copy days, reorder tasks, and pause plan for a date range.

### 4.5 Daily review and reporting

- **P0** User can create or edit one review per local calendar date. It is valid with zero completed sessions.
- **P0** Review supports optional free-text reflection (up to 5,000 characters), optional mood/assessment (positive, mixed, difficult, or unset), optional reason tags, and an optional “what I did” summary. The text is private user-generated content and must not be placed in analytics or logs.
- **P0** Prompt examples are neutral: “What went well?”, “What got in the way?”, “What would help tomorrow?” The user may skip every prompt.
- **P0** Daily report shows planned items, session totals, focus/rest time, completed/skipped/unstarted items, and review text only to the owner.
- **P0** User can edit or delete a review. Edits update `updated_at` and create an audit/version record only if product policy requires user-visible history; do not keep hidden journal versions indefinitely.
- **P1** Browse prior reviews by date and search locally/server-side only after privacy and encryption choices are reviewed.

### 4.6 Future reward blueprint (not active in MVP)

- **Future** Configurable reward rules may require accumulated activity time by category (source example: “Candy” 20 hours and “Gaming” 10 hours). These labels are examples, not fixed MVP behavior.
- **Future** A reward system should define earning rules, eligibility windows, redemption, expiry, cancellations, and a ledger that can be audited. Never derive reward balances from mutable UI totals alone.
- **Future** To honor “one reward at a time,” a partial unique database index or transactional lock must prevent more than one open claim/redemption per user. The rule’s meaning (one active reward, one unredeemed reward, or one redemption at a time) is a product decision.
- **Future** Daily good deed and results entities may be enabled behind a feature flag. Do not expose these endpoints or collect these records in MVP.

### 4.7 Admin CRM, templates, notifications, and aggregate monitoring

- **P0** Admins can open a role-gated CRM dashboard to view aggregate product activity, resolve support tickets, publish global activity templates, publish weekly-plan templates, and create notification campaigns.
- **P0** Support tickets contain user-authored support messages only. Admins can assign, reply, resolve, close, and add internal notes. Daily-review text and private profile fields are not part of CRM ticket context.
- **P0** Admin-created activity and weekly-plan templates are visible to users only when published. Users copy a template into their own plan; they cannot modify the original global template.
- **P0** Admin notification campaigns support draft, scheduled, sending, sent, cancelled, and failed states. Respect platform notification permission and user notification preference; never include private review/profile data in a notification.
- **P0** CRM monitoring includes daily/weekly/monthly/yearly aggregate completed focus time, active users, completed sessions, top performers by completed Dream Force focus time, and Top 10 apps by aggregate Android screen-time contribution.
- **P0** Android app usage sync is a separate, default-off consent from Terms acceptance and Android Usage Access. With both consents, daily per-app aggregates sync to the user's private account for Screen time Insights. CRM Top 10 uses a separate non-identifiable aggregate; admins cannot view individual app-usage records, review text, or raw UsageStats timelines.

## 5. User journeys and acceptance criteria

### Start a session

1. User selects a quick template, recent activity, or custom activity.
2. App previews total duration and focus/rest format; user can adjust the run without changing the template.
3. User taps Start. The app creates a session locally, requests backend session creation when online, and shows the active timer.
4. The lock-screen surface appears if the OS feature is available and enabled; otherwise the in-app timer remains usable.
5. On each phase transition, the app records the transition and updates the lock-screen surface. On completion, the session is finalized once.

**Acceptance:** Tapping Start twice cannot create two running sessions. A lost response followed by a retry with the same idempotency key returns the same session. After app force-close/reopen, phase and remaining time are reconstructed within a 2-second target under normal clock conditions.

### Plan and skip an activity

1. User selects a weekday and adds templates in order, optionally with a local start time.
2. On the scheduled date, the plan displays today’s activities.
3. User can start an activity, skip it, or leave it alone.
4. End-of-day report distinguishes skipped from unstarted.

**Acceptance:** Skipping one planned occurrence does not delete the recurring weekly template and does not create a completed session.

### Write a day review with no completed work

1. User opens Daily Review from today’s view or a reminder.
2. They may write a reason, select optional tags, or leave fields empty.
3. Save creates/updates the review for that user’s local date.

**Acceptance:** A review is permitted with zero sessions; a second create for the same user/date updates the existing review (upsert semantics) rather than creating a duplicate.

## 6. Non-functional requirements

### Reliability and performance

- API p95 target: ≤300 ms for ordinary reads and ≤500 ms for writes at MVP load, excluding identity-provider calls and large exports.
- App cold start target: ≤3 seconds on supported mid-range devices under normal conditions.
- API reads and writes must be retry-safe where practical. Use idempotency for session start and other non-idempotent operations.
- Database backups encrypted, with recovery point objective ≤24 hours and recovery time objective ≤8 hours for MVP; verify restore procedures before launch.
- Offline data queue encrypted using platform secure storage/key management. Define conflict handling by resource: templates and plans use `version`/`updated_at` optimistic concurrency; session events are append-only and idempotent; daily review is last-write-wins with conflict notice if concurrent edits occur.

### Accessibility and localization

- Support screen readers, scalable text, contrast, reduced motion, and accessible timer announcements.
- Localize interface, number/date/time formatting, and pluralization. Store instants as UTC and retain IANA timezone for local scheduling.
- Never rely on color alone to distinguish focus/rest or positive/negative values.

### Privacy and security

- HTTPS/TLS for all API traffic; no production credentials embedded in client code.
- Authenticate every private API request. Authorize every resource query against the authenticated account; never trust a client-supplied `user_id` for ownership.
- Apply object- and property-level authorization to prevent cross-account IDOR and over-posting. Allowlist writable fields.
- Rate-limit authentication, account recovery, session creation, export, and other resource-heavy endpoints. Bound request size, pagination size, text length, and export size.
- Use managed secrets, rotate keys, encrypt backups, and separate production from development data. Avoid copying production PII into test systems.
- Email may be available to authorized support staff only when needed for a case; log support access and redact email in general logs. Journal text is not visible to support by default.
- Establish retention periods for inactive accounts, audit records, exports, and backups before launch. Deletion from backups follows a documented expiry schedule.
- Use OWASP API Security Top 10 as a threat-review checklist; it is guidance, not a guarantee of security.

## 7. Technical architecture recommendation

### Client

**Assumption:** Flutter for shared Android/iOS app logic and UI. Use platform channels/native extensions for Android notification/foreground execution and iOS ActivityKit/WidgetKit surfaces. Keep timer domain logic, API models, and validation in shared Dart code; keep lifecycle integration in platform-specific modules. This prevents a later full rewrite while acknowledging OS-native features cannot be delivered identically by one cross-platform UI widget.

### Backend

- HTTPS JSON REST API with resource-oriented paths, versioned as `/v1`.
- OpenAPI 3.1 description is the API contract and code-generation source of truth. Pin the exact OpenAPI version/tooling in the implementation repo.
- PostgreSQL relational store. UUID primary keys, foreign keys, check constraints, unique constraints, and indexes enforce core invariants. Keep application-layer validation as well.
- Authentication through OIDC-compatible provider; backend validates token issuer, audience, signature, expiry, and subject. Internal account IDs are independent UUIDs.
- Stateless API workers. Timer runs on the client; backend stores authoritative transitions/history and reconciles idempotent events.
- Push notification service is optional for MVP; phase updates should not require server push.
- Separate operational telemetry from private user content. Crash logs and product analytics must omit review text and email.

### Contract conventions

- `Content-Type: application/json`; UTF-8.
- Timestamps are RFC 3339 UTC strings (example `2026-11-10T12:30:00Z`); local schedule entries include IANA timezone and local date/time.
- IDs are opaque UUID strings. Clients must not infer identity or permissions from ID values.
- Include `Authorization: Bearer <access_token>` for authenticated calls.
- `Idempotency-Key` required for session creation and recommended for retriable writes; scope key to authenticated account and endpoint. Retain key/result for at least 24 hours.
- `If-Match` with an ETag or `version` field for mutable plans/templates/reviews; return `412 Precondition Failed` on stale update.
- Paginated lists use `limit` (default 20, max 100) and opaque `cursor`; responses include `next_cursor`.
- Errors follow RFC 9457 `application/problem+json`, with stable application `code` and `request_id`; no stack traces or PII.
- Breaking changes require a new major path version. Additive optional response fields are allowed; clients ignore unknown fields.

## 8. API resource model

Base URL: `https://api.<domain>/v1` (production host is a deployment decision). Authentication/token issuance is provided by the selected identity provider; the app exchanges/refreshes tokens using its supported SDK and does not send passwords to Dream Force APIs.

### 8.1 Common error response

```http
HTTP/1.1 422 Unprocessable Content
Content-Type: application/problem+json
```

```json
{
  "type": "https://api.example.com/problems/validation-error",
  "title": "Request validation failed",
  "status": 422,
  "detail": "One or more fields are invalid.",
  "instance": "/v1/activity-templates",
  "code": "VALIDATION_ERROR",
  "request_id": "0192c2d8-6fd1-7e78-8c58-b38583fce441",
  "errors": [
    { "field": "focus_minutes", "code": "must_be_positive", "message": "Must be greater than zero." }
  ]
}
```

Never include rejected sensitive values in `detail`, `errors`, or logs.

### 8.2 Endpoints

| Method and path | Purpose | Success |
| --- | --- | --- |
| `GET /me` | Get the authenticated profile and settings | 200 |
| `PATCH /me` | Update allowed profile/settings fields | 200 |
| `DELETE /me` | Begin account deletion | 202 |
| `GET /activity-templates` | List built-in and owned templates | 200 |
| `POST /activity-templates` | Create a custom template | 201 |
| `GET /activity-templates/{id}` | Fetch one template | 200 |
| `PATCH /activity-templates/{id}` | Update owned template | 200 |
| `DELETE /activity-templates/{id}` | Archive owned template | 204 |
| `GET /plans` | List weekly plans | 200 |
| `POST /plans` | Create a weekly plan | 201 |
| `GET /plans/{id}` | Fetch plan, entries, version | 200 |
| `PUT /plans/{id}` | Replace plan schedule using `If-Match` | 200 |
| `GET /plan-occurrences?from=&to=` | Read materialized/deterministic date occurrences | 200 |
| `PATCH /plan-occurrences/{id}` | Mark started/skipped or attach skip reason | 200 |
| `POST /sessions` | Start session; idempotency required | 201 or 200 replay |
| `GET /sessions/{id}` | Fetch session state/history | 200 |
| `POST /sessions/{id}/events` | Append pause/resume/cancel event | 200 |
| `GET /sessions?from=&to=` | List session history | 200 |
| `GET /daily-reviews?from=&to=` | List owner’s reviews | 200 |
| `PUT /daily-reviews/{local_date}` | Upsert review for local date | 200 or 201 |
| `GET /daily-reviews/{local_date}` | Get a review | 200 |
| `DELETE /daily-reviews/{local_date}` | Delete a review | 204 |
| `POST /exports` | Request account data export | 202 |

Every endpoint other than explicitly public provider discovery is authenticated. There are no MVP reward/good-deed endpoints.

### 8.3 `GET /me` response

```json
{
  "id": "b8d06a9d-4a42-4e98-9f4d-fd95075c944e",
  "display_name": "Riya",
  "avatar_url": null,
  "email_verified": true,
  "timezone": "Asia/Dhaka",
  "locale": "en-BD",
  "created_at": "2026-11-10T08:00:00Z",
  "updated_at": "2026-11-10T08:00:00Z",
  "settings": {
    "default_format_id": "standard",
    "phase_notifications_enabled": false,
    "live_activity_enabled": true
  }
}
```

Email is not returned by default to the general app profile endpoint. A dedicated account/security screen may request it if needed. Provider subject and internal auth claims are never returned.

### 8.4 Create activity template

`POST /activity-templates`

```json
{
  "name": "Essay writing",
  "category": "study",
  "planned_minutes": 60,
  "format": { "kind": "standard", "focus_minutes": 45, "rest_minutes": 15 },
  "include_final_rest": false
}
```

`201 Created`

```json
{
  "id": "9ee06a1c-c6b2-4707-a202-f65d0e66c19a",
  "name": "Essay writing",
  "category": "study",
  "planned_minutes": 60,
  "format": { "kind": "standard", "focus_minutes": 45, "rest_minutes": 15 },
  "include_final_rest": false,
  "is_builtin": false,
  "version": 1,
  "created_at": "2026-11-10T08:15:00Z",
  "updated_at": "2026-11-10T08:15:00Z"
}
```

### 8.5 Create weekly plan

`POST /plans`

```json
{
  "name": "Study week",
  "timezone": "Asia/Dhaka",
  "entries": [
    { "weekday": 1, "position": 1, "template_id": "9ee06a1c-c6b2-4707-a202-f65d0e66c19a", "local_start_time": "09:00" },
    { "weekday": 3, "position": 1, "template_id": "9ee06a1c-c6b2-4707-a202-f65d0e66c19a", "local_start_time": null }
  ]
}
```

`201 Created`

```json
{
  "id": "a43c6bfb-3f92-4329-8c4a-41c22a163eb2",
  "name": "Study week",
  "timezone": "Asia/Dhaka",
  "version": 1,
  "entries": [
    { "id": "2e120d1b-e934-4f66-a118-d38a3b58da87", "weekday": 1, "position": 1, "template_id": "9ee06a1c-c6b2-4707-a202-f65d0e66c19a", "local_start_time": "09:00" },
    { "id": "685ae098-05d8-4c31-bec8-521d92d15d46", "weekday": 3, "position": 1, "template_id": "9ee06a1c-c6b2-4707-a202-f65d0e66c19a", "local_start_time": null }
  ],
  "created_at": "2026-11-10T08:20:00Z",
  "updated_at": "2026-11-10T08:20:00Z"
}
```

Weekday numbering is ISO-8601: Monday=1 through Sunday=7.

### 8.6 Start session

`POST /sessions` (requires `Idempotency-Key: 68d...`)

```json
{
  "template_id": "9ee06a1c-c6b2-4707-a202-f65d0e66c19a",
  "plan_occurrence_id": null,
  "name_snapshot": "Essay writing",
  "planned_minutes": 60,
  "focus_minutes": 45,
  "rest_minutes": 15,
  "include_final_rest": false,
  "client_started_at": "2026-11-10T08:30:00Z",
  "device_timezone": "Asia/Dhaka",
  "client_event_id": "ab9cbbdb-014c-4d58-b822-87a759ad61ee"
}
```

`201 Created` (or `200 OK` on idempotent replay)

```json
{
  "id": "71c559b4-92d1-4ac0-97e3-3eb0386fc61f",
  "status": "running",
  "current_phase": "focus",
  "phase_started_at": "2026-11-10T08:30:00Z",
  "phase_ends_at": "2026-11-10T09:15:00Z",
  "planned_ends_at": "2026-11-10T09:30:00Z",
  "started_at": "2026-11-10T08:30:00Z",
  "server_received_at": "2026-11-10T08:30:01Z",
  "version": 1
}
```

If another session is open, return `409 Conflict` with `code: ACTIVE_SESSION_EXISTS` and the existing session ID only for that authenticated user.

### 8.7 Session event

`POST /sessions/{id}/events` (idempotency key recommended; client event UUID unique)

```json
{
  "event_id": "a87368f1-836a-4c44-959c-279bd06ee327",
  "type": "pause",
  "occurred_at": "2026-11-10T08:52:10Z",
  "expected_version": 3,
  "reason": null
}
```

Response:

```json
{
  "session_id": "71c559b4-92d1-4ac0-97e3-3eb0386fc61f",
  "status": "paused",
  "current_phase": "focus",
  "paused_at": "2026-11-10T08:52:10Z",
  "version": 4,
  "accepted_event_id": "a87368f1-836a-4c44-959c-279bd06ee327"
}
```

Allowed event types: `pause`, `resume`, `skip_phase`, `finish`, `cancel`. Server checks the transition against current state/version and returns `409 SESSION_STATE_CONFLICT` for stale/illegal transitions. Client can refresh state and replay only unaccepted event IDs.

### 8.8 Daily review upsert

`PUT /daily-reviews/2026-11-10`

```json
{
  "timezone": "Asia/Dhaka",
  "mood": "mixed",
  "summary": "Finished the reading task; postponed coding.",
  "reflection": "I had an appointment in the afternoon and felt tired afterward.",
  "reason_tags": ["appointment", "low_energy"],
  "version": 1
}
```

Response:

```json
{
  "local_date": "2026-11-10",
  "timezone": "Asia/Dhaka",
  "mood": "mixed",
  "summary": "Finished the reading task; postponed coding.",
  "reflection": "I had an appointment in the afternoon and felt tired afterward.",
  "reason_tags": ["appointment", "low_energy"],
  "version": 2,
  "created_at": "2026-11-10T18:00:00Z",
  "updated_at": "2026-11-10T18:05:00Z"
}
```

The API derives account ownership from the access token. `local_date` is a date, not a UTC timestamp; one review per `(user_id, local_date)` is enforced.

### 8.9 Pagination example

`GET /sessions?from=2026-11-01T00:00:00Z&to=2026-12-01T00:00:00Z&limit=20`

```json
{
  "data": [],
  "page": { "next_cursor": null, "limit": 20 }
}
```

### 8.10 Status code policy

- `200` read/update or idempotent replay; `201` created; `202` accepted for asynchronous export/deletion; `204` successful delete/archive without body.
- `400` malformed syntax; `401` missing/invalid authentication; `403` authenticated but not permitted; `404` absent or deliberately concealed private resource; `409` state conflict; `412` stale ETag/version; `413` body too large; `422` validation error; `429` rate limited with `Retry-After`; `5xx` generic server fault.

## 9. Database schema (PostgreSQL reference)

The following is a logical MVP schema. Names/types may be adapted by migrations, but the constraints and ownership invariants should remain. Use migrations, avoid destructive in-place changes, and test restore/migration paths. PostgreSQL automatically indexes primary/unique keys but not all referencing foreign-key columns; add indexes for common foreign-key access paths.

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE app_user (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL,
  email_normalized text NOT NULL UNIQUE,
  email_verified_at timestamptz,
  role text NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  google_subject text UNIQUE,
  password_hash text,
  display_name varchar(80),
  avatar_url text,
  timezone text NOT NULL DEFAULT 'UTC',
  locale varchar(35) NOT NULL DEFAULT 'en',
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'deletion_pending', 'deleted', 'suspended')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CHECK ((role = 'user' AND google_subject IS NOT NULL AND password_hash IS NULL)
      OR (role = 'admin' AND password_hash IS NOT NULL))
);

CREATE TABLE user_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES app_user(id) ON DELETE CASCADE,
  gender varchar(80),
  date_of_birth date,
  country varchar(100),
  city varchar(100),
  profession varchar(120),
  timezone varchar(64) NOT NULL DEFAULT 'UTC',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (date_of_birth IS NULL OR date_of_birth >= DATE '1900-01-01')
);

CREATE TABLE user_settings (
  user_id uuid PRIMARY KEY REFERENCES app_user(id) ON DELETE CASCADE,
  phase_notifications_enabled boolean NOT NULL DEFAULT false,
  live_activity_enabled boolean NOT NULL DEFAULT true,
  week_starts_on smallint NOT NULL DEFAULT 1 CHECK (week_starts_on BETWEEN 1 AND 7),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE activity_template (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id uuid REFERENCES app_user(id) ON DELETE CASCADE,
  name varchar(80) NOT NULL CHECK (char_length(trim(name)) BETWEEN 1 AND 80),
  icon_key varchar(40) NOT NULL DEFAULT 'target',
  category varchar(40),
  planned_minutes smallint NOT NULL CHECK (planned_minutes BETWEEN 1 AND 480),
  is_builtin boolean NOT NULL DEFAULT false,
  archived_at timestamptz,
  version integer NOT NULL DEFAULT 1 CHECK (version > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK ((is_builtin AND owner_user_id IS NULL) OR (NOT is_builtin AND owner_user_id IS NOT NULL))
);
CREATE INDEX activity_template_owner_idx ON activity_template(owner_user_id, updated_at DESC)
  WHERE archived_at IS NULL;

CREATE TABLE weekly_plan (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  name varchar(80) NOT NULL CHECK (char_length(trim(name)) BETWEEN 1 AND 80),
  timezone text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  version integer NOT NULL DEFAULT 1 CHECK (version > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX weekly_plan_user_idx ON weekly_plan(user_id, is_active, updated_at DESC);

CREATE TABLE weekly_plan_entry (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid NOT NULL REFERENCES weekly_plan(id) ON DELETE CASCADE,
  template_id uuid NOT NULL REFERENCES activity_template(id) ON DELETE RESTRICT,
  weekday smallint NOT NULL CHECK (weekday BETWEEN 1 AND 7),
  position smallint NOT NULL CHECK (position >= 1),
  local_start_time time,
  planned_minutes_override smallint CHECK (planned_minutes_override BETWEEN 1 AND 480),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (plan_id, weekday, position)
);
CREATE INDEX weekly_plan_entry_template_idx ON weekly_plan_entry(template_id);

CREATE TABLE plan_occurrence (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  plan_id uuid NOT NULL REFERENCES weekly_plan(id) ON DELETE CASCADE,
  plan_entry_id uuid REFERENCES weekly_plan_entry(id) ON DELETE SET NULL,
  template_id uuid REFERENCES activity_template(id) ON DELETE SET NULL,
  local_date date NOT NULL,
  timezone text NOT NULL,
  local_start_time time,
  planned_minutes smallint NOT NULL CHECK (planned_minutes BETWEEN 1 AND 480),
  name_snapshot varchar(80) NOT NULL,
  state text NOT NULL DEFAULT 'scheduled'
    CHECK (state IN ('scheduled', 'started', 'skipped', 'completed', 'unstarted')),
  skip_reason varchar(500),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (plan_entry_id, local_date)
);
CREATE INDEX plan_occurrence_user_date_idx ON plan_occurrence(user_id, local_date, state);

CREATE TABLE focus_session (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  template_id uuid REFERENCES activity_template(id) ON DELETE SET NULL,
  plan_occurrence_id uuid REFERENCES plan_occurrence(id) ON DELETE SET NULL,
  name_snapshot varchar(80) NOT NULL,
  category_snapshot varchar(40),
  planned_minutes smallint NOT NULL CHECK (planned_minutes BETWEEN 1 AND 480),
  focus_minutes smallint NOT NULL CHECK (focus_minutes > 0),
  rest_minutes smallint NOT NULL CHECK (rest_minutes >= 0),
  include_final_rest boolean NOT NULL DEFAULT false,
  status text NOT NULL CHECK (status IN ('running', 'paused', 'completed', 'cancelled', 'interrupted')),
  current_phase text NOT NULL CHECK (current_phase IN ('focus', 'rest', 'finished')),
  started_at timestamptz NOT NULL,
  ended_at timestamptz,
  total_paused_seconds integer NOT NULL DEFAULT 0 CHECK (total_paused_seconds >= 0),
  actual_focus_seconds integer NOT NULL DEFAULT 0 CHECK (actual_focus_seconds >= 0),
  actual_rest_seconds integer NOT NULL DEFAULT 0 CHECK (actual_rest_seconds >= 0),
  version integer NOT NULL DEFAULT 1 CHECK (version > 0),
  client_timezone text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK ((status IN ('running', 'paused') AND ended_at IS NULL)
      OR (status IN ('completed', 'cancelled', 'interrupted') AND ended_at IS NOT NULL))
);
-- At most one non-terminal session per user. Enforced under concurrent requests too.
CREATE UNIQUE INDEX one_open_session_per_user_idx ON focus_session(user_id)
  WHERE status IN ('running', 'paused');
CREATE INDEX focus_session_user_started_idx ON focus_session(user_id, started_at DESC);
CREATE INDEX focus_session_occurrence_idx ON focus_session(plan_occurrence_id)
  WHERE plan_occurrence_id IS NOT NULL;

CREATE TABLE session_event (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES focus_session(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  client_event_id uuid NOT NULL,
  event_type text NOT NULL CHECK (event_type IN
    ('started', 'pause', 'resume', 'focus_started', 'rest_started', 'skip_phase', 'finish', 'cancel', 'interrupted')),
  occurred_at timestamptz NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now(),
  event_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (user_id, client_event_id)
);
CREATE INDEX session_event_session_time_idx ON session_event(session_id, occurred_at);

CREATE TABLE daily_review (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  local_date date NOT NULL,
  timezone text NOT NULL,
  mood text CHECK (mood IN ('positive', 'mixed', 'difficult')),
  summary varchar(1000),
  reflection varchar(5000),
  reason_tags text[] NOT NULL DEFAULT '{}',
  version integer NOT NULL DEFAULT 1 CHECK (version > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, local_date)
);
CREATE INDEX daily_review_user_date_idx ON daily_review(user_id, local_date DESC);

CREATE TABLE idempotency_record (
  user_id uuid NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  endpoint_key varchar(120) NOT NULL,
  idempotency_key varchar(255) NOT NULL,
  request_hash bytea NOT NULL,
  response_status smallint,
  response_body jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  PRIMARY KEY (user_id, endpoint_key, idempotency_key)
);
CREATE INDEX idempotency_expiry_idx ON idempotency_record(expires_at);

CREATE TABLE account_export_job (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  status text NOT NULL CHECK (status IN ('queued', 'processing', 'ready', 'failed', 'expired')),
  artifact_key text,
  requested_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz,
  completed_at timestamptz
);

CREATE TABLE support_access_audit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  support_actor_id uuid NOT NULL,
  subject_user_id uuid NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  reason_code varchar(80) NOT NULL,
  accessed_fields text[] NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX support_access_subject_time_idx ON support_access_audit(subject_user_id, occurred_at DESC);
```

### 9.1 Data ownership and deletion rules

- All user-owned rows are queried and mutated with `user_id = authenticated_user.id` in the same database operation; ownership checks do not depend on client filtering.
- Built-in templates are global and read-only; custom templates are scoped by owner.
- Historical session name/category/duration/format are snapshots so editing a template does not rewrite past activity.
- Reviews are highly private. Do not duplicate their text in event payloads, data warehouses, support logs, or push payloads.
- Prefer soft archive for templates/plans with history. User deletion cascades or anonymizes personal content according to the approved retention policy.
- For large tables, partitioning is not needed at MVP scale; add only after measured growth justifies it.

### 9.2 Future reward schema blueprint (design only; do not create MVP APIs)

When rewards are approved, introduce a versioned policy and an immutable ledger. A plausible future core is:

```sql
CREATE TABLE reward_policy (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name varchar(80) NOT NULL,
  version integer NOT NULL CHECK (version > 0),
  category text NOT NULL,
  required_focus_seconds bigint NOT NULL CHECK (required_focus_seconds > 0),
  eligible_from timestamptz,
  eligible_until timestamptz,
  active boolean NOT NULL DEFAULT false,
  UNIQUE (name, version)
);

CREATE TABLE reward_catalog_item (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  policy_id uuid NOT NULL REFERENCES reward_policy(id) ON DELETE RESTRICT,
  title varchar(120) NOT NULL,
  description varchar(1000),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE reward_ledger_entry (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  policy_id uuid NOT NULL REFERENCES reward_policy(id) ON DELETE RESTRICT,
  source_session_id uuid REFERENCES focus_session(id) ON DELETE SET NULL,
  entry_type text NOT NULL CHECK (entry_type IN ('earned', 'redeemed', 'reversed', 'expired')),
  amount_seconds bigint NOT NULL CHECK (amount_seconds <> 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, source_session_id, policy_id, entry_type)
);

CREATE TABLE reward_redemption (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  catalog_item_id uuid NOT NULL REFERENCES reward_catalog_item(id) ON DELETE RESTRICT,
  status text NOT NULL CHECK (status IN ('requested', 'active', 'fulfilled', 'cancelled', 'expired')),
  requested_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz
);
CREATE UNIQUE INDEX one_open_reward_redemption_per_user_idx ON reward_redemption(user_id)
  WHERE status IN ('requested', 'active');
```

This enforces one open redemption if that is the finalized rule, while the ledger preserves how balances were earned. A production reward model needs policy semantics and double-entry/reversal rules before implementation.

## 10. Analytics and operational events

Permitted MVP event examples: `onboarding_completed`, `template_selected`, `session_started`, `session_completed`, `session_cancelled`, `plan_created`, `plan_occurrence_skipped`, `daily_review_saved` (metadata only), `lock_screen_surface_unavailable`.

Do not collect: reflection/summary text, email, auth tokens, exact free-form skip reasons, or inferred sensitive traits. Analytics event IDs should be random; user identifiers should be pseudonymous and retained only as long as needed. Provide opt-out controls according to the final privacy policy and applicable law.

Operational metrics include API latency/error rate, queue depth, timer recovery error, database health, and export/delete job status. Keep access logs protected and redact authorization headers and query-string secrets.

## 11. Test and release requirements

Test coverage is expected during engineering delivery even though this document is not a test execution request.

- Contract validation: OpenAPI linting, request/response schema tests, and backward-compatibility checks.
- Authorization tests: account A cannot read/change account B’s templates, sessions, plans, or reviews, including by guessing UUIDs or manipulating nested IDs.
- Concurrency tests: two simultaneous session starts yield one open session; event retries do not duplicate transitions; review upsert remains unique.
- Timer tests: focus/rest boundaries, final partial cycle, pause/resume, cancellation, offline events, clock skew, daylight-saving change, restart recovery, duplicate delivery.
- Cross-platform acceptance: Android lock-screen notification behavior across supported Android API levels/device vendor variation; iOS Live Activity supported/disabled/stale/ended behavior; in-app fallback on both.
- Database tests: constraints, migrations from previous versions, deletion behavior, restore from backup, index performance on expected query patterns.
- Privacy checks: ensure private review/email absent from logs/analytics/crash reports and lock-screen payloads.
- Accessibility/localization checks on small screens, large type, screen readers, RTL where supported, and translated date/time formats.
- Store release readiness: privacy labels/disclosures, permission rationale, retention and deletion policy, support workflow, incident contact, and production monitoring.

## 12. Decisions to confirm before build freeze

1. Confirm Flutter as the shared mobile framework, or specify an existing team preference.
2. Choose identity provider(s) and whether sign-in is Google/Apple, email link, or another provider. Apple sign-in requirements depend on distribution and provider choices.
3. Confirm account email visibility: recommended default is email stored securely by backend for support/account recovery, not exposed through ordinary profile responses; support reads require audited case access.
4. Confirm whether age restrictions require date of birth. Do not require gender without a feature/legal reason.
5. Confirm timer meaning: source examples imply planned total includes the rest (30 = 25+5; 60 = 50+10). This PRD adopts that meaning.
6. Define handling when a user’s device clock changes materially during an offline session.
7. Confirm weekly schedule semantics when timezone changes and whether multiple simultaneous plans are allowed.
8. Confirm retention periods for account data, journal text, audit events, exports, and deletion from backups.
9. Clarify future rewards: “one reward at a time” means one open redemption per user in this draft, but the business rule must be finalized.
10. Set supported minimum Android/iOS versions and device matrix after platform spike. Lock-screen capabilities vary by OS version, settings, and device.

## 13. Standards and reference sources

This PRD uses these primary references for implementation guidance; requirements above remain product-specific:

- [OpenAPI Specification 3.1.1](https://spec.openapis.org/oas/v3.1.1.html) — language-neutral HTTP API description and JSON Schema alignment.
- [RFC 9457: Problem Details for HTTP APIs](https://www.rfc-editor.org/rfc/rfc9457.html) — interoperable machine-readable API errors.
- [OWASP API Security Top 10 (2023)](https://owasp.org/www-project-api-security/) — API threat categories, including object authorization, authentication, resource limits, and security configuration.
- [OWASP REST Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/REST_Security_Cheat_Sheet.html) — HTTPS, safe error handling, and REST security guidance.
- [PostgreSQL constraints documentation](https://www.postgresql.org/docs/current/ddl-constraints.html) — constraints, foreign keys, unique constraints, and indexing considerations.
- [Apple ActivityKit: displaying live data with Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities) — lock-screen and Dynamic Island behavior, lifecycle, availability, and stale state.
- [Android background services overview](https://developer.android.com/develop/background-work/services) and [time-sensitive notifications](https://developer.android.com/develop/ui/views/notifications/time-sensitive) — ongoing user-visible work and notification behavior.

---

**Document owner:** Product (TBD)  
**Reviewers:** Mobile lead, backend lead, security/privacy, design, support (TBD)

## 14. Frontend design specification (text reference for design and development)

This section is the text-only visual and interaction reference for the mobile team. It is deliberately not a Figma deliverable. Once the product owner approves this direction, the same specification can be translated into Figma screens and a component library. Figma work must preserve the page flows, states, and tokens below unless the owner approves a change.

### 14.1 Visual direction

**Design intent:** Calm, focused, warm, and encouraging. The interface should feel like a daily planning tool rather than a game, a clinical tracker, or a competitive productivity dashboard. Use open space, restrained surfaces, clear hierarchy, and purposeful color. Avoid streak pressure, shame language, excessive gradients, noisy badges, and decorative motion while a timer is active.

**Brand direction (working name: “Quiet Momentum”):** Deep evergreen is the primary action color; warm off-white is the default canvas; sky blue marks rest; warm amber is used only for caution. Color is never the only way to communicate meaning: pair it with labels, icons, or shapes. These are starting tokens and must be checked in the final rendered app for WCAG 2.2 AA contrast.

| Token | Light value | Usage |
| --- | --- | --- |
| `color.background` | `#F6F8F5` | Main page canvas |
| `color.surface` | `#FFFFFF` | Cards, sheets, dialogs |
| `color.surface.subtle` | `#EAF0EC` | Secondary panels, selected rows |
| `color.text.primary` | `#17231F` | Main text and headings |
| `color.text.secondary` | `#52615A` | Supporting text, labels |
| `color.text.disabled` | `#69756F` | Disabled content; recheck contrast in context |
| `color.primary` | `#256D5B` | Primary button, selected navigation, links |
| `color.primary.strong` | `#174C3D` | High contrast primary controls / pressed state |
| `color.primary.container` | `#DDEFE7` | Selected card background; use dark text |
| `color.focus` | `#176B55` | Focus phase label, ring, progress indicator |
| `color.rest` | `#235C9B` | Rest phase label, icon, progress indicator |
| `color.warning` | `#8A5A00` | Caution, schedule conflict |
| `color.error` | `#B42318` | Validation errors, destructive actions |
| `color.success` | `#216E45` | Saved/completed confirmation |
| `color.border` | `#D8E1DC` | Outlines, dividers |
| `color.overlay` | `#101915` at 48% | Modal and bottom-sheet scrim |

**Dark theme:** Follow system theme by default and provide a user override. Define semantic dark tokens rather than inverting the light values: background `#101915`, surface `#18221D`, subtle surface `#23312A`, primary text `#F1F5F2`, secondary text `#BECBC3`, primary `#77C6A7`, focus `#77C6A7`, rest `#8DBBFA`, warning `#F0C36A`, error `#FF8A80`, border `#34433A`. Recheck every foreground/background pair for contrast; do not assume these example values pass without measurement.

### 14.2 Type, spacing, shape, and interaction tokens

- **Typography:** Use platform-native system sans fonts (Roboto on Android, SF on iOS) for accessibility and familiarity. Map semantic roles, not hard-coded font names: Display 32/38 semibold, Page title 28/34 semibold, Section title 20/26 semibold, Body 16/24 regular, Body small 14/20, Label 12/16 medium, Timer 56/64 semibold (scale down responsively). Respect system text scaling; wrap or reflow rather than clip.
- **Spacing:** 4-unit base scale: 4, 8, 12, 16, 24, 32. Standard page side padding 20 (compact devices may use 16); card internal padding 16; section gap 24; dense list row vertical padding 12.
- **Corners:** 12 radius on standard cards and inputs; 16 on feature cards; 24 on bottom sheets; pill radius for chips and phase labels. Do not mix arbitrary radii.
- **Elevation:** Prefer surface contrast and borders; use subtle elevation only for floating timer control and modal sheets. Avoid heavy shadows.
- **Touch targets:** At least 48 dp Android / 44 pt iOS for primary interactions. Provide adequate spacing between adjacent destructive or mutually exclusive controls.
- **Motion:** 150–250 ms for small state changes, with no essential information conveyed only through animation. Respect Reduce Motion. Timer digits update without a continuous flashing animation.
- **Icons:** Use one consistent platform-appropriate outlined icon family, 24 dp/pt default. Always add accessible text labels for icon-only controls.
- **Buttons:** Primary filled evergreen, secondary tonal, tertiary text, destructive outlined/error. Buttons have default, pressed, focused, disabled, loading, and error states. A disabled button remains readable and includes a nearby explanation if the reason is not obvious.
- **Forms:** Labels remain visible above fields; placeholders are examples only. Put validation next to the relevant field and preserve entered values on recoverable errors.

### 14.3 Responsive layout and platform behavior

- Design phone-first for widths from 320 logical pixels. Use safe-area insets for status/navigation bars, camera cutouts, and bottom gesture areas.
- For standard phone screens, use one scrollable column. Never place essential actions below an unpredictable keyboard without scrolling them into view.
- On large phones/tablets, constrain reading columns to approximately 600 logical pixels and center them; use a wider two-column layout only for the weekly plan and history where it improves scanning.
- Keep navigation and action names consistent across Android and iOS. Let platform conventions control system back gestures, permission prompts, date/time pickers, sheets, and lock-screen presentations.
- Do not simulate a system permission dialog. Explain why notifications/Live Activities help immediately before asking the OS for permission; offer a usable in-app timer if declined.
- Support orientation changes without losing timer or unsaved form state. Portrait is the designed default; landscape remains functional.

### 14.4 Navigation model

Use a persistent bottom navigation bar with four destinations:

1. **Today** — current date, current session, quick start, today’s plan, daily review.
2. **Plan** — weekly schedule and plan editing.
3. **Insights** — Activity and Android-only Screen time views, including the yearly heatmap.
4. **Profile** — profile editing, appearance, account, privacy, terms, notifications, and help.

The active session is not a fifth tab. When a session is running and the user leaves the timer screen, show a compact persistent timer chip above the bottom navigation (activity name, phase icon/label, remaining time). Tapping it returns to the active session. Hide the chip when there is no active session or when the current screen already shows the full timer. Back navigation from a modal/editor returns to the originating context and preserves draft data.

### 14.5 Page specifications

#### A. Sign-in and first-run setup

**Purpose:** Explain the value, authenticate, collect only the profile details required to personalize the app, and set local preferences.

**Layout:** Brand mark/title and one-sentence benefit at top; primary sign-in method(s) as large buttons; short privacy summary and links to terms/privacy; secondary “Already have an account? Sign in” only when relevant. After successful sign-in, a short setup page asks for display name (pre-filled only when a verified identity provides one) and timezone/locale. Do not ask for gender or date of birth in MVP.

**Actions:** Sign in, continue setup, change timezone/locale, open privacy notice. Authentication is handled by the identity provider SDK. Keep redirect/cancel behavior clear.

**States:** Loading sign-in, provider unavailable, user cancelled, network failure, invalid/expired provider response, account pending deletion. Never display raw identity-provider error payloads.

#### B. Today dashboard

**Purpose:** Answer “What can I start now?” and make a day review easy to find.

**Top-to-bottom layout:**

1. Top app bar with date/day and profile avatar button. Greeting is optional and short.
2. If a session is active: a prominent current-session card with phase label, remaining time, and “Return to timer”; do not show another Start action as the dominant card.
3. “Quick start” horizontal card grid/list of 3–4 recent/favorite templates showing user-selected icon, name, total duration, and “Automatic focus & rest.” Add a separate “Choose activity” action.
4. “Today’s plan” ordered list with time (if configured), activity name, duration, and state. Each row has a clear Start action or overflow actions. Empty state offers “Plan your week” and “Start an activity.”
5. Daily progress summary showing focus time and completed planned items, using values and labels rather than a pressure-inducing score or streak.
6. “Review your day” card, available even when no activity was planned or completed. If saved, show “Edit review” and saved state.

**Actions:** Start quick template; open activity picker; open activity/template editor; start or skip a planned occurrence; open session; open daily review; navigate to weekly plan.

**States:** First day/no templates, no planned items, offline with cached data, sync pending, active session, all items complete, no activity completed. Keep layout stable; use concise empty-state explanations and one direct next action.

#### C. Activity picker

**Purpose:** Select a reusable activity with minimal effort.

**Layout:** Page title “Choose an activity”; search field when there are enough items to search; “Quick picks” built-ins as list/cards; “Recent” list; “My activities” list; clear “Create custom activity” button. Each item shows name, category (optional), total duration, focus/rest format, and a non-color cue for its format.

**Actions:** Tap a template to open a start preview; long-press/overflow for edit, duplicate, archive; choose “Custom activity.” No timer begins merely from browsing or editing.

**States:** Loading, none created (show built-ins), no search results, offline cache, archived item unavailable.

#### D. Start preview and custom activity editor

**Purpose:** Verify the task and its time blocks before the timer begins.

**Layout:** Activity name field; user-selected icon picker; category selector (optional); planned total duration stepper; and an informative automatic focus/rest summary. The summary must explain that the user selects only total duration and the app calculates focus/rest blocks.

**Automatic schedule preview:** Display whole-minute examples without exposing editable phase controls. A 60-minute plan previews “50 min focus · 10 min rest.” A 90-minute plan previews two 40-minute focus blocks separated by 5-minute breaks, followed by the optional long-rest recommendation. The accessible label includes the complete schedule and total duration.

**Actions:** Change name, icon, category, or total duration; preview; start; save as new template; update existing template only after explicit “Save changes”; cancel/back.

**Validation:** Name 1–80 characters and duration 1–480 minutes. Show inline errors and do not erase valid values.

#### E. Active session

**Purpose:** Keep attention on the current phase and provide safe, obvious timer controls.

**Layout:** Top bar with close/minimize (session continues) and activity title. Centered phase label (“Focus” or “Rest”) with an accessible large countdown and progress ring/bar. Under it, show next phase and duration (“Rest · 5 min next”) and session total elapsed/planned time. The primary control toggles Pause/Resume. Show a separate destructive **Delete session** button; it opens a confirmation and does not compete with the primary control. Do not show Skip phase or Finish now controls.

**Timer behavior:** The displayed countdown is derived from a target timestamp and monotonic elapsed time, never incremented as the only source of truth. On phase transition, change label, color, progress semantics, and the lock-screen surface. Announce phase changes politely for screen readers and optionally use haptics only if enabled/system setting permits.

**Lock screen:** Show activity name (truncate safely), Focus/Rest, remaining time, and pause/resume if platform supports it. Do not show private notes. If OS surface unavailable or denied, show a one-time non-blocking explanation and keep the timer in-app. Explain that the OS controls exact refresh and display behavior.

**Actions:** Pause, resume, delete/cancel. Delete session requires confirmation, records status `cancelled` with actual focus/rest time, and returns to Today after acknowledgement. Completed status is reached only when the generated schedule ends. Every action confirms state change immediately; do not require network for local response.

**States:** Focus running, rest running, paused, offline, sync pending, restoring after process restart, clock discrepancy, session completed, phase notification unavailable, Live Activity/notification denied, expired/stale OS surface. For sync errors, keep local state and show retry status without interrupting focus.

#### F. Session completion summary

**Purpose:** Close the loop without forcing journaling after every task.

**Layout:** Clear “Session complete” or “Session ended early”; activity name; planned vs actual focus/rest durations; completed cycles; optional short note field only if product approves adding session notes; buttons “Done,” “Start another,” and return to Today. Make “Start another” secondary so completion can be dismissed quickly.

**Actions:** Save/acknowledge; start another template; open today report. Session result is saved automatically; no separate save button for timer data.

**States:** Saved, offline queued, save retry, duplicate completion replay. Avoid celebratory overload; use brief restrained visual feedback.

#### G. Plan overview (week)

**Purpose:** Create a reusable weekly structure and let users adjust individual days.

**Layout:** Header with week range and previous/next controls; timezone label; horizontal day selector with accessible day/date names; selected-day ordered schedule list; “Add activity” action; optional weekly summary. Each entry shows local time or “Any time,” name, planned duration, and reorder handle. On phones, show one selected day at a time; on wide screens, allow a week-at-a-glance grid.

**Actions:** Select day, add activity, reorder, edit time/duration, copy day, clear day (confirmation if populated), pause/archive plan, save. Changes to recurring plan apply to future occurrences and never rewrite completed history.

**States:** New empty week, populated, read-only offline cache, save in progress, conflict (another device updated), timezone changed, date with skipped/unstarted/completed occurrences. Conflict resolution offers reload or review local edits; never silently overwrite.

#### H. Add/edit a plan entry

**Purpose:** Add one activity to a weekday schedule.

**Layout:** Activity selector; optional start-time picker; duration preview; optional “repeat this activity on…” weekday controls only if the interaction remains clear; Save button. Use native date/time pickers where practical.

**Actions:** Select template, set time, reorder after saving, save/cancel. If editing a built-in/custom template from here, keep the user’s plan draft intact when returning.

**Validation:** One entry per list position; duplicate activities are allowed if intentional; time is local to plan timezone; prevent invalid or missing template references.

#### I. Daily review

**Purpose:** Let a user describe the day in their own words, especially why planned tasks did not happen.

**Layout:** Date heading and concise prompt; optional mood chips “Positive,” “Mixed,” “Difficult” and “Skip”; text area “What happened today?”; optional tags/reason checklist with “Other” free text if enabled; prompt cards “What went well?” and “What got in the way?”; Save button. Show brief activity summary above the writing area if available. Permit save when no sessions or plans exist.

**Interaction:** Autosave draft locally while typing; explicit Save confirms sync; editing an existing date loads the existing review. Deleting a review is a separate action with confirmation. Keep saved notes private; do not place review text in notification previews or lock-screen surfaces.

**States:** Empty, draft, saving, saved, offline queued, merge conflict, validation (5,000-character limit), date with no activities, read-only while export/deletion is processing.

#### J. Insights

**Purpose:** Review completed Dream Force activity and, on Android only, screen-time summaries without turning either into a leaderboard.

**Layout:** The third bottom-navigation destination is Insights, not History. It opens with Activity selected and provides an Android-only Screen time segment. The yearly comparison heatmap remains visible while Day, Week, Month, and Year update the active summary, donut chart, and breakdown. Do not ship the previous standalone History screen.

**Actions:** Change Activity/Screen time source, change period, inspect a category/app breakdown, and open the current day’s detail when available. No global search over reflection text in MVP.

**States:** No activity, Usage access not granted/revoked, loading, offline cached data, partial Android results, and unavailable app records.

#### K. Profile, settings, privacy, and support

**Layout:** Profile header with an explicit “Edit profile” action for display name and avatar. Edit profile includes optional Gender, Date of birth, Country, City, Profession, and Time zone fields, as well as the read-only verified Google account. Settings groups: Appearance (system/light/dark), Time & language (timezone, locale, week start), Timer (automatic focus/rest explanation, sound/haptics, phase notifications), Account (verified Google identity and sign out), Privacy (export data, delete account, privacy policy), Terms and Conditions, Help and support.

**Actions:** Save profile fields; change preferences; request OS notification permission after explanation; export data; delete account with clear consequence and final confirmation; sign out. Support route opens a contact method without exposing journal entries by default.

**States:** Save pending/success/error, identity provider unavailable, export queued/ready/expired, deletion pending/finalized, permission denied with link to system settings where supported.

### 14.6 Shared component behavior and action rules

- **Cards:** Entire card is tappable only when it performs one clear action. If a card contains multiple actions, make each a separate labeled control; avoid nested tap targets.
- **Lists:** Stable ordering and labels; provide separators or spacing. Swipe gestures are optional shortcuts only; equivalent visible actions must exist.
- **Bottom sheets/dialogs:** Use for short choices or confirmations, not for multi-step forms. Provide explicit title, close/cancel, and action labels.
- **Confirmation:** Confirm destructive actions such as delete session, clear a populated day, delete review, sign out if unsynced data exists, and account deletion. Do not require confirmation for ordinary start/pause/resume actions. For session deletion, explain that elapsed time is retained in history as cancelled.
- **Toasts/snackbars:** Use for brief non-blocking feedback (“Saved,” “Copied”). Do not use them as the only validation/error message or for content the user needs to act on later.
- **Session notifications:** At a phase boundary, issue a concise local notification such as “Great job! You have completed a focus period.” Include the activity name only when the device’s notification privacy setting allows it. The notification is a best-effort OS surface; the session state remains authoritative in the app.
- **Loading:** Keep known content visible during refresh; use skeletons only for initial load. Disable duplicate submission while a write is pending and indicate progress.
- **Offline:** Distinguish offline and server error. Keep safe local work usable. Show “Saved on this device; sync pending” when applicable; never falsely claim server sync completed.
- **Empty states:** State what is empty and offer one relevant action. Use supportive neutral language, no guilt or gamified pressure.
- **Error recovery:** Keep user-entered values and provide retry. Use plain language plus a request ID only in technical/support details.
- **Accessibility:** Name every control; announce dynamic timer phase changes; mark progress values with accessible labels; support system text scaling and screen readers; ensure focus order follows visual order; do not trap focus in sheets.

### 14.7 Frontend design acceptance checklist

- Every page named in §14.5 has default, loading, empty, error, and offline behavior where relevant.
- Every visible action has a defined result, feedback, and back/cancel route; actions requiring confirmation are listed in §14.6.
- One active session is visually and logically dominant; timer remains recoverable after backgrounding, process restart, and network loss.
- Focus and rest states differ by text label, icon/shape, and color; color alone is never the signal.
- Every screen fits 320 logical-pixel width and supports system text scaling without clipped actions or text.
- Primary controls meet platform touch-target guidance; text contrast is measured in final theme combinations, with WCAG 2.2 AA targets of at least 4.5:1 for ordinary text and 3:1 for large text.
- System permission denial, OS lock-screen unavailability, and notification settings do not block core timer use.
- Private review text and email never appear in lock-screen content, analytics payloads, ordinary logs, or public screen previews.
- Tokens are implemented centrally as semantic design tokens for both light and dark themes; individual pages do not introduce one-off color values.
- The same labels, control order, and state model are used on Android and iOS, with native adaptations for each OS surface.

### 14.8 Design handoff for Figma and implementation

When Figma generation is approved, create an organized file with pages for `00 Foundations`, `01 Components`, `02 User Flows`, and `03 Screens`; use the semantic color/type/spacing tokens in §14.1–14.2; include light and dark variables; show loading, empty, error, offline, and disabled states for shared components; and create phone frames for the smallest supported viewport plus one current standard phone size. Annotate native-only behavior (Android ongoing notification and iOS Live Activity) rather than drawing a fake universal lock screen. Link each screen to the relevant requirements in this PRD. The design must be reviewable before any implementation-specific deviations are made.

**Figma generation status:** Not started; wait for explicit product-owner approval of this text direction.

### 14.9 Accessibility reference

Use [WCAG 2.2](https://www.w3.org/TR/WCAG22/) as the accessibility reference for color contrast and use of color. WCAG 2.2 AA requires at least 4.5:1 contrast for ordinary text and 3:1 for large text; final colors must be measured in the implemented foreground/background pair, not assumed from a palette swatch.

## 15. Android app usage dashboard (addendum)

### 15.1 Scope and platform behavior

- Dream Force activity (timer sessions, plans, and daily reviews) remains available on both Android and iOS and continues to use the account sync described in this PRD.
- This release adds optional tracking of time spent in other apps on Android only. iOS must not show an other-app screen-time dashboard, setting, permission prompt, or substitute tracking method in this release. iOS History continues to show Dream Force activity only.
- Android Usage Access and per-account screen-time cloud sync are separate, strictly opt-in choices. Core Dream Force timer, plans, reviews, and history work when a user declines or later revokes either permission or sync consent.
- Keep Dream Force activity and other-app usage visually distinct in the Android dashboard. Label each source; never combine them into a single “productive time” score.

### 15.2 Android permission and lifecycle

Android uses `UsageStatsManager` with the special app access represented by `android.permission.PACKAGE_USAGE_STATS`. This is not an ordinary runtime permission dialog. Explain the purpose and local storage behavior in-app first, then open `Settings.ACTION_USAGE_ACCESS_SETTINGS` only after the user taps “Open Usage access settings.” The user grants access in Android Settings and returns to the app. On resume, re-check `AppOpsManager`/the platform authorization state; do not infer that access was granted merely because Settings was opened.

States and actions:

1. **Not enabled:** Explain that Android Usage access allows Dream Force to read aggregate usage summaries by app for the device, including Dream Force if returned by Android. Provide “Open Usage access settings” and “Not now.” Do not auto-launch Settings or gate core app use.
2. **Enabled:** Load the selected date range and show the latest refresh time. Refresh when the dashboard opens and when the user explicitly pulls to refresh, subject to OS data availability and a reasonable refresh throttle.
3. **Revoked:** Stop querying immediately, retain the user’s locally cached summary only if the product still labels it as stale, display “Usage access is off,” and provide a settings shortcut. Do not silently continue to present cached values as current.
4. **No data / unsupported interval:** Explain that Android has no usage data for the selected period yet and allow changing the range. Do not display misleading zeroes as confirmed inactivity.
5. **Settings unavailable or query error:** Keep Dream Force features usable; show a recoverable error and a retry action.

Use Android's calendar-aligned `UsageStatsManager.INTERVAL_DAILY` aggregates for per-day summaries, preserving the device's IANA timezone and local date. These are OS-provided estimates and may be delayed or incomplete; do not promise second-by-second accuracy, foreground activity surveillance, or guaranteed coverage for every app/device. Do not upload event timelines. The Screen time view includes all app records returned by Android, including Dream Force when Android provides a record for it. Only show app labels/icons that Android can resolve; handle removed/unavailable packages as “App no longer available.”

### 15.3 Dashboard requirements

The Android History/Insights area has two primary views: **Activity** and **Screen time**. Activity means completed Dream Force focus-session time only, grouped by the user's Dream Force activity categories. Do not silently include plans, rest periods, manual/non-timer time, or general phone use in Activity totals. Screen time uses Android's per-app usage totals. These views remain distinct. The Activity view is available on iOS with Dream Force data only; the comparison heatmap and Screen time view are Android-only.

The Android view includes:

- Period selector: Day, Week, Month, and Year, with dates in the device’s local time zone. Changing the period updates the active view’s total, chart, and category/app breakdown.
- Activity breakdown by Dream Force category for the selected range.
- Screen time breakdown listing all apps with an available Android usage summary, including Dream Force if returned, with app icon/neutral fallback, display name, duration, and share of observed total; list is scrollable.
- A GitHub-inspired daily calendar heatmap that stays visible for every selected period. It always shows daily comparisons for the selected year; changing Day/Week/Month/Year updates the active view summary/chart/breakdown while leaving the yearly heatmap in place. For each day calculate `delta_seconds = completed_dream_force_focus_seconds - android_app_usage_seconds`. Positive values use progressively stronger green shades; negative values use progressively stronger red shades; zero uses a neutral shade. Shade intensity represents absolute delta magnitude. Include a text legend and a non-color explanation. The heatmap is a comparison signal, not a 24-hour budget or a sum of mutually exclusive activity buckets.
- A donut chart above the heatmap that shows the active view’s distribution by Dream Force activity category or Android app, depending on the selected Activity/Screen time view. Changing the period updates its segments and legend values. Use the same stable color for an activity/app in the donut, category/app list, and app usage bar.
- Show one total for the active view and a visible “Updated …” timestamp for Android data. Do not show a combined Activity total, Screen time total, and delta callout together.
- No score, warning, judgment, productivity ranking, or unsolicited intervention.
- A short privacy explanation and a “Manage Usage access” action. Include an explicit “Clear usage history on this device” action with confirmation.
- Empty, loading, stale, access-needed, access-revoked, partial-data, and error states described in §15.2.

For accessibility, duration is available as text, not only chart geometry or color. If a chart is added, label axes and provide an equivalent list/summary. Do not use red/green judgment colors.

### 15.4 Privacy and storage boundary

Other-app usage is sensitive device activity data. The Android dashboard may work locally without cloud sync. Account sync is default-off and requires a separate, affirmative, versioned consent that names the uploaded fields and purpose. The consent is shown during account creation and can be managed later in Insights. Android Usage Access remains a separate OS permission; neither choice implies the other.

After both choices are enabled, upload only per-local-day app aggregates `(user_id, local_date, IANA timezone, package identifier, available app label, usage seconds, queried_at)` to the signed-in user's private account for cross-device Screen time Insights. Do not upload foreground event timelines, screen contents, notification contents, or an installed-app list. Do not include package names, labels, or per-user usage in logs, crash reports, support tooling, notifications, or lock-screen surfaces. Admins cannot inspect individual usage rows; CRM Top 10 remains a separate anonymous aggregate.

Turning off cloud sync immediately blocks further uploads and deletes that user's uploaded app-usage rows. The consent version, grant time, and revocation time remain as a minimal consent audit. Account export includes the owner's daily usage rows, never a raw timeline; account deletion cascades to all account usage rows. Clearing device history removes only the local cache; explain that this does not delete the account copy, and offer the cloud-sync off/delete action separately. If local app data is cleared or the app is uninstalled, the local cache is removed by Android. Access revocation disables new reads and refreshes. Use encrypted app-private storage where supported and exclude the cache from device backup.

### 15.5 API contract and local repository

The per-user cloud endpoint is only available after the user has granted screen-time sync consent. It accepts daily aggregates and never accepts a raw foreground event timeline. It is owner-scoped and returns only the authenticated user's data. The anonymous CRM Top 10 aggregate remains a separate contract and cannot be joined to an individual account. Android client repository contract:

```text
GET local://device-usage?from=YYYY-MM-DD&to=YYYY-MM-DD
  -> DeviceUsageSummary

POST local://device-usage/refresh?from=YYYY-MM-DD&to=YYYY-MM-DD
  -> DeviceUsageSummary | permission_required | no_data | query_error

DELETE local://device-usage
  -> 204 No Content

PUT /v1/me/screen-time
  -> upsert consented local-day app aggregates for the authenticated account

GET /v1/me/screen-time?period=day|week|month|year&timezone=IANA_ZONE
  -> the authenticated user's app-level summary for that local period
```

The `local://` operations are illustrative app-internal operations. `DeviceUsageSummary` is derived from Android Usage Stats API and the local store. HTTP operations require valid Dream Force authentication and persisted consent:

```json
{
  "platform": "android",
  "from": "2026-11-10",
  "to": "2026-11-10",
  "timezone": "Asia/Dhaka",
  "total_observed_seconds": 10800,
  "updated_at": "2026-11-10T12:45:00+06:00",
  "data_status": "available",
  "apps": [
    { "package_name": "com.example.reader", "label": "Reader", "usage_seconds": 5400, "share_percent": 50.0 },
    { "package_name": "com.example.browser", "label": "Browser", "usage_seconds": 3600, "share_percent": 33.3 }
  ]
}
```

`data_status` values: `available`, `partial`, `stale`, `no_data`, `permission_required`, `query_error`. The app computes percentages from returned usage and guards the zero-total case. The remote upload contains only each app's local date, IANA timezone, package identifier, available label, and aggregate usage seconds, plus the query time. It contains no event timeline or device identifier. `data_status` and computed percentages are UI values and are not serialized as usage records.

### 15.6 Android local database schema

The following Room/SQLite table is an encrypted device cache and is separate from the PostgreSQL schema in §9. Store per-local-day aggregates, not event timelines:

```sql
CREATE TABLE device_app_usage_daily (
  local_date TEXT NOT NULL,             -- ISO-8601 date in the recorded timezone
  timezone_id TEXT NOT NULL,            -- IANA zone used for this aggregation
  package_name TEXT NOT NULL,
  app_label TEXT NOT NULL,
  usage_seconds INTEGER NOT NULL CHECK (usage_seconds >= 0),
  queried_at TEXT NOT NULL,             -- ISO-8601 timestamp with offset
  PRIMARY KEY (local_date, timezone_id, package_name)
);

CREATE INDEX device_app_usage_date_idx
  ON device_app_usage_daily(local_date, timezone_id);
```

Upsert the daily aggregate after successful queries. Retain at least 400 days so the year view can render a full calendar year, including leap years and date-boundary refreshes. When cloud consent is enabled, sync daily aggregate rows to the user's account. Clear rows on the confirmed device clear action; this does not delete the cloud copy. Migration and backup policy must preserve the encrypted local cache.

### 15.7 Acceptance criteria and references

- Android users can open app usage from History and opt in through a clear in-app explanation and Android Settings. Returning from Settings re-checks the actual authorization state.
- Denial/revocation never blocks or degrades Dream Force session tracking. Revocation is reflected before any new app-usage query.
- Android app usage is sourced from `UsageStatsManager` daily interval aggregates. Upload is disabled until the user separately consents to account sync and Android Usage Access is granted. Uploaded data is per-user and owner-readable only; CRM Top 10 remains a separate anonymous aggregate.
- iOS contains no other-app usage UI, API integration, or tracking mechanism in this release.
- Crash, support, and ordinary analytics payloads contain no package names, app labels, or other-app durations. The screen-time endpoint accepts only consented, daily, per-app aggregates for the user's private Insights; it accepts no raw timeline or device identifier.
- Clear-device-usage removes all local rows after confirmation. Stale and partial data are labeled plainly.
- [Android `UsageStatsManager`](https://developer.android.com/reference/android/app/usage/UsageStatsManager) documents usage query APIs and the `PACKAGE_USAGE_STATS` access requirement.
- [Android special permissions](https://developer.android.com/training/permissions/requesting-special) documents the Settings-based grant flow and user-driven request pattern.
- [Android `Manifest.permission`](https://developer.android.com/reference/android/Manifest.permission#PACKAGE_USAGE_STATS) documents the usage access permission.

### 15.8 Comparison and aggregation rules

- Activity is the sum of completed focus-phase seconds from Dream Force sessions, grouped by the session's saved activity/category snapshot and local day. A paused duration contributes only when the timer records it as focus time; planned time, rest time, cancelled/uncompleted time, and non-session activities do not contribute.
- Screen time is the sum of Android UsageStats results by package for the same local calendar day and time zone. On the Screen time tab, show all app records available for the selected range, including Dream Force when Android returns it; label unavailable app names clearly. Use the total of all returned app usage for the comparison delta.
- `delta_seconds = activity_focus_seconds - all_app_usage_seconds`. The delta may be positive or negative and is not constrained to fit within 24 hours because the two sources describe different, potentially overlapping measures and Android usage summaries may be incomplete.
- Use fixed magnitude bands for comparable cell shades: 0 is neutral, 1–<30 minutes is level 1, 30–<60 minutes level 2, 1–<2 hours level 3, and 2+ hours level 4. Direction sets green (positive) or red (negative). Include the numerical delta for the selected day; shade must not be the only way to understand a value.
- Day, week, month, and year selectors aggregate the same source definitions. The year selector displays the daily heatmap plus the yearly category/app breakdown; other periods use an appropriately labeled summary/chart and breakdown.
- For iOS, keep the Activity aggregation and category breakdown. Do not attempt the `A − S` heatmap until an iOS app-usage source is explicitly scoped for a future release.

### 15.9 Chart and category color tokens

Use these stable colors so the category/app identity is recognizable in the donut, legend, and list. Keep text labels and values visible so color is not the only way to identify a series.

**Dream Force activity categories:** Study `#2F7D62`; Coding `#3974C5`; Reading `#D18A1F`.

**Android app colors:** Reader `#E56B54`; Browser `#3975C6`; Music `#7B59C9`; Dream Force `#28775F`; Chat `#D97706`; Maps `#0E8A9D`; Social `#D84C7A`; Email `#426DAA`; Video `#C75435`; Calendar `#458B56`; News `#A67B13`; Photos `#7655A2`; Notes `#327B6C`; Banking `#347794`; Weather `#3974AA`; Camera `#B44D4D`; Settings `#65727B`; Phone `#3D8758`. The donut may group non-top apps as “Other apps” with neutral `#7B8790`, while the full app list gives each app its own color.
