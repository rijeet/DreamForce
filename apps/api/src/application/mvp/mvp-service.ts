import { createHash, randomUUID } from 'node:crypto';

import type { z } from 'zod';

import type {
  activityTemplateSchema,
  createSessionSchema,
  dailyReviewSchema,
  patchActivityTemplateSchema,
  sessionEventSchema,
  updateProfileSchema,
  updateSettingsSchema,
  weeklyPlanSchema,
} from '@dream-force/api-contract';

import { createDatabaseClient } from '../../infrastructure/database/neon';
import { HttpProblem } from '../../interfaces/http/auth';

type ProfileInput = z.infer<typeof updateProfileSchema>;
type SettingsInput = z.infer<typeof updateSettingsSchema>;
type ActivityInput = z.infer<typeof activityTemplateSchema>;
type ActivityPatch = z.infer<typeof patchActivityTemplateSchema>;
type SessionInput = z.infer<typeof createSessionSchema>;
type SessionEventInput = z.infer<typeof sessionEventSchema>;
type PlanInput = z.infer<typeof weeklyPlanSchema>;
type ReviewInput = z.infer<typeof dailyReviewSchema>;
const sql = createDatabaseClient;

function conflict(code: string): never { throw new HttpProblem(409, code); }
function notFound(code: string): never { throw new HttpProblem(404, code); }
function stale(): never { throw new HttpProblem(412, 'VERSION_STALE'); }

export async function getProfile(userId: string) {
  const rows = await sql()`SELECT u.id, u.email, u.display_name AS "displayName", u.avatar_url AS "avatarUrl", u.locale,
    p.gender, p.date_of_birth AS "dateOfBirth", p.country, p.city, p.profession, p.timezone,
    s.theme_preference AS "themePreference", s.phase_notifications_enabled AS "phaseNotificationsEnabled",
    s.sound_enabled AS "soundEnabled", s.haptics_enabled AS "hapticsEnabled", s.analytics_app_usage_opt_in AS "analyticsAppUsageOptIn", s.week_starts_on AS "weekStartsOn",
    s.screen_time_sync_enabled AS "screenTimeSyncEnabled", s.screen_time_consent_version AS "screenTimeConsentVersion", s.terms_accepted_version AS "termsAcceptedVersion"
    FROM users u JOIN user_profiles p ON p.user_id = u.id JOIN user_settings s ON s.user_id = u.id WHERE u.id = ${userId}::uuid`;
  if (!rows[0]) notFound('PROFILE_NOT_FOUND');
  return rows[0];
}

export async function updateProfile(userId: string, input: ProfileInput) {
  const current = await getProfile(userId);
  const profile = {
    displayName: input.displayName ?? current.displayName,
    avatarUrl: input.avatarUrl ?? current.avatarUrl,
    locale: input.locale ?? current.locale,
    gender: input.gender ?? current.gender,
    dateOfBirth: input.dateOfBirth ?? current.dateOfBirth,
    country: input.country ?? current.country,
    city: input.city ?? current.city,
    profession: input.profession ?? current.profession,
    timezone: input.timezone ?? current.timezone,
  };
  await sql()`UPDATE users SET display_name=${profile.displayName}, avatar_url=${profile.avatarUrl}, locale=${profile.locale} WHERE id=${userId}::uuid`;
  await sql()`UPDATE user_profiles SET gender=${profile.gender}, date_of_birth=${profile.dateOfBirth}, country=${profile.country}, city=${profile.city}, profession=${profile.profession}, timezone=${profile.timezone} WHERE user_id=${userId}::uuid`;
  return getProfile(userId);
}

