# Dream Force — Session State Machine Specification

**Status:** Locked before implementation  
**Scope:** Android MVP timer persistence, API contract, offline reconciliation, and recovery

This document is the authoritative behavioral contract for `focus_sessions`, `session_phases`, and `session_events`. It refines `Backend Schema.md`; where the documents differ, this specification wins for session behavior.

## Invariants

- A user has at most one open session (`running` or `paused`).
- The API creates the entire immutable phase schedule atomically. Clients cannot create, skip, reorder, or finish a phase early.
- A standard schedule uses `focus_seconds = round(total_seconds * 5 / 6)` and `rest_seconds = total_seconds - focus_seconds`. A 90-minute schedule is 40 focus / 5 rest / 40 focus / 5 rest.
- The only user transitions are **Pause**, **Resume**, and **Delete session**. Delete is a confirmation-gated cancellation, never a hard delete.
- Server time is authoritative for persistence. The client renders from the returned phase target timestamp plus a monotonic clock while foregrounded.
- Every mutation is idempotent and versioned. A retry returns the original result and never adds a duplicate event or pause interval.

## Persisted state

### `focus_sessions`

The columns in `Backend Schema.md` are required. The timer-specific columns have these exact meanings:

| Column | Meaning |
| --- | --- |
| `status` | `running`, `paused`, `completed`, `cancelled`, or `interrupted` |
| `current_phase` | `focus`, `rest`, or `finished` |
| `current_phase_index` | Active immutable phase position; terminal sessions retain the last position |
| `phase_started_at` | Server timestamp at which the current phase began; null before start/after terminal finalization |
| `phase_target_end_at` | Server timestamp at which the active phase completes while running; shifted only by a resume |
| `paused_at` | Server timestamp of pause; non-null only while `status = paused` |
| `total_paused_seconds` | Sum of completed pause intervals, rounded to whole seconds |
| `version` | Incremented once per accepted state transition |

`session_phases` remains the immutable planned schedule plus the actual start/end and active elapsed duration for each phase. `session_events` is the append-only audit/idempotency ledger. Its `(user_id, client_event_id)` uniqueness constraint is required.

## States and transitions

| Current state | Event | Preconditions | Atomic result |
| --- | --- | --- | --- |
| none | `create` | No open session; valid schedule | Insert session as `running`, all phase rows, first phase start/target times, and `started` + phase-started events |
| running | `pause` | Matches `version`; before auto completion/cancellation | Set `status = paused`, `paused_at = server_now`; append `pause` |
| paused | `resume` | Matches `version` | `pause_delta = server_now - paused_at`; set `phase_target_end_at = phase_target_end_at + pause_delta`, add rounded delta to `total_paused_seconds`, clear `paused_at`, set `running`; append `resume` |
| running | automatic phase boundary | `server_now >= phase_target_end_at` | Finalize active phase; start next immutable phase or complete session; append phase-started or `completed` |
| running or paused | `cancel` | Matches `version`; user confirmed Delete | Finalize elapsed active work excluding paused time; set `cancelled`, `current_phase = finished`, `ended_at = server_now`; append `cancel` |
| running or paused | recovery interruption | Client/service cannot continue and the recovery policy expires | Set `interrupted`, preserve elapsed time, append `interrupted` |
| completed/cancelled/interrupted | any user event | — | Reject with `409 SESSION_TERMINAL`; idempotent retry of the original client event still returns its stored result |

There is no `skip` transition and no `finish now` transition.

### Pause/resume timing rule

At pause, the persisted target end stays unchanged and `paused_at` freezes the displayed remaining time:

`remaining_seconds = max(0, phase_target_end_at - paused_at)`.

At resume, the API calculates the exact paused interval from server timestamps and shifts `phase_target_end_at` forward by that interval. Therefore target end always means “the expected completion instant if the session is currently running,” and a device restart needs only the persisted snapshot to recover it. A client must never advance the phase merely because its own stale wall clock reaches a pre-pause target.

## API contract

`POST /v1/sessions` atomically creates the session, schedule, first phase, and state snapshot. It requires `Idempotency-Key` and returns the full session snapshot.

`POST /v1/sessions/{id}/events` accepts only `pause`, `resume`, or `cancel`:

```json
{
  "clientEventId": "uuid",
  "eventType": "pause",
  "expectedVersion": 4,
  "clientOccurredAt": "2026-11-13T12:00:00Z"
}
```

`clientOccurredAt` is diagnostic only; the server uses its receipt time for authoritative mutation timing. An accepted response returns the resulting session snapshot, including `version`, `currentPhaseIndex`, `phaseTargetEndAt`, `pausedAt`, and per-phase actual durations. A stale `expectedVersion` returns `412 SESSION_VERSION_STALE` with the latest snapshot. An invalid state transition returns `409` with a stable application error code.

Automatic boundary processing runs in the same transactional service used by reads and mutations. Before returning an active session or applying an event, it advances every due boundary using server time. This makes delayed foreground-service callbacks and delayed network requests converge without client-side phase decisions.

## Offline and replay behavior

- The mobile app writes each intended mutation to encrypted local storage and its outbox before submission.
- Events replay in creation order for the session. A later event waits until an earlier event resolves or receives the latest snapshot.
- The Dio authentication interceptor is queued and token refresh is single-flight; a refresh failure pauses protected sync without discarding timer state.
- On reconnect or process recovery, fetch the authoritative snapshot before rendering controls. Re-submit only events with their original `clientEventId`.
- Cancellation is retained in history with elapsed focus/rest totals and never removes the immutable schedule or audit events.

## Required constraints and indexes

- Partial unique index on `focus_sessions(user_id)` where `status IN ('running', 'paused')`.
- Unique `(session_id, position)` on `session_phases`.
- Unique `(user_id, client_event_id)` on `session_events`.
- Check constraints for non-negative duration counters, valid status/phase enums, and `paused_at IS NOT NULL` exactly when `status = 'paused'`.
- Row updates use `WHERE id = :id AND user_id = :userId AND version = :expectedVersion`; successful transitions increment `version` in the same transaction as the event insert.

## Minimum verification

- Pause for 90 seconds, restart the app, resume, and assert the persisted target end moved exactly 90 seconds.
- Submit the same event twice concurrently and assert one event row and one version increment.
- Submit an old version after another client resumes and assert `412` plus the latest snapshot.
- Let the app/background service miss a phase boundary; the next read must automatically advance to the correct phase or completion.
- Cancel while paused and assert elapsed totals exclude the unfinished paused interval.
- Confirm no API or UI route offers Skip phase or Finish now.
