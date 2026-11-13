import { NextResponse } from 'next/server';

import { createRedisClient } from '@/src/infrastructure/cache/redis';
import { createDatabaseClient } from '@/src/infrastructure/database/neon';

export const runtime = 'nodejs';

export async function GET() {
  const [database, redis] = await Promise.allSettled([
    Promise.resolve().then(() => createDatabaseClient()`SELECT 1`),
    Promise.resolve().then(() => createRedisClient().ping()),
  ]);
  const checks = {
    database: database.status === 'fulfilled' ? 'ok' : 'unavailable',
    redis: redis.status === 'fulfilled' ? 'ok' : 'unavailable',
  } as const;
  const ready = checks.database === 'ok' && checks.redis === 'ok';
  return NextResponse.json(
    { status: ready ? 'ready' : 'not_ready', ...checks },
    { status: ready ? 200 : 503 },
  );
}
