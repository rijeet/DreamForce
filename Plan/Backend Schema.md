# Backend Schema: Dream Force

**Database:** Neon serverless PostgreSQL  
**API runtime:** Vercel Functions / Next.js Route Handlers  
**Ephemeral store and rate limiting:** Upstash Redis  
**Async delivery:** Upstash QStash to signed Vercel job routes  
**Scope:** MVP persistent backend data. Raw Android third-party-app usage stays on-device by default. Only users who explicitly opt in to anonymous analytics contribute daily app-level aggregates for the admin Top 10 report; admins cannot inspect an individual user's installed-app list or usage timeline.

## Authentication flow

1. **User sign up:** A standard user acknowledges Privacy Policy and Terms, then chooses **Continue with Google**. The Flutter app uses Google OpenID Connect Authorization Code with PKCE. The API validates issuer, audience, signature, expiration, and subject. If the Google subject is unknown, it creates `users`, `user_profiles`, and `user_settings` in one transaction with `role = 'user'`.
2. **Login:** Standard users sign in with Google. Admins are created only by a protected bootstrap/provisioning script with email and password; their password is stored exclusively as an Argon2id hash. Both flows create an `auth_sessions` row and return a short-lived access token plus an opaque, rotated refresh token. The mobile app stores tokens only in Android Keystore/iOS Keychain.
3. **Session / token:** Access token is a signed JWT with `sub = users.id`, issuer, audience, expiry, and a session identifier. API routes require `Authorization: Bearer <access_token>`. Refresh sends the opaque refresh token; the server hashes it, validates the session, rotates it, and revokes the previous token.
4. **Logout and password reset:** Logout revokes the current `auth_sessions` record and deletes local secure tokens. Standard users recover access through Google. Admin password reset is an operator-only, audited provisioning-script action; no public admin-registration or password-reset endpoint exists. “Sign out of all devices” revokes all active sessions for the user.

## Data conventions

- All IDs are UUIDs generated server-side unless documented as client-generated event IDs.
- All timestamps are `timestamptz` in UTC; local schedule data also stores IANA timezone and local date/time. Recurring weekly occurrences are lazily materialized only for the requested range (maximum rolling 14 days), using the saved IANA timezone so daylight-saving transitions resolve at materialization time rather than from stale future UTC instants.
- `created_at` is immutable; `updated_at` changes on each mutation.
- User-owned rows are always queried with `user_id = authenticated_user_id` in the database query itself.
- Activity/session history uses snapshots so later template changes do not rewrite historic records.
- `version` supports optimistic concurrency; mutable API writes require `If-Match` or the current version.

## Tables

### users

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid | Primary key |
| email | text | Latest identity-provider email; private |
| email_normalized | text | Unique normalized email for account recovery/support |
| email_verified_at | timestamptz | Null until verified by provider |
| role | varchar(16) | `user` by default; `admin` only through provisioning script |
| google_subject | text | Unique Google OIDC subject for standard-user authentication; nullable for script-created admins |
| password_hash | text | Argon2id hash; nullable and permitted only for script-created admins |
| display_name | varchar(80) | User-visible name; nullable during first run |
| avatar_url | text | Optional provider or approved avatar reference |
| locale | varchar(35) | Default `en` |
| status | varchar(24) | `active`, `deletion_pending`, `deleted`, or `suspended` |
| created_at | timestamptz | Creation time |
| updated_at | timestamptz | Last change time |
| deleted_at | timestamptz | Soft-delete/tombstone time; nullable |

Constraints: `role` is `user` or `admin`; `google_subject` is unique; a `user` requires `google_subject` and no password hash; a script-created `admin` requires `password_hash`. The provisioning script is the only writer permitted to create an admin.

### user_profiles

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid | Primary key |
| user_id | uuid | Unique FK to `users.id`; one profile per user |
| gender | varchar(80) | Optional; private |
| date_of_birth | date | Optional; private; minimum date validation in migration |
| country | varchar(100) | Optional; private |
| city | varchar(100) | Optional; private |
| profession | varchar(120) | Optional; private |
| timezone | varchar(64) | IANA timezone, default `UTC` |
| created_at | timestamptz | Creation time |
| updated_at | timestamptz | Last change time |

### auth_sessions

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid | Primary key; included in access-token claims |
| user_id | uuid | FK to `users.id` |
| refresh_token_hash | bytea | Hash only; never store plaintext refresh token |
| user_agent | varchar(500) | Optional, privacy-reviewed device context |
| created_at | timestamptz | Session creation time |
| last_used_at | timestamptz | Last successful refresh/use |
| expires_at | timestamptz | Hard expiry |
| revoked_at | timestamptz | Null until logout/revocation |
| replaced_by_session_id | uuid | Self-FK for token rotation lineage; nullable |