export async function updateSettings(userId: string, input: SettingsInput) {
  const current = await getProfile(userId);
  const enablingScreenTimeSync = input.screenTimeSyncEnabled === true;
  const revokingScreenTimeSync = input.screenTimeSyncEnabled === false;
  await sql()`
    WITH changed AS (
      UPDATE user_settings SET
        theme_preference=${input.themePreference ?? current.themePreference},
        phase_notifications_enabled=${input.phaseNotificationsEnabled ?? current.phaseNotificationsEnabled},
        sound_enabled=${input.soundEnabled ?? current.soundEnabled},
        haptics_enabled=${input.hapticsEnabled ?? current.hapticsEnabled},
        analytics_app_usage_opt_in=${input.analyticsAppUsageOptIn ?? current.analyticsAppUsageOptIn},
        week_starts_on=${input.weekStartsOn ?? current.weekStartsOn},
        screen_time_sync_enabled=${input.screenTimeSyncEnabled ?? current.screenTimeSyncEnabled},
        screen_time_consent_version=CASE WHEN ${enablingScreenTimeSync} THEN ${input.screenTimeConsentVersion ?? null} ELSE screen_time_consent_version END,
        screen_time_consent_at=CASE WHEN ${enablingScreenTimeSync} THEN now() ELSE screen_time_consent_at END,
        screen_time_sync_revoked_at=CASE WHEN ${revokingScreenTimeSync} THEN now() WHEN ${enablingScreenTimeSync} THEN NULL ELSE screen_time_sync_revoked_at END
      WHERE user_id=${userId}::uuid
      RETURNING user_id
    ), removed AS (
      DELETE FROM user_app_usage_daily USING changed
      WHERE user_app_usage_daily.user_id=changed.user_id AND ${revokingScreenTimeSync}
      RETURNING user_app_usage_daily.user_id
    )
    SELECT user_id FROM changed
  `;
  return getProfile(userId);
}

export async function uploadScreenTimeUsage(userId: string, input: { queriedAt: string; rows: Array<{ localDate: string; timezoneId: string; packageName: string; appLabel: string; usageSeconds: number }> }) {
  const settings = await sql()`SELECT screen_time_sync_enabled AS enabled FROM user_settings WHERE user_id=${userId}::uuid`;
  if (settings[0]?.enabled !== true) throw new HttpProblem(403, 'SCREEN_TIME_SYNC_CONSENT_REQUIRED');
  const payload = JSON.stringify(input.rows.map((row) => ({
    local_date: row.localDate,
    timezone_id: row.timezoneId,
    package_name: row.packageName,
    app_label: row.appLabel,
    usage_seconds: row.usageSeconds,
  })));
  const result = await sql()`
    WITH consent AS (
      SELECT user_id FROM user_settings
      WHERE user_id=${userId}::uuid AND screen_time_sync_enabled=true
      FOR SHARE
    ), incoming AS (
      SELECT local_date::date, timezone_id, package_name, app_label, usage_seconds::integer
      FROM jsonb_to_recordset(${payload}::jsonb)
        AS usage(local_date text, timezone_id text, package_name text, app_label text, usage_seconds integer)
    ), written AS (
      INSERT INTO user_app_usage_daily (user_id, local_date, timezone_id, package_name, app_label, usage_seconds, queried_at)
      SELECT consent.user_id, incoming.local_date, incoming.timezone_id, incoming.package_name, incoming.app_label, incoming.usage_seconds, ${input.queriedAt}::timestamptz
      FROM consent CROSS JOIN incoming
      ON CONFLICT (user_id, local_date, timezone_id, package_name)
      DO UPDATE SET app_label=EXCLUDED.app_label, usage_seconds=EXCLUDED.usage_seconds, queried_at=EXCLUDED.queried_at, updated_at=now()
      RETURNING 1
    )
    SELECT count(*)::int AS "uploadedRows" FROM written
  `;
  const uploadedRows = Number(result[0]?.uploadedRows ?? 0);
  if (uploadedRows === 0) throw new HttpProblem(403, 'SCREEN_TIME_SYNC_CONSENT_REQUIRED');
  return { uploadedRows, queriedAt: input.queriedAt };
}

