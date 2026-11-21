import { createDatabaseClient } from '../../infrastructure/database/neon';
import { createQStashClient } from '../../infrastructure/jobs/qstash';
import { HttpProblem } from '../../interfaces/http/auth';

const sql = createDatabaseClient;

type DeletionSchedule = {
  accountStatus: string;
  deletionDueAt: string | Date;
};

export async function finalizeDueAccountDeletion(userId: string) {
  const rows = await sql()`
    DELETE FROM users
    WHERE id=${userId}::uuid
      AND status='deletion_pending'
      AND deletion_due_at IS NOT NULL
      AND deletion_due_at <= now()
    RETURNING id
  `;
  return Boolean(rows[0]);
}

export async function requestAccountDeletion(userId: string) {
  if (await finalizeDueAccountDeletion(userId)) throw new HttpProblem(401, 'ACCOUNT_DELETED');
  const rows = (await sql()`
    UPDATE users
    SET status='deletion_pending',
        deletion_due_at=COALESCE(deletion_due_at, now() + interval '30 days')
    WHERE id=${userId}::uuid AND status IN ('active', 'deletion_pending')
    RETURNING status AS "accountStatus", deletion_due_at AS "deletionDueAt"
  `) as DeletionSchedule[];
  const schedule = rows[0];
  if (!schedule) throw new HttpProblem(409, 'ACCOUNT_UNAVAILABLE');
  const dueAt = new Date(schedule.deletionDueAt);
  void scheduleAccountDeletion(userId, dueAt);
  return { accountStatus: schedule.accountStatus, deletionDueAt: dueAt.toISOString() };
}

export async function cancelAccountDeletion(userId: string) {
  if (await finalizeDueAccountDeletion(userId)) throw new HttpProblem(401, 'ACCOUNT_DELETED');
  const rows = await sql()`
    UPDATE users
    SET status='active', deletion_due_at=NULL
    WHERE id=${userId}::uuid AND status='deletion_pending'
    RETURNING id
  `;
  if (!rows[0]) throw new HttpProblem(409, 'ACCOUNT_DELETION_NOT_PENDING');
}

function publicApiOrigin() {
  const configured = process.env.API_PUBLIC_URL?.replace(/\/$/, '');
  if (configured) return configured;
  const production = process.env.VERCEL_PROJECT_PRODUCTION_URL;
  if (production) return `https://${production.replace(/^https?:\/\//, '')}`;
  const deployment = process.env.VERCEL_URL;
  if (deployment) return `https://${deployment.replace(/^https?:\/\//, '')}`;
  return null;
}

async function scheduleAccountDeletion(userId: string, dueAt: Date) {
  try {
    const origin = publicApiOrigin();
    if (!origin || Number.isNaN(dueAt.getTime())) return;
    await createQStashClient().publishJSON({
      url: `${origin}/v1/jobs/account-deletions`,
      body: { userId },
      notBefore: Math.floor(dueAt.getTime() / 1000),
    });
  } catch (error) {
    console.error('Could not schedule account deletion', error);
  }
}
