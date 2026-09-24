\set ON_ERROR_STOP on
SELECT plan(3);
BEGIN;

SELECT fa.id AS account_id, fa.branch_id
FROM bmt_db.financial_accounts fa
JOIN bmt_db.savings_accounts sa ON sa.financial_account_id = fa.id
WHERE fa.status = 'ACTIVE'
ORDER BY fa.account_number
LIMIT 1
\gset fixture_

DELETE FROM bmt_db.teller_cash_sessions WHERE teller_user_id = 'c6f40c04-6914-4494-9390-7526b953e982' AND business_date = CURRENT_DATE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'c6f40c04-6914-4494-9390-7526b953e982', true);

DO $$
DECLARE v_account UUID;
BEGIN
  SELECT fa.id INTO v_account FROM bmt_db.financial_accounts fa JOIN bmt_db.savings_accounts sa ON sa.financial_account_id = fa.id WHERE fa.status = 'ACTIVE' ORDER BY fa.account_number LIMIT 1;
  PERFORM bmt_db.teller_post_savings_deposit(v_account, 10000, 'CASH', NULL, 'closed session test', '33333333-3333-4333-8333-333333333333');
  RAISE EXCEPTION 'expected closed-session rejection';
EXCEPTION WHEN OTHERS THEN
  IF SQLERRM <> 'Sesi kas belum dibuka' THEN RAISE; END IF;
END $$;
SELECT ok(true, 'setoran ditolak saat sesi kas tertutup');

SELECT bmt_db.teller_open_cash_session(0, :'fixture_branch_id') AS session_id \gset opened_
SELECT bmt_db.teller_post_savings_deposit(:'fixture_account_id', 10000, 'CASH', NULL, 'open session test', '44444444-4444-4444-8444-444444444444') AS transaction_id \gset posted_
SELECT ok((SELECT status = 'POSTED' FROM bmt_db.transactions WHERE id = :'posted_transaction_id'), 'setoran berhasil setelah sesi kas dibuka');
SELECT ok((SELECT count(*) = 1 FROM bmt_db.teller_cash_movements WHERE transaction_id = :'posted_transaction_id'), 'arus kas teller tercatat setelah sesi dibuka');

SELECT * FROM finish();
ROLLBACK;
