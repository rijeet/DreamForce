import { createRedisClient } from './redis';

export type PlanDayPayload = {
  plan: Record<string, unknown> | null;
  templates: unknown[];
  occurrences: unknown[];
};

const TTL_SECONDS = 30;

function versionKey(userId: string, localDate: string, version: string) {
  return `plan-day:${userId}:${localDate}:${version}`;
}

function latestKey(userId: string, localDate: string) {
  return `plan-day:${userId}:${localDate}:latest`;
}

function indexKey(userId: string) {
  return `plan-day-index:${userId}`;
}

function planVersion(payload: PlanDayPayload) {
  const version = Number(payload.plan?.version);
  return Number.isFinite(version) ? String(version) : 'none';
}

function isPayload(value: unknown): value is PlanDayPayload {
  if (!value || typeof value !== 'object') return false;
  const payload = value as PlanDayPayload;
  return Array.isArray(payload.templates) && Array.isArray(payload.occurrences);
}

export async function readCachedPlanDay(userId: string, localDate: string) {
  try {
    const value = await createRedisClient().get<PlanDayPayload>(latestKey(userId, localDate));
    return isPayload(value) ? value : null;
  } catch (error) {
    console.error('plan day cache read failed', error instanceof Error ? error.name : 'unknown');
    return null;
  }
}

export async function writeCachedPlanDay(userId: string, localDate: string, payload: PlanDayPayload) {
  try {
    const redis = createRedisClient();
    const versioned = versionKey(userId, localDate, planVersion(payload));
    const latest = latestKey(userId, localDate);
    const index = indexKey(userId);
    await redis
      .pipeline()
      .set(versioned, payload, { ex: TTL_SECONDS })
      .set(latest, payload, { ex: TTL_SECONDS })
      .sadd(index, versioned, latest)
      .expire(index, TTL_SECONDS)
      .exec();
  } catch (error) {
    console.error('plan day cache write failed', error instanceof Error ? error.name : 'unknown');
  }
}

export async function invalidatePlanDayCache(userId: string) {
  try {
    const redis = createRedisClient();
    const index = indexKey(userId);
    const keys = await redis.smembers(index);
    await redis.del(...(keys.length > 0 ? [...keys, index] : [index]));
  } catch (error) {
    console.error('plan day cache invalidation failed', error instanceof Error ? error.name : 'unknown');
  }
}
