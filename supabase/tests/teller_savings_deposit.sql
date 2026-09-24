\set ON_ERROR_STOP on

SELECT plan(6);

SELECT ok(
  has_function_privilege('authenticated', 'bmt_db.teller_post_savings_deposit(uuid,numeric,text,text,text,uuid)', 'EXECUTE')
  AND NOT has_function_privilege('anon', 'bmt_db.teller_post_savings_deposit(uuid,numeric,text,text,text,uuid)', 'EXECUTE'),
  'atomic teller deposit RPC is authenticated-only'
);

SELECT ok(
  (SELECT count(*) = 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'bmt_db' AND p.proname = 'teller_post_savings_deposit'
    AND pg_get_function_identity_arguments(p.oid) LIKE '%p_idempotency_key uuid%'),
  'teller deposit RPC requires UUID idempotency key'
);

SELECT ok(
  (SELECT count(*) = 1 FROM pg_constraint WHERE conname = 'uq_financial_mutation_request'),
  'financial mutation registry prevents duplicate actor-operation-key rows'
);

SELECT ok(
  (SELECT count(*) = 2 FROM bmt_db.chart_of_accounts WHERE code IN ('1.01.001', '2.01.001') AND allow_posting),
  'cash teller and savings liability COA accounts are available for balanced posting'
);

SELECT ok(
  (SELECT count(*) = 1 FROM pg_attribute a JOIN pg_class c ON c.oid = a.attrelid JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'bmt_db' AND c.relname = 'transactions' AND a.attname = 'idempotency_key' AND a.atttypid = 'uuid'::regtype)
  AND (SELECT count(*) = 1 FROM pg_constraint WHERE conname = 'uq_transactions_idempotency_key'),
  'transactions has a UUID idempotency key with a unique constraint'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'bmt_db' AND p.proname = 'teller_post_savings_deposit'
      AND pg_get_functiondef(p.oid) ~* '\\m(COMMIT|BEGIN)\\M'
  ),
  'teller deposit function does not issue manual transaction control'
);

SELECT * FROM finish();
