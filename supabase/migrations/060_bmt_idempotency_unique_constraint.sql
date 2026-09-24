BEGIN;

-- The unique index may be owned by the constraint from a previous/partial run.
-- Drop the constraint first; PostgreSQL refuses to drop its backing index directly.
ALTER TABLE bmt_db.transactions
  DROP CONSTRAINT IF EXISTS uq_transactions_idempotency_key;
DROP INDEX IF EXISTS bmt_db.uq_transactions_idempotency_key;
ALTER TABLE bmt_db.transactions
  ADD CONSTRAINT uq_transactions_idempotency_key UNIQUE (idempotency_key);

NOTIFY pgrst, 'reload schema';
COMMIT;
