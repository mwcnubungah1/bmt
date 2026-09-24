\set ON_ERROR_STOP on

SELECT plan(5);
BEGIN;
SELECT fa.id AS account_id, fa.branch_id, sa.current_balance AS before_balance
FROM bmt_db.financial_accounts fa
JOIN bmt_db.savings_accounts sa ON sa.financial_account_id = fa.id
WHERE fa.status = 'ACTIVE'
ORDER BY fa.account_number
LIMIT 1
\gset fixture_

INSERT INTO bmt_db.teller_cash_sessions(branch_id, teller_user_id, opening_balance)
VALUES (:'fixture_branch_id', 'c6f40c04-6914-4494-9390-7526b953e982', 0)
RETURNING id AS session_id
\gset fixture_

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'c6f40c04-6914-4494-9390-7526b953e982', true);

SELECT bmt_db.teller_post_savings_deposit(
  :'fixture_account_id', 125000, 'CASH', NULL, 'pgTAP integration test', '11111111-1111-4111-8111-111111111111'
) AS transaction_id
\gset result_

SELECT ok(
  (SELECT current_balance = :'fixture_before_balance'::NUMERIC + 125000 FROM bmt_db.savings_accounts WHERE financial_account_id = :'fixture_account_id'),
  'saldo tabungan bertambah sesuai nominal'
);

SELECT ok(
  (SELECT count(*) = 1 FROM bmt_db.savings_ledger WHERE transaction_id = :'result_transaction_id')
  AND (SELECT count(*) = 1 FROM bmt_db.teller_cash_movements WHERE transaction_id = :'result_transaction_id'),
  'ledger tabungan dan pergerakan kas tercatat'
);

SELECT ok(
  (SELECT COALESCE(sum(jl.debit), 0) = COALESCE(sum(jl.credit), 0)
   FROM bmt_db.journal_entries je JOIN bmt_db.journal_lines jl ON jl.journal_entry_id = je.id
   WHERE je.transaction_id = :'result_transaction_id'),
  'total debit dan kredit jurnal seimbang'
);

SELECT ok(
  bmt_db.teller_post_savings_deposit(
    :'fixture_account_id', 125000, 'CASH', NULL, 'pgTAP integration test', '11111111-1111-4111-8111-111111111111'
  ) = :'result_transaction_id'::UUID
  AND (SELECT count(*) = 1 FROM bmt_db.transactions WHERE idempotency_key = '11111111-1111-4111-8111-111111111111'),
  'idempotency key yang sama mengembalikan transaksi tanpa duplikasi'
);

DO $$
BEGIN
  PERFORM bmt_db.teller_post_savings_deposit(
    '00000000-0000-4000-8000-000000000000', 125000, 'CASH', NULL, 'rollback test', '22222222-2222-4222-8222-222222222222'
  );
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

SELECT ok(
  (SELECT count(*) = 0 FROM bmt_db.transactions WHERE idempotency_key = '22222222-2222-4222-8222-222222222222')
  AND (SELECT count(*) = 0 FROM bmt_db.savings_ledger sl JOIN bmt_db.transactions t ON t.id = sl.transaction_id WHERE t.idempotency_key = '22222222-2222-4222-8222-222222222222'),
  'error mengembalikan scope function tanpa orphan transaction atau ledger'
);

SELECT * FROM finish();
ROLLBACK;
