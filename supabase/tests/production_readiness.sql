-- Production-readiness structural gate for the local/staging database.
\set ON_ERROR_STOP on

SELECT plan(7);

SELECT ok(
    (SELECT count(*) = 3
       FROM pg_proc p
       JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'bmt_db'
        AND p.proname IN ('claim_financial_mutation', 'complete_financial_mutation', 'data_volume_snapshot')),
    'governance and idempotency functions exist'
);

SELECT ok(
    (SELECT count(*) = 5
       FROM pg_class c
       JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'bmt_db'
        AND c.relkind = 'i'
        AND c.relname IN (
            'ix_transactions_customer_date',
            'ix_loan_schedules_account_due',
            'ix_installment_payments_schedule_paid',
            'ix_journal_lines_entry',
            'ix_user_branches_user_branch'
        )),
    'critical query indexes exist'
);

SELECT ok(
    (SELECT count(*) = 0
       FROM pg_proc p
       JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'bmt_db'
        AND p.prosecdef
        AND NOT EXISTS (
            SELECT 1 FROM unnest(COALESCE(p.proconfig, ARRAY[]::TEXT[])) setting
             WHERE setting LIKE 'search_path=%'
        )),
    'every SECURITY DEFINER function pins search_path'
);

SELECT ok(
    (SELECT count(*) = 0
       FROM bmt_db.security_definer_audit
      WHERE public_can_execute OR anon_can_execute),
    'SECURITY DEFINER functions are not executable by public or anon'
);

SELECT ok(
    (SELECT count(*) >= 5
       FROM bmt_db.rls_policy_audit
      WHERE rls_enabled AND policy_count > 0),
    'RLS is enabled on policy-bearing tables'
);

SELECT ok(
    (SELECT count(*) = 4 FROM bmt_db.operational_retention_policy),
    'retention policy covers operational and financial datasets'
);

SELECT ok(
    has_function_privilege('authenticated', 'bmt_db.reverse_transaction(uuid,uuid,text,text)', 'EXECUTE')
    AND NOT has_function_privilege('anon', 'bmt_db.reverse_transaction(uuid,uuid,text,text)', 'EXECUTE'),
    'idempotent reversal boundary is authenticated-only'
);

SELECT * FROM finish();
