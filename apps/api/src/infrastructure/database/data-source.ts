import 'reflect-metadata';

import { DataSource } from 'typeorm';

import { readServerEnvironment } from '../env';

/**
 * Neon PostgreSQL connection for Vercel. Runtime always uses the pooled
 * DATABASE_URL. Schema changes are migrations; synchronize is deliberately off.
 */
let dataSource: DataSource | undefined;
let initialization: Promise<DataSource> | undefined;

export async function getDataSource(): Promise<DataSource> {
  dataSource ??= new DataSource({
    type: 'postgres',
    url: readServerEnvironment().DATABASE_URL,
    ssl: { rejectUnauthorized: false },
    synchronize: false,
    migrationsRun: false,
    migrationsTableName: 'typeorm_migrations',
    entities: [],
    migrations: [],
    extra: { max: 2, idleTimeoutMillis: 10_000, connectionTimeoutMillis: 10_000 },
  });
  if (dataSource.isInitialized) return dataSource;
  initialization ??= dataSource.initialize().catch((error: unknown) => {
    initialization = undefined;
    dataSource = undefined;
    throw error;
  });
  return initialization;
}

/** Compatibility adapter for existing parameterized SQL while repositories migrate. */
export function createDatabaseClient() {
  return async <T extends unknown[] = Record<string, unknown>[]>(
    parts: TemplateStringsArray,
    ...values: unknown[]
  ): Promise<T> => {
    const statement = parts.reduce(
      (query, part, index) => query + part + (index < values.length ? `$${index + 1}` : ''),
      '',
    );
    const dataSource = await getDataSource();
    return dataSource.query(statement, values) as Promise<T>;
  };
}
