import { NextResponse } from 'next/server';

import { createRedisClient } from '@/src/infrastructure/cache/redis';
import { createDatabaseClient } from '@/src/infrastructure/database/neon';

export const runtime = 'nodejs';

export async function GET() {
  try {
    await Promise.all([createDatabaseClient()`SELECT 1`, createRedisClient().ping()]);
    return NextResponse.json({ status: 'ready', database: 'ok', redis: 'ok' });
  } catch {
    return NextResponse.json({ status: 'not_ready' }, { status: 503 });
  }
}