### user_settings

| Column | Type | Notes |
| --- | --- | --- |
| user_id | uuid | Primary key and FK to `users.id` |
| theme_preference | varchar(12) | `system`, `light`, or `dark` |
| phase_notifications_enabled | boolean | User preference; OS permission is separate |
| sound_enabled | boolean | Timer sound preference |
| haptics_enabled | boolean | Timer haptic preference |
| live_activity_enabled | boolean | iOS preference where supported |
| analytics_app_usage_opt_in | boolean | Default false; permits anonymous app-level aggregate contribution only |
| week_starts_on | smallint | 1–7, Monday default |
| updated_at | timestamptz | Last change time |

### activity_templates

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid | Primary key |
| owner_user_id | uuid | Nullable FK to `users.id`; null only for built-in templates |
| name | varchar(80) | Required activity name |
| icon_key | varchar(40) | Stable app icon identifier, e.g. `book`, `code` |
| category | varchar(40) | Optional user category |
| planned_minutes | smallint | 1–480 total minutes |
| is_builtin | boolean | Global read-only template when true |
| created_by_admin_id | uuid | Nullable FK to `users.id`; set for admin-created global templates |
| archived_at | timestamptz | Soft archive; nullable |
| version | integer | Optimistic concurrency version |
| created_at | timestamptz | Creation time |
| updated_at | timestamptz | Last change time |

### weekly_plans

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid | Primary key |
| user_id | uuid | FK to `users.id` |
| name | varchar(80) | Required plan name |
| timezone | varchar(64) | IANA zone used for future occurrences |
| is_active | boolean | Current plan state |
| version | integer | Optimistic concurrency version |
| created_at | timestamptz | Creation time |
| updated_at | timestamptz | Last change time |

### weekly_plan_templates

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid | Primary key |
| name | varchar(80) | Admin-authored reusable plan template name |
| description | varchar(500) | Optional user-facing description |
| timezone | varchar(64) | Default IANA timezone guidance |
| is_published | boolean | Only published templates are visible to users |
| created_by_admin_id | uuid | FK to admin `users.id` |
| created_at | timestamptz | Creation time |
| updated_at | timestamptz | Last change time |

### weekly_plan_template_entries

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid | Primary key |
| weekly_plan_template_id | uuid | FK to `weekly_plan_templates.id` |
| activity_template_id | uuid | FK to global `activity_templates.id` |
| weekday | smallint | 1–7 |
| position | smallint | Ordered position within weekday |
| local_start_time | time | Optional suggested time |
| planned_minutes_override | smallint | Optional 1–480 minute duration |
| created_at | timestamptz | Creation time |
| updated_at | timestamptz | Last change time |

### weekly_plan_entries

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid | Primary key |
| plan_id | uuid | FK to `weekly_plans.id` |
| template_id | uuid | FK to `activity_templates.id` |
| weekday | smallint | 1–7 |
| position | smallint | Ordered position within weekday |
| local_start_time | time | Optional scheduled local time |
| planned_minutes_override | smallint | Optional 1–480 minute override |
| created_at | timestamptz | Creation time |
| updated_at | timestamptz | Last change time |

Constraints: unique `(plan_id, weekday, position)`.

### plan_occurrences

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid | Primary key |
| user_id | uuid | FK to `users.id` |
| plan_id | uuid | FK to `weekly_plans.id` |
| plan_entry_id | uuid | Nullable FK to `weekly_plan_entries.id` for retained history |
| template_id | uuid | Nullable FK to `activity_templates.id` |
| local_date | date | Date in occurrence timezone |
| timezone | varchar(64) | IANA zone snapshot |
| local_start_time | time | Optional local time snapshot |
| planned_minutes | smallint | 1–480 total duration snapshot |
| name_snapshot | varchar(80) | Template-name snapshot |
| icon_key_snapshot | varchar(40) | Icon snapshot |
| state | varchar(16) | `scheduled`, `started`, `skipped`, `completed`, `unstarted` |
| skip_reason | varchar(500) | Optional private reason |
| created_at | timestamptz | Creation time |
| updated_at | timestamptz | Last change time |

Constraint: unique `(plan_entry_id, local_date)` when `plan_entry_id` is present.

