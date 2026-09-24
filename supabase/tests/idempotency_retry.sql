-- Sequential retry contract for financial mutation idempotency.
\set ON_ERROR_STOP on

SELECT plan(3);

DELETE FROM bmt_db.financial_mutation_requests
WHERE operation = 'test_retry' AND idempotency_key = 'pgprove-retry-001';

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'e088ce1d-fb7c-47aa-a15d-7dfa779d7583', false);

SELECT ok(
    (SELECT is_new FROM bmt_db.claim_financial_mutation('test_retry', 'pgprove-retry-001', 'hash-a')),
    'first idempotency claim is new'
);

SELECT request_id
FROM bmt_db.claim_financial_mutation('test_retry', 'pgprove-retry-001', 'hash-a')
\gset mutation_
SELECT bmt_db.complete_financial_mutation(:'mutation_request_id', 'SUCCEEDED', NULL, 200);

SELECT ok(
    NOT (SELECT is_new FROM bmt_db.claim_financial_mutation('test_retry', 'pgprove-retry-001', 'hash-a'))
    AND (SELECT status FROM bmt_db.claim_financial_mutation('test_retry', 'pgprove-retry-001', 'hash-a')) = 'SUCCEEDED',
    'retry with same key returns the completed result'
);

RESET ROLE;
SELECT ok(
    (SELECT count(*) = 1
       FROM bmt_db.financial_mutation_requests
      WHERE operation = 'test_retry' AND idempotency_key = 'pgprove-retry-001'),
    'retry does not create a duplicate mutation row'
);

RESET ROLE;
SELECT * FROM finish();
