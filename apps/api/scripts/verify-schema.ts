import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { config } from 'dotenv';
import postgres from 'postgres';

async function main() {
  const apiDirectory = join(dirname(fileURLToPath(import.meta.url)), '..');
  config({ path: join(apiDirectory, '.env.local') });
  const connectionString = process.env.DATABASE_URL_UNPOOLED;
  if (!connectionString) throw new Error('DATABASE_URL_UNPOOLED is required.');
  const sql = postgres(connectionString, { max: 1, prepare: false });
  try {
    const tables = await sql<{ table_name: string }[]>`
      SELECT table_name FROM information_schema.tables
      WHERE table_schema = 'public' ORDER BY table_name
    `;
    const indexes = await sql<{ indexname: string }[]>`
      SELECT indexname FROM pg_indexes
      WHERE schemaname = 'public' AND tablename = 'focus_sessions'
      ORDER BY indexname
    `;
    console.log(`Tables: ${tables.map((row) => row.table_name).join(', ')}`);
    console.log(`focus_sessions indexes: ${indexes.map((row) => row.indexname).join(', ')}`);
  } finally {
    await sql.end({ timeout: 5 });
  }
}

main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
