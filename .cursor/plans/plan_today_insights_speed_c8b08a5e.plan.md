---
name: Plan Today Insights Speed
overview: Fix Today so it shows the same planned activities as the weekly plan, open Insights on Day, set the Create account banner to cover.jpg (1936×544), and speed plan loading by collapsing four sequential API calls into one Redis-cached read.
todos:
  - id: today-occurrences
    content: Load today's plan occurrences and show Start/Skip rows on Today; empty state only when the list is empty
    status: completed
  - id: insights-day
    content: Default Insights Activity period to Day
    status: completed
  - id: account-banner
    content: Set the Create account banner to cover.jpg at its native 1936×544 (3.56:1) frame
    status: completed
  - id: plan-read-cache
    content: Add one plan-day read, cache it in Redis for ~30s, invalidate on plan/skip/session writes, and stop full-screen reloads
    status: completed
isProject: false
---

# Today, Insights, banner, and faster plan load

## Create account image

Use [cover.jpg](cover.jpg) for the banner above **Create account**. The file is **1936 × 544 px**, ratio **121:34** (about **3.56:1**). Copy it to `apps/mobile/assets/images/cover.jpg` and declare it in the Flutter asset list.

In [apps/mobile/lib/features/auth/presentation/auth_gate.dart](apps/mobile/lib/features/auth/presentation/auth_gate.dart) the slot is currently `logo.jpg` at a fixed height of 92 with `BoxFit.cover`, which crops a square logo. Replace that with `AspectRatio(aspectRatio: 1936 / 544)` and `BoxFit.contain` so the whole “Consistency Over Intensity” banner shows, including the rounded artwork. Keep the 28px page padding. Do not clip it again with an extra corner radius that cuts the banner’s own rounded corners.

## 1. Today shows no activities

This is a real bug. The weekly plan loads occurrences from `GET /v1/plan-occurrences`. Today never calls the API. [apps/mobile/lib/features/today/presentation/today_screen.dart](apps/mobile/lib/features/today/presentation/today_screen.dart) always paints a static “No activities planned” card.

PostgreSQL `ISODOW` and Dart `DateTime.weekday` both use Monday = 1, so the dates already match. Saturday on Plan and an empty Today is the missing fetch, not a weekday mismatch.

Load today’s occurrences (same local date the plan uses) and render the same row as Plan: icon, name, `HH:mm · N min`, **Start**, and **Skip** while the occurrence is scheduled. Empty state stays only when that list is empty. Start goes through the existing session path in [apps/mobile/lib/app/app_shell.dart](apps/mobile/lib/app/app_shell.dart). Skip uses the existing `PATCH /v1/plan-occurrences/{id}`.

## 2. Insights opens on Week

[apps/mobile/lib/features/insights/presentation/insights_screen.dart](apps/mobile/lib/features/insights/presentation/insights_screen.dart) sets `_period = _Period.week`, so the first request is `period=week`. Change the initial period to `_Period.day`. Activity stays the selected source. Day / Week / Month / Year still switch as they do now.

## 3. Why Plan is slow, and what Redis is for

Opening Plan runs four calls one after another in `_load()`:

1. `GET /v1/plans`
2. `GET /v1/plans/{id}`
3. `GET /v1/activity-templates`
4. `GET /v1/plan-occurrences` — this **writes** on every read (`INSERT … ON CONFLICT DO NOTHING`, then a select)

Leaving the tab destroys `PlanScreen`, because [app_shell.dart](apps/mobile/lib/app/app_shell.dart) swaps the body with a `switch`. Coming back starts the waterfall again. Changing the day also replaces the whole page with a spinner.

Redis and QStash are configured, but Redis is only pinged from `/v1/ready`. QStash is never called.

**Use Redis on the read path. Do not put plan loads on QStash.** QStash is a signed background queue for exports, deletion, and cleanup. A queue hop would make the screen slower. PostgreSQL stays the source of truth.

Speed work:

- Add one read, `GET /v1/plans/current?localDate=YYYY-MM-DD`, in the MVP service. One SQL statement returns the active plan, its entries, activity templates, and that day’s occurrences (materialize, then read). The route handler stays thin.
- Cache that JSON in Upstash Redis for about 30 seconds, key `plan-day:{userId}:{localDate}:{planVersion}`. Delete the user’s plan-day keys when a plan is saved, an occurrence is skipped, or a session starts from an occurrence.
- Point Plan and Today at that one call. Fetch templates in parallel only if the combined payload does not already include the names and icons the rows need.
- Keep Today, Plan, Insights, and Profile alive with an `IndexedStack` so a tab switch does not rebuild and refetch. Refresh the visible plan in the background when returning to the tab.
- On day change, keep the week header and list on screen and show a small progress indicator instead of a full-screen spinner.

## UI this pass covers

- Today’s plan rows match the Plan cards (time, name, duration, Start, Skip).
- Insights opens with **Day** selected.
- Create account banner is `cover.jpg` (1936×544, about 3.56:1), shown in full.

No broader restyle of timer, profile, or insights charts.