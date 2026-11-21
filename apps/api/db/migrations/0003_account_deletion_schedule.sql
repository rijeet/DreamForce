-- A confirmed account deletion waits 30 days. deletion_due_at is the moment
-- the account and its rows are removed. Cancelling clears the schedule.
ALTER TABLE users ADD COLUMN deletion_due_at timestamptz;

ALTER TABLE users ADD CONSTRAINT users_deletion_schedule CHECK (
  (status = 'deletion_pending' AND deletion_due_at IS NOT NULL)
  OR (status <> 'deletion_pending' AND deletion_due_at IS NULL)
);
