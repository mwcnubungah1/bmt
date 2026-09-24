\set ON_ERROR_STOP on
SELECT plan(4);

SELECT ok(has_function_privilege('authenticated', 'bmt_db.teller_open_cash_session(numeric,uuid)', 'EXECUTE'), 'authenticated teller can open cash session');
SELECT ok(has_function_privilege('authenticated', 'bmt_db.teller_close_cash_session(numeric)', 'EXECUTE'), 'authenticated teller can close cash session');
SELECT ok(has_function_privilege('authenticated', 'bmt_db.teller_get_cash_session()', 'EXECUTE'), 'authenticated teller can read today session');
SELECT ok((SELECT count(*) = 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='bmt_db' AND p.proname='teller_post_savings_deposit' AND pg_get_functiondef(p.oid) LIKE '%Sesi kas belum dibuka%'), 'deposit rejects missing daily cash session');
SELECT * FROM finish();
