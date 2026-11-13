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

import { createDatabaseClient } from '../../infrastructure/database/data-source';
import { HttpProblem } from '../../interfaces/http/auth';
import type { MvpRepository } from '../../APP.Entity/ports/mvp-repository';

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
    s.sound_enabled AS "soundEnabled", s.haptics_enabled AS "hapticsEnabled", s.analytics_app_usage_opt_in AS "analyticsAppUsageOptIn", s.week_starts_on AS "weekStartsOn"
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
  await sql()`UPDATE user_settings SET theme_preference=${input.themePreference ?? current.themePreference}, phase_notifications_enabled=${input.phaseNotificationsEnabled ?? current.phaseNotificationsEnabled}, sound_enabled=${input.soundEnabled ?? current.soundEnabled}, haptics_enabled=${input.hapticsEnabled ?? current.hapticsEnabled}, analytics_app_usage_opt_in=${input.analyticsAppUsageOptIn ?? current.analyticsAppUsageOptIn}, week_starts_on=${input.weekStartsOn ?? current.weekStartsOn} WHERE user_id=${userId}::uuid`;
  return getProfile(userId);
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

async function advanceDueSession(userId: string, id: string) {
  const sessions = await sql()`SELECT * FROM focus_sessions WHERE id=${id}::uuid AND user_id=${userId}::uuid AND status='running' AND phase_target_end_at <= now()`;
  const session = sessions[0] as Record<string, unknown> | undefined;
  if (!session) return;
  const index = Number(session.current_phase_index);
  const phaseRows = await sql()`SELECT * FROM session_phases WHERE session_id=${id}::uuid ORDER BY position`;
  const phase = phaseRows[index] as Record<string, unknown>;
  const phaseEnd = new Date(session.phase_target_end_at as string);
  await sql()`UPDATE session_phases SET ended_at=${phaseEnd}, actual_seconds=planned_seconds WHERE id=${phase.id as string}::uuid`;
  const next = phaseRows[index + 1] as Record<string, unknown> | undefined;
  if (!next) {
    await sql()`UPDATE focus_sessions SET status='completed', current_phase='finished', phase_target_end_at=null, phase_started_at=null, ended_at=${phaseEnd}, actual_focus_seconds=(SELECT COALESCE(sum(actual_seconds),0) FROM session_phases WHERE session_id=${id}::uuid AND phase_type='focus'), actual_rest_seconds=(SELECT COALESCE(sum(actual_seconds),0) FROM session_phases WHERE session_id=${id}::uuid AND phase_type='rest'), version=version+1 WHERE id=${id}::uuid`;
    await sql()`INSERT INTO session_events (session_id, user_id, client_event_id, event_type, occurred_at) VALUES (${id}::uuid, ${userId}::uuid, ${randomUUID()}::uuid, 'completed', ${phaseEnd})`;
    return;
  }
  const nextType = next.phase_type as string;
  const nextEnd = new Date(phaseEnd.getTime() + Number(next.planned_seconds) * 1000);
  await sql()`UPDATE session_phases SET started_at=${phaseEnd} WHERE id=${next.id as string}::uuid`;
  await sql()`UPDATE focus_sessions SET current_phase=${nextType}, current_phase_index=${index + 1}, phase_started_at=${phaseEnd}, phase_target_end_at=${nextEnd}, version=version+1 WHERE id=${id}::uuid`;
  await sql()`INSERT INTO session_events (session_id, user_id, client_event_id, event_type, occurred_at) VALUES (${id}::uuid, ${userId}::uuid, ${randomUUID()}::uuid, ${nextType === 'focus' ? 'focus_started' : 'rest_started'}, ${phaseEnd})`;
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

export const neonMvpRepository: MvpRepository = {
  getProfile, updateProfile, updateSettings, listActivities, createActivity,
  patchActivity, archiveActivity, createFocusSession, getFocusSession,
  submitSessionEvent, listPlans, createPlan, getPlan, getDailyReview,
  upsertDailyReview,
};