export async function getScreenTimeInsights(userId: string, period: 'day' | 'week' | 'month' | 'year', timezone: string) {
  const settings = await sql()`SELECT screen_time_sync_enabled AS enabled FROM user_settings WHERE user_id=${userId}::uuid`;
  if (settings[0]?.enabled !== true) throw new HttpProblem(403, 'SCREEN_TIME_SYNC_CONSENT_REQUIRED');
  const bounds = await sql()`
    WITH local_bounds AS (
      SELECT date_trunc(${period === 'day' ? 'day' : period}, now() AT TIME ZONE ${timezone})::date AS start_date,
        (date_trunc(${period === 'day' ? 'day' : period}, now() AT TIME ZONE ${timezone}) +
          CASE ${period} WHEN 'day' THEN interval '1 day' WHEN 'week' THEN interval '1 week' WHEN 'month' THEN interval '1 month' ELSE interval '1 year' END)::date AS end_date
    )
    SELECT start_date::text AS "startDate", end_date::text AS "endDate" FROM local_bounds
  `;
  const startDate = String(bounds[0].startDate);
  const endDate = String(bounds[0].endDate);
  const apps = await sql()`
    SELECT package_name AS "packageName", (array_agg(app_label ORDER BY queried_at DESC))[1] AS "appLabel", sum(usage_seconds)::bigint AS "usageSeconds", max(queried_at) AS "queriedAt"
    FROM user_app_usage_daily
    WHERE user_id=${userId}::uuid AND timezone_id=${timezone} AND local_date >= ${startDate}::date AND local_date < ${endDate}::date
    GROUP BY package_name ORDER BY sum(usage_seconds) DESC
  `;
  return {
    period, timezone, startDate, endDate,
    totalUsageSeconds: apps.reduce((sum, app) => sum + Number(app.usageSeconds), 0),
    updatedAt: apps.reduce<string | null>((latest, app) => {
      const value = app.queriedAt instanceof Date ? app.queriedAt.toISOString() : String(app.queriedAt);
      return latest === null || value > latest ? value : latest;
    }, null),
    apps: apps.map((app) => ({ ...app, usageSeconds: Number(app.usageSeconds) })),
  };
}

export async function getActivityInsights(userId: string, period: 'day' | 'week' | 'month' | 'year') {
  const profiles = await sql()`SELECT timezone FROM user_profiles WHERE user_id=${userId}::uuid`;
  const timezone = String(profiles[0]?.timezone ?? 'UTC');
  // The selected period is evaluated in the user's IANA timezone, then converted
  // to instants by PostgreSQL. The DB/server timezone therefore cannot shift days.
  const rows = await sql()`
    WITH bounds AS (
      SELECT ${timezone}::text AS tz,
        date_trunc(${period === 'day' ? 'day' : period}, now() AT TIME ZONE ${timezone}) AS local_start,
        date_trunc(${period === 'day' ? 'day' : period}, now() AT TIME ZONE ${timezone}) +
          CASE ${period} WHEN 'day' THEN interval '1 day' WHEN 'week' THEN interval '1 week' WHEN 'month' THEN interval '1 month' ELSE interval '1 year' END AS local_end
    ), bucketed AS (
      SELECT date_trunc(CASE ${period} WHEN 'year' THEN 'month' ELSE 'day' END, f.ended_at AT TIME ZONE b.tz)::date AS local_date,
        COALESCE(sum(f.actual_focus_seconds), 0)::int AS focus_seconds,
        count(*)::int AS completed_sessions
      FROM focus_sessions f CROSS JOIN bounds b
      WHERE f.user_id=${userId}::uuid AND f.status='completed'
        AND f.ended_at >= (b.local_start AT TIME ZONE b.tz)
        AND f.ended_at < (b.local_end AT TIME ZONE b.tz)
      GROUP BY local_date
    ), date_buckets AS (
      SELECT generate_series(
        local_start,
        local_end - CASE ${period} WHEN 'year' THEN interval '1 month' ELSE interval '1 day' END,
        CASE ${period} WHEN 'year' THEN interval '1 month' ELSE interval '1 day' END
      )::date AS local_date
      FROM bounds
    )
    SELECT d.local_date::text AS date,
      COALESCE(b.focus_seconds, 0)::int AS "focusSeconds",
      COALESCE(b.completed_sessions, 0)::int AS "completedSessions"
    FROM date_buckets d LEFT JOIN bucketed b USING (local_date) ORDER BY d.local_date
  `;
  const totalSeconds = rows.reduce((total, row) => total + Number(row.focusSeconds), 0);
  const totalSessions = rows.reduce((total, row) => total + Number(row.completedSessions), 0);
  return { period, timezone, totalFocusSeconds: totalSeconds, completedSessions: totalSessions, days: rows };
}