### focus_sessions

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid | Primary key |
| user_id | uuid | FK to `users.id` |
| template_id | uuid | Nullable FK to `activity_templates.id` |
| plan_occurrence_id | uuid | Nullable FK to `plan_occurrences.id` |
| name_snapshot | varchar(80) | Activity-name snapshot |
| icon_key_snapshot | varchar(40) | Activity-icon snapshot |
| category_snapshot | varchar(40) | Optional category snapshot |
| planned_minutes | smallint | Chosen total duration |
| schedule_version | smallint | Automatic scheduling algorithm version |
| status | varchar(16) | `running`, `paused`, `completed`, `cancelled`, `interrupted` |
| current_phase | varchar(16) | `focus`, `rest`, or `finished` |
| current_phase_index | smallint | Zero-based active `session_phases.position`; terminal sessions retain their final position |
| started_at | timestamptz | Session start |
| phase_started_at | timestamptz | Start of the active phase; null only before the first phase starts or after terminal completion |
| phase_target_end_at | timestamptz | Active phase end target; on resume it is shifted forward by the exact paused interval |
| paused_at | timestamptz | Time the active phase was paused; null unless status is `paused` |
| ended_at | timestamptz | Required for terminal states |
| total_paused_seconds | integer | Non-negative accumulated pause time |
| actual_focus_seconds | integer | Non-negative recorded focus time |
| actual_rest_seconds | integer | Non-negative recorded rest time |
| version | integer | Optimistic concurrency version |
| client_timezone | varchar(64) | IANA zone at session start |
| created_at | timestamptz | Creation time |
| updated_at | timestamptz | Last change time |

Constraints: partial unique index permits only one `running` or `paused` session per user; `paused_at` is non-null exactly when status is `paused`; `phase_target_end_at` is non-null exactly when the session is active. The authoritative transition rules are in `Session State Machine Specification.md`.

### session_phases

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid | Primary key |
| session_id | uuid | FK to `focus_sessions.id` |
| position | smallint | Zero-based automatic phase order |
| phase_type | varchar(8) | `focus` or `rest` |
| planned_seconds | integer | Positive phase duration; immutable schedule snapshot |
| started_at | timestamptz | Null until phase begins |
| ended_at | timestamptz | Null until phase ends |
| actual_seconds | integer | Non-negative final elapsed duration |
| created_at | timestamptz | Schedule generation time |

Constraint: unique `(session_id, position)`. The API generates all phase rows on session creation; clients cannot add, skip, or reorder them.

### session_events

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid | Primary key |
| session_id | uuid | FK to `focus_sessions.id` |
| user_id | uuid | FK to `users.id` |
| client_event_id | uuid | Client-generated idempotency identifier |
| event_type | varchar(24) | `started`, `pause`, `resume`, `focus_started`, `rest_started`, `completed`, `cancel`, `interrupted` |
| occurred_at | timestamptz | Client-observed transition time |
| received_at | timestamptz | API receipt time |
| event_payload | jsonb | Strictly allowlisted timing metadata; no journal text |

Constraint: unique `(user_id, client_event_id)`.

### daily_reviews

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid | Primary key |
| user_id | uuid | FK to `users.id` |
| local_date | date | Owner’s local calendar date |
| timezone | varchar(64) | IANA zone |
| mood | varchar(16) | `positive`, `mixed`, `difficult`, or null |
| summary | varchar(1000) | Optional private summary |
| reflection | varchar(5000) | Optional private reflection |
| reason_tags | text[] | Optional private tags |
| version | integer | Optimistic concurrency version |
| created_at | timestamptz | Creation time |
| updated_at | timestamptz | Last change time |

Constraint: unique `(user_id, local_date)`.

### support_tickets

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid | Primary key |
| user_id | uuid | FK to `users.id`; ticket owner |
| assigned_admin_id | uuid | Nullable FK to `users.id` with `role = 'admin'` |
| subject | varchar(160) | Required user-supplied support subject |
| category | varchar(32) | `account`, `billing`, `bug`, `feature`, `other` |
| status | varchar(24) | `open`, `in_progress`, `waiting_on_user`, `resolved`, `closed` |
| priority | varchar(16) | `low`, `normal`, `high`, `urgent` |
| created_at | timestamptz | Creation time |
| updated_at | timestamptz | Last change time |
| resolved_at | timestamptz | Null until resolved |

### support_ticket_messages

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid | Primary key |
| ticket_id | uuid | FK to `support_tickets.id` |
| author_user_id | uuid | FK to `users.id`; owner or admin |
| body | varchar(5000) | Support message; never contains journal content by default |
| is_internal | boolean | Admin-only CRM note when true |
| created_at | timestamptz | Creation time |

