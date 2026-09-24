BEGIN;

DROP INDEX IF EXISTS bmt_db.uq_transactions_idempotency_key;
ALTER TABLE bmt_db.transactions
  ADD CONSTRAINT uq_transactions_idempotency_key UNIQUE (idempotency_key);

NOTIFY pgrst, 'reload schema';
COMMIT;