export async function listActivities(userId: string) {
  return sql()`SELECT id, name, icon_key AS "iconKey", category, planned_minutes AS "plannedMinutes", is_builtin AS "isBuiltin", version, updated_at AS "updatedAt" FROM activity_templates WHERE archived_at IS NULL AND (owner_user_id=${userId}::uuid OR is_builtin=true) ORDER BY is_builtin DESC, updated_at DESC`;
}

export async function createActivity(userId: string, input: ActivityInput) {
  const rows = await sql()`INSERT INTO activity_templates (owner_user_id, name, icon_key, category, planned_minutes) VALUES (${userId}::uuid, ${input.name}, ${input.iconKey}, ${input.category ?? null}, ${input.plannedMinutes}) RETURNING id, name, icon_key AS "iconKey", category, planned_minutes AS "plannedMinutes", version`;
  return rows[0];
}

export async function patchActivity(userId: string, id: string, input: ActivityPatch) {
  const rows = await sql()`SELECT * FROM activity_templates WHERE id=${id}::uuid AND owner_user_id=${userId}::uuid AND archived_at IS NULL`;
  const current = rows[0] as Record<string, unknown> | undefined;
  if (!current) notFound('ACTIVITY_NOT_FOUND');
  if (Number(current.version) !== input.version) stale();
  const changed = await sql()`UPDATE activity_templates SET name=${input.name ?? current.name as string}, icon_key=${input.iconKey ?? current.icon_key as string}, category=${input.category ?? current.category as string | null}, planned_minutes=${input.plannedMinutes ?? Number(current.planned_minutes)}, version=version+1 WHERE id=${id}::uuid AND owner_user_id=${userId}::uuid AND version=${input.version} RETURNING id, name, icon_key AS "iconKey", category, planned_minutes AS "plannedMinutes", version`;
  if (!changed[0]) stale();
  return changed[0];
}

export async function archiveActivity(userId: string, id: string) {
  const rows = await sql()`UPDATE activity_templates SET archived_at=now(), version=version+1 WHERE id=${id}::uuid AND owner_user_id=${userId}::uuid AND archived_at IS NULL RETURNING id`;
  if (!rows[0]) notFound('ACTIVITY_NOT_FOUND');
}

function schedule(totalMinutes: number) {
  if (totalMinutes === 90) return [{ type: 'focus', seconds: 2400 }, { type: 'rest', seconds: 300 }, { type: 'focus', seconds: 2400 }, { type: 'rest', seconds: 300 }];
  const totalSeconds = totalMinutes * 60;
  const focusSeconds = Math.round(totalSeconds * 5 / 6);
  return [{ type: 'focus', seconds: focusSeconds }, { type: 'rest', seconds: totalSeconds - focusSeconds }];
}

