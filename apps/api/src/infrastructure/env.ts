import { z } from 'zod';

const serverEnvironmentSchema = z.object({
  DATABASE_URL: z.string().url(),
  UPSTASH_REDIS_REST_URL: z.string().url(),
  UPSTASH_REDIS_REST_TOKEN: z.string().min(1),
  QSTASH_TOKEN: z.string().min(1),
  QSTASH_CURRENT_SIGNING_KEY: z.string().min(1),
  QSTASH_NEXT_SIGNING_KEY: z.string().min(1),
  GOOGLE_CLIENT_ID: z.string().min(1),
  GOOGLE_ISSUER: z.string().url().default('https://accounts.google.com'),
  JWT_ACCESS_TOKEN_SECRET: z.string().min(32),
  ADMIN_SESSION_SECRET: z.string().min(32),
});

export type ServerEnvironment = z.infer<typeof serverEnvironmentSchema>;

export function readServerEnvironment(): ServerEnvironment {
  return serverEnvironmentSchema.parse(process.env);
}
