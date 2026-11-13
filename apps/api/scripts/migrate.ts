import { createHash } from 'node:crypto';
import { readdir, readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { config } from 'dotenv';
import postgres from 'postgres';

async function main() {
  const scriptDirectory = dirname(fileURLToPath(import.meta.url));
  const apiDirectory = join(scriptDirectory, '..');
  config({ path: join(apiDirectory, '.env.local') });

  const connectionString = process.env.DATABASE_URL_UNPOOLED;
  if (!connectionString) {
    throw new Error('DATABASE_URL_UNPOOLED is required. Use the Neon direct (non-pooler) connection string only for migrations.');
  }

  const migrationsDirectory = join(apiDirectory, 'db', 'migrations');
  const sql = postgres(connectionString, { max: 1, prepare: false });
  try {
  await sql`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      name varchar(255) PRIMARY KEY,
      checksum varchar(64) NOT NULL,
      applied_at timestamptz NOT NULL DEFAULT now()
    )
  `;

  const names = (await readdir(migrationsDirectory)).filter((name) => name.endsWith('.sql')).sort();
  for (const name of names) {
    const content = await readFile(join(migrationsDirectory, name), 'utf8');
    const checksum = createHash('sha256').update(content).digest('hex');
    const applied = await sql<{ checksum: string }[]>`SELECT checksum FROM schema_migrations WHERE name = ${name}`;
    if (applied[0]) {
      if (applied[0].checksum !== checksum) throw new Error(`Applied migration changed: ${name}. Create a new migration instead.`);
      console.log(`Skipped ${name} (already applied).`);
      continue;
    }
    await sql.begin(async (transaction) => {
      await transaction.unsafe(content);
      await transaction`INSERT INTO schema_migrations (name, checksum) VALUES (${name}, ${checksum})`;
    });
    console.log(`Applied ${name}.`);
  }
  } finally {
    await sql.end({ timeout: 5 });
  }
}

main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