export async function createFocusSession(userId: string, input: SessionInput) {
  const phases = schedule(input.plannedMinutes);
  const now = new Date();
  const target = new Date(now.getTime() + phases[0].seconds * 1000);
  try {
    const rows = await sql()`INSERT INTO focus_sessions (user_id, template_id, plan_occurrence_id, name_snapshot, icon_key_snapshot, category_snapshot, planned_minutes, schedule_version, status, current_phase, current_phase_index, started_at, phase_started_at, phase_target_end_at, client_timezone) VALUES (${userId}::uuid, ${input.templateId ?? null}::uuid, ${input.planOccurrenceId ?? null}::uuid, ${input.name}, ${input.iconKey}, ${input.category ?? null}, ${input.plannedMinutes}, 1, 'running', 'focus', 0, ${now}, ${now}, ${target}, ${input.timezone}) RETURNING *`;
    const session = rows[0] as Record<string, unknown>;
    await Promise.all(phases.map((phase, position) => sql()`INSERT INTO session_phases (session_id, position, phase_type, planned_seconds, started_at) VALUES (${session.id as string}::uuid, ${position}, ${phase.type}, ${phase.seconds}, ${position === 0 ? now : null})`));
    await sql()`INSERT INTO session_events (session_id, user_id, client_event_id, event_type, occurred_at) VALUES (${session.id as string}::uuid, ${userId}::uuid, ${randomUUID()}::uuid, 'started', ${now})`;
    return getFocusSession(userId, session.id as string);
  } catch (error) {
    if (String(error).includes('focus_sessions_one_open_per_user_idx')) conflict('OPEN_SESSION_EXISTS');
    throw error;
  }
}

export async function getFocusSession(userId: string, id: string) {
  await advanceDueSession(userId, id);
  const rows = await sql()`SELECT id, name_snapshot AS "name", icon_key_snapshot AS "iconKey", planned_minutes AS "plannedMinutes", status, current_phase AS "currentPhase", current_phase_index AS "currentPhaseIndex", phase_target_end_at AS "phaseTargetEndAt", paused_at AS "pausedAt", total_paused_seconds AS "totalPausedSeconds", actual_focus_seconds AS "actualFocusSeconds", actual_rest_seconds AS "actualRestSeconds", version, started_at AS "startedAt", ended_at AS "endedAt" FROM focus_sessions WHERE id=${id}::uuid AND user_id=${userId}::uuid`;
  if (!rows[0]) notFound('SESSION_NOT_FOUND');
  const phases = await sql()`SELECT position, phase_type AS "phaseType", planned_seconds AS "plannedSeconds", started_at AS "startedAt", ended_at AS "endedAt", actual_seconds AS "actualSeconds" FROM session_phases WHERE session_id=${id}::uuid ORDER BY position`;
  return { ...rows[0], phases };
}

export async function getCurrentFocusSession(userId: string) {
  const rows = await sql()`SELECT id FROM focus_sessions WHERE user_id=${userId}::uuid AND status IN ('running', 'paused') ORDER BY started_at DESC LIMIT 1`;
  const id = rows[0]?.id as string | undefined;
  return id ? getFocusSession(userId, id) : null;
}