### notification_campaigns

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid | Primary key |
| created_by_admin_id | uuid | FK to admin `users.id` |
| title | varchar(120) | User-visible notification title |
| body | varchar(500) | User-visible notification copy |
| audience | varchar(32) | `all_users`, `active_users`, `selected_users` |
| status | varchar(24) | `draft`, `scheduled`, `sending`, `sent`, `cancelled`, `failed` |
| scheduled_for | timestamptz | Optional future send time |
| created_at | timestamptz | Creation time |
| sent_at | timestamptz | Null until delivery starts/completes |

### notification_deliveries

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid | Primary key |
| campaign_id | uuid | FK to `notification_campaigns.id` |
| user_id | uuid | FK to `users.id` |
| channel | varchar(16) | `push` or `in_app` |
| status | varchar(24) | `queued`, `sent`, `delivered`, `failed`, `suppressed` |
| provider_message_id | text | Nullable delivery-provider identifier |
| sent_at | timestamptz | Nullable send time |
| delivered_at | timestamptz | Nullable delivery time |
| failure_code | varchar(80) | Nullable safe error code |

### user_activity_daily

| Column | Type | Notes |
| --- | --- | --- |
| user_id | uuid | FK to `users.id` |
| local_date | date | User-local day |
| timezone | varchar(64) | IANA timezone snapshot |
| completed_focus_seconds | integer | Completed Dream Force focus only |
| completed_session_count | integer | Number of completed sessions |
| planned_completed_count | integer | Completed planned occurrences |
| created_at | timestamptz | Aggregate creation time |
| updated_at | timestamptz | Aggregate update time |

Primary key: `(user_id, local_date)`. Admin CRM may show this only as aggregate operational/product metrics; it does not expose reviews or private profile fields.

### app_usage_aggregate_daily

| Column | Type | Notes |
| --- | --- | --- |
| local_date | date | Aggregate reporting day |
| app_key | varchar(255) | Pseudonymous stable app identifier; raw user/device linkage is not stored |
| app_label | varchar(160) | Display label only when user explicitly opted in |
| user_count | integer | Number of opted-in contributing users |
| total_usage_seconds | bigint | Aggregate app duration across contributors |
| created_at | timestamptz | Aggregate creation time |
| updated_at | timestamptz | Aggregate update time |

Primary key: `(local_date, app_key)`. This table powers Top 10 apps by day/week/month/year. It cannot be joined to a user or used for individual monitoring.

### idempotency_records

| Column | Type | Notes |
| --- | --- | --- |
| user_id | uuid | FK to `users.id` |
| endpoint_key | varchar(120) | Route/action namespace |
| idempotency_key | varchar(255) | Client request key |
| request_hash | bytea | Detects unsafe key reuse with different payload |
| response_status | smallint | Stored final HTTP status |
| response_body | jsonb | Stored replay-safe result; no secrets |
| created_at | timestamptz | Creation time |
| expires_at | timestamptz | Expiry, at least 24 hours for session creation |

Primary key: `(user_id, endpoint_key, idempotency_key)`.

### account_export_jobs

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid | Primary key |
| user_id | uuid | FK to `users.id` |
| status | varchar(16) | `queued`, `processing`, `ready`, `failed`, `expired` |
| artifact_key | text | Private object-storage key; never a public URL |
| requested_at | timestamptz | Request time |
| expires_at | timestamptz | Download/retention expiry |
| completed_at | timestamptz | Completion time; nullable |
| failure_code | varchar(80) | Safe, non-sensitive failure reason; nullable |

### account_deletion_requests

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid | Primary key |
| user_id | uuid | FK to `users.id` |
| status | varchar(16) | `requested`, `scheduled`, `processing`, `completed`, `cancelled`, `failed` |
| requested_at | timestamptz | User confirmation time |
| scheduled_for | timestamptz | Finalization time after grace period |
| completed_at | timestamptz | Null until complete |
| cancelled_at | timestamptz | Null unless user cancels within policy |
| failure_code | varchar(80) | Safe technical/status code; nullable |

### support_access_audit

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid | Primary key |
| support_actor_id | uuid | Authorized support operator identity; not an end-user reference |
| subject_user_id | uuid | FK to `users.id` |
| reason_code | varchar(80) | Required case reason |
| accessed_fields | text[] | Allowlisted metadata only |
| occurred_at | timestamptz | Access time |

## Relationships

