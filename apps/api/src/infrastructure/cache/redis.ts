import { Redis } from '@upstash/redis';

import { readServerEnvironment } from '../env';

export function createRedisClient() {
  const environment = readServerEnvironment();
  return new Redis({
    url: environment.UPSTASH_REDIS_REST_URL,
    token: environment.UPSTASH_REDIS_REST_TOKEN,
  });
}