async function advanceDueSession(userId: string, id: string) {
  // A delayed client can miss more than one boundary. Catch up from each
  // persisted target instant until the active phase is current or complete.
  while (true) {
    const sessions = await sql()`SELECT * FROM focus_sessions WHERE id=${id}::uuid AND user_id=${userId}::uuid AND status='running' AND phase_target_end_at <= now()`;
    const session = sessions[0] as Record<string, unknown> | undefined;
    if (!session) return;
    const index = Number(session.current_phase_index);
    const phaseRows = await sql()`SELECT * FROM session_phases WHERE session_id=${id}::uuid ORDER BY position`;
    const phase = phaseRows[index] as Record<string, unknown> | undefined;
    if (!phase) return;
    const phaseEnd = new Date(session.phase_target_end_at as string);
    const next = phaseRows[index + 1] as Record<string, unknown> | undefined;

    // Marking the phase is idempotent. The version/index/target predicate below
    // ensures only one concurrent reader advances and emits the boundary event.
    await sql()`UPDATE session_phases SET ended_at=${phaseEnd}, actual_seconds=planned_seconds WHERE id=${phase.id as string}::uuid AND ended_at IS NULL`;
    if (!next) {
      const completed = await sql()`UPDATE focus_sessions SET status='completed', current_phase='finished', phase_target_end_at=null, phase_started_at=null, ended_at=${phaseEnd}, actual_focus_seconds=(SELECT COALESCE(sum(actual_seconds),0) FROM session_phases WHERE session_id=${id}::uuid AND phase_type='focus'), actual_rest_seconds=(SELECT COALESCE(sum(actual_seconds),0) FROM session_phases WHERE session_id=${id}::uuid AND phase_type='rest'), version=version+1 WHERE id=${id}::uuid AND user_id=${userId}::uuid AND status='running' AND current_phase_index=${index} AND phase_target_end_at=${session.phase_target_end_at as Date} AND phase_target_end_at <= now() RETURNING id`;
      if (!completed[0]) continue;
      await sql()`INSERT INTO session_events (session_id, user_id, client_event_id, event_type, occurred_at) VALUES (${id}::uuid, ${userId}::uuid, ${randomUUID()}::uuid, 'completed', ${phaseEnd})`;
      return;
    }
    const nextType = next.phase_type as string;
    const nextEnd = new Date(phaseEnd.getTime() + Number(next.planned_seconds) * 1000);
    const advanced = await sql()`UPDATE focus_sessions SET current_phase=${nextType}, current_phase_index=${index + 1}, phase_started_at=${phaseEnd}, phase_target_end_at=${nextEnd}, version=version+1 WHERE id=${id}::uuid AND user_id=${userId}::uuid AND status='running' AND current_phase_index=${index} AND phase_target_end_at=${session.phase_target_end_at as Date} AND phase_target_end_at <= now() RETURNING id`;
    if (!advanced[0]) continue;
    await sql()`UPDATE session_phases SET started_at=${phaseEnd} WHERE id=${next.id as string}::uuid AND started_at IS NULL`;
    await sql()`INSERT INTO session_events (session_id, user_id, client_event_id, event_type, occurred_at) VALUES (${id}::uuid, ${userId}::uuid, ${randomUUID()}::uuid, ${nextType === 'focus' ? 'focus_started' : 'rest_started'}, ${phaseEnd})`;
  }
}

export async function submitSessionEvent(userId: string, id: string, input: SessionEventInput) {
  const previous = await sql()`SELECT id FROM session_events WHERE user_id=${userId}::uuid AND client_event_id=${input.clientEventId}::uuid`;
  if (previous[0]) return getFocusSession(userId, id);
  await advanceDueSession(userId, id);
  const rows = await sql()`SELECT * FROM focus_sessions WHERE id=${id}::uuid AND user_id=${userId}::uuid`;
  const session = rows[0] as Record<string, unknown> | undefined;
  if (!session) notFound('SESSION_NOT_FOUND');
  if (Number(session.version) !== input.expectedVersion) stale();
  const now = new Date();
  if (input.eventType === 'pause') {
    if (session.status !== 'running') conflict('SESSION_NOT_RUNNING');
    await sql()`UPDATE focus_sessions SET status='paused', paused_at=${now}, version=version+1 WHERE id=${id}::uuid AND version=${input.expectedVersion}`;
  } else if (input.eventType === 'resume') {
    if (session.status !== 'paused' || !session.paused_at) conflict('SESSION_NOT_PAUSED');
    const delta = Math.max(0, Math.round((now.getTime() - new Date(session.paused_at as Date).getTime()) / 1000));
    await sql()`UPDATE focus_sessions SET status='running', paused_at=null, phase_target_end_at=phase_target_end_at + (${delta} * interval '1 second'), total_paused_seconds=total_paused_seconds+${delta}, version=version+1 WHERE id=${id}::uuid AND version=${input.expectedVersion}`;
  } else {
    if (!['running', 'paused'].includes(session.status as string)) conflict('SESSION_TERMINAL');
    await sql()`UPDATE focus_sessions SET status='cancelled', current_phase='finished', paused_at=null, phase_target_end_at=null, phase_started_at=null, ended_at=${now}, version=version+1 WHERE id=${id}::uuid AND version=${input.expectedVersion}`;
  }
  await sql()`INSERT INTO session_events (session_id, user_id, client_event_id, event_type, occurred_at) VALUES (${id}::uuid, ${userId}::uuid, ${input.clientEventId}::uuid, ${input.eventType === 'cancel' ? 'cancel' : input.eventType}, ${now})`;
  return getFocusSession(userId, id);
}

