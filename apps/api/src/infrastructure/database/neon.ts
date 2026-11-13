import { neon } from '@neondatabase/serverless';

import { readServerEnvironment } from '../env';

/**
 * Creates a request-safe Neon HTTP client. Runtime traffic must use the pooled
 * `DATABASE_URL`; migrations alone may use `DATABASE_URL_UNPOOLED` in CI.
 */
export function createDatabaseClient() {
  return neon(readServerEnvironment().DATABASE_URL);
}