- `users` 1 → 1 `user_profiles`
- `users` 1 → 1 `user_settings`
- `users` 1 → many `auth_sessions`
- `users` 1 → many owned `activity_templates`
- `users` 1 → many `weekly_plans`
- `weekly_plans` 1 → many `weekly_plan_entries`
- `users` (admin) 1 → many `weekly_plan_templates`, `activity_templates`, and `notification_campaigns`
- `weekly_plan_templates` 1 → many `weekly_plan_template_entries`
- `activity_templates` 1 → many `weekly_plan_entries`
- `weekly_plan_entries` 1 → many `plan_occurrences`
- `users` 1 → many `plan_occurrences`
- `users` 1 → many `focus_sessions`
- `focus_sessions` 1 → many immutable `session_phases`
- `focus_sessions` 1 → many `session_events`
- `users` 1 → many `daily_reviews`, `idempotency_records`, `account_export_jobs`, and `account_deletion_requests`
- `users` 1 → many `support_tickets`, `support_ticket_messages`, and `user_activity_daily` records
- `support_tickets` 1 → many `support_ticket_messages`
- `notification_campaigns` 1 → many `notification_deliveries`

## Access rules

| Resource | Read | Write |
| --- | --- | --- |
| users / user_profiles / user_settings | Owner only; admin sees only approved CRM metadata, never private profile fields by default | Owner may update allowed profile/settings fields; backend controls role, password hash, account status, and email identity |
| auth_sessions | Owner sees only safe session metadata where exposed | Backend/auth flow only; owner may revoke own sessions |
| activity_templates | Owner reads own templates plus built-ins | Owner creates/updates/archives own templates; built-ins are read-only |
| weekly_plans / entries / occurrences | Owner only | Owner only; completed history is immutable except allowed occurrence state updates |
| focus_sessions / phases / events | Owner only | Owner can create, pause, resume, or cancel own active session; backend generates phases/completion events |
| daily_reviews | Owner only | Owner only; reflection text never enters analytics/support logs |
| idempotency_records | Backend only | Backend only |
| account_export_jobs / deletion requests | Owner sees own status only | Owner creates own request; worker/backend advances status |
| support_tickets / messages | Ticket owner sees public messages on own ticket; assigned admin sees assigned ticket; admins see CRM queue | Owner may create/reply to own ticket; admins may assign, change status, reply, and add internal notes |
| notification_campaigns / deliveries | Admin only; user may see own in-app notification result | Admin creates/schedules/cancels campaigns; QStash worker writes delivery status |
| weekly_plan_templates / template entries | Published templates readable by users; all templates readable by admins | Admin only; user copies a published template into own weekly plan |
| user_activity_daily | Owner may read own derived summary; admins read aggregate CRM queries only | Backend aggregation service only |
| app_usage_aggregate_daily | Admin aggregate reports only | Backend aggregation service only after explicit user opt-in |
| support_access_audit | Security/admin service only | Backend service only |

Every SQL query for a user-owned table includes the authenticated `user_id`. Never authorize by accepting a client-supplied owner ID. Admin authorization requires `role = 'admin'` in the verified session and does not bypass private-review, raw app-usage, or profile-data restrictions.

## Upstash Redis keys

Upstash Redis is not the source of truth. All durable user data stays in Neon PostgreSQL.

| Key pattern | TTL | Purpose |
| --- | --- | --- |
| `rate:{route}:{subjectOrIp}` | Sliding window | API abuse protection |
| `idem-lock:{userId}:{endpoint}:{key}` | Short | Prevent duplicate in-flight work; PostgreSQL persists final replay record |
| `session-revoked:{sessionId}` | Until JWT expiry | Fast access-token revocation lookup |
| `cache:templates:{userId}` | Short | Safe cache of template-list projection |
| `cache:plans:{userId}:{week}` | Short | Safe cache of weekly plan projection |
| `qstash-dedupe:{messageId}` | Job lifetime | Prevent duplicate asynchronous job handling |
| `admin-login:{emailOrIp}` | Sliding window | Brute-force protection for script-created admin credentials |

## Serverless data-flow requirements

- Route Handlers are stateless and may run concurrently; never depend on in-process memory for sessions, locks, timers, or queues.
- Acquire PostgreSQL connections through a serverless-compatible pooled/HTTP driver; release them promptly.
- Use Upstash REST clients from Vercel Functions; do not require a persistent Redis TCP connection.
- Verify every QStash job signature from the raw body before parsing its payload. Job routes require no end-user bearer token and accept ID-only job payloads.
- Use Vercel Cron only to invoke idempotent cleanup/scheduling routes; long work is delegated to QStash.
- Store secrets only as Vercel environment variables, separately scoped for development, preview, and production.