export async function listPlans(userId: string) {
  return sql()`SELECT id, name, timezone, is_active AS "isActive", version, updated_at AS "updatedAt" FROM weekly_plans WHERE user_id=${userId}::uuid ORDER BY updated_at DESC`;
}

export async function createPlan(userId: string, input: PlanInput) {
  const rows = await sql()`INSERT INTO weekly_plans (user_id, name, timezone) VALUES (${userId}::uuid, ${input.name}, ${input.timezone}) RETURNING id, name, timezone, is_active AS "isActive", version`;
  const plan = rows[0] as Record<string, unknown>;
  await Promise.all(input.entries.map((entry) => sql()`INSERT INTO weekly_plan_entries (plan_id, template_id, weekday, position, local_start_time, planned_minutes_override) VALUES (${plan.id as string}::uuid, ${entry.templateId}::uuid, ${entry.weekday}, ${entry.position}, ${entry.localStartTime ?? null}, ${entry.plannedMinutesOverride ?? null})`));
  return getPlan(userId, plan.id as string);
}

export async function getPlan(userId: string, id: string) {
  const plans = await sql()`SELECT id, name, timezone, is_active AS "isActive", version FROM weekly_plans WHERE id=${id}::uuid AND user_id=${userId}::uuid`;
  if (!plans[0]) notFound('PLAN_NOT_FOUND');
  const entries = await sql()`SELECT id, template_id AS "templateId", weekday, position, local_start_time AS "localStartTime", planned_minutes_override AS "plannedMinutesOverride" FROM weekly_plan_entries WHERE plan_id=${id}::uuid ORDER BY weekday, position`;
  return { ...plans[0], entries };
}

export async function getDailyReview(userId: string, localDate: string) {
  const rows = await sql()`SELECT local_date AS "localDate", timezone, mood, summary, reflection, reason_tags AS "reasonTags", version, updated_at AS "updatedAt" FROM daily_reviews WHERE user_id=${userId}::uuid AND local_date=${localDate}::date`;
  return rows[0] ?? null;
}

export async function upsertDailyReview(userId: string, localDate: string, input: ReviewInput) {
  const current = await getDailyReview(userId, localDate);
  if (current && input.version !== current.version) stale();
  const rows = await sql()`INSERT INTO daily_reviews (user_id, local_date, timezone, mood, summary, reflection, reason_tags) VALUES (${userId}::uuid, ${localDate}::date, ${input.timezone}, ${input.mood ?? null}, ${input.summary ?? null}, ${input.reflection ?? null}, ${input.reasonTags ?? []}) ON CONFLICT (user_id, local_date) DO UPDATE SET timezone=EXCLUDED.timezone, mood=EXCLUDED.mood, summary=EXCLUDED.summary, reflection=EXCLUDED.reflection, reason_tags=EXCLUDED.reason_tags, version=daily_reviews.version+1 RETURNING local_date AS "localDate", timezone, mood, summary, reflection, reason_tags AS "reasonTags", version`;
  return rows[0];
}

export function requestHash(value: unknown) { return createHash('sha256').update(JSON.stringify(value)).digest(); }
