-- BMT 030 - forward-only governance, security audit and performance hardening.

CREATE TABLE IF NOT EXISTS bmt_db.financial_mutation_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID NOT NULL REFERENCES bmt_db.user_profiles(id) ON DELETE RESTRICT,
    operation TEXT NOT NULL,
    idempotency_key TEXT NOT NULL,
    request_hash TEXT,
    status TEXT NOT NULL DEFAULT 'IN_PROGRESS',
    result_id UUID,
    response_code INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '24 hours'),
    CONSTRAINT uq_financial_mutation_request UNIQUE (actor_id, operation, idempotency_key),
    CONSTRAINT ck_financial_mutation_status CHECK (status IN ('IN_PROGRESS', 'SUCCEEDED', 'FAILED')),
    CONSTRAINT ck_financial_mutation_key CHECK (btrim(idempotency_key) <> '')
);

CREATE INDEX IF NOT EXISTS ix_financial_mutation_expiry
    ON bmt_db.financial_mutation_requests (expires_at)
    WHERE status <> 'IN_PROGRESS';

COMMENT ON TABLE bmt_db.financial_mutation_requests IS
'Idempotency registry for financial mutations. Claim a key before posting, paying, reversing or settling money.';

CREATE OR REPLACE FUNCTION bmt_db.claim_financial_mutation(
    p_operation TEXT,
    p_idempotency_key TEXT,
    p_request_hash TEXT DEFAULT NULL
)
RETURNS TABLE (request_id UUID, is_new BOOLEAN, status TEXT, result_id UUID)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
    v_actor UUID := auth.uid();
    v_existing bmt_db.financial_mutation_requests%ROWTYPE;
    v_id UUID;
BEGIN
    IF v_actor IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
    IF NULLIF(btrim(p_operation), '') IS NULL OR NULLIF(btrim(p_idempotency_key), '') IS NULL THEN
        RAISE EXCEPTION 'Operation and idempotency key are required';
    END IF;
    INSERT INTO bmt_db.financial_mutation_requests(actor_id, operation, idempotency_key, request_hash)
    VALUES (v_actor, p_operation, p_idempotency_key, p_request_hash)
    ON CONFLICT (actor_id, operation, idempotency_key) DO NOTHING
    RETURNING id INTO v_id;
    IF v_id IS NOT NULL THEN
        RETURN QUERY SELECT v_id, TRUE, 'IN_PROGRESS'::TEXT, NULL::UUID;
        RETURN;
    END IF;
    SELECT * INTO v_existing FROM bmt_db.financial_mutation_requests
     WHERE actor_id = v_actor AND operation = p_operation AND idempotency_key = p_idempotency_key
     FOR UPDATE;
    IF v_existing.request_hash IS DISTINCT FROM p_request_hash THEN
        RAISE EXCEPTION 'Idempotency key was reused with a different request';
    END IF;
    RETURN QUERY SELECT v_existing.id, FALSE, v_existing.status, v_existing.result_id;
END;
$$;

CREATE OR REPLACE FUNCTION bmt_db.complete_financial_mutation(
    p_request_id UUID, p_status TEXT, p_result_id UUID DEFAULT NULL, p_response_code INTEGER DEFAULT NULL
)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
    IF p_status NOT IN ('SUCCEEDED', 'FAILED') THEN RAISE EXCEPTION 'Invalid mutation completion status'; END IF;
    UPDATE bmt_db.financial_mutation_requests
       SET status = p_status, result_id = p_result_id, response_code = p_response_code, completed_at = now()
     WHERE id = p_request_id AND actor_id = auth.uid() AND status = 'IN_PROGRESS';
    IF NOT FOUND THEN RAISE EXCEPTION 'Mutation request is not owned or already completed'; END IF;
END;
$$;

REVOKE ALL ON FUNCTION bmt_db.claim_financial_mutation(TEXT, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.claim_financial_mutation(TEXT, TEXT, TEXT) TO authenticated;
REVOKE ALL ON FUNCTION bmt_db.complete_financial_mutation(UUID, TEXT, UUID, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.complete_financial_mutation(UUID, TEXT, UUID, INTEGER) TO authenticated;

CREATE INDEX IF NOT EXISTS ix_transactions_customer_date
    ON bmt_db.transactions (customer_id, transaction_date DESC, created_at DESC, transaction_number);
CREATE INDEX IF NOT EXISTS ix_loan_schedules_account_due
    ON bmt_db.loan_schedules (loan_account_id, due_date, installment_no);
CREATE INDEX IF NOT EXISTS ix_installment_payments_schedule_paid
    ON bmt_db.installment_payments (loan_schedule_id, paid_at DESC, id);
CREATE INDEX IF NOT EXISTS ix_journal_lines_entry
    ON bmt_db.journal_lines (journal_entry_id);
CREATE INDEX IF NOT EXISTS ix_user_branches_user_branch
    ON bmt_db.user_branches (user_id, branch_id);

CREATE OR REPLACE FUNCTION bmt_db.portal_get_loan_schedules(p_limit INTEGER DEFAULT 50, p_offset INTEGER DEFAULT 0)
RETURNS TABLE (
    id UUID, loan_account_id UUID, account_number VARCHAR, installment_no INTEGER, due_date DATE,
    opening_principal NUMERIC, principal_due NUMERIC, margin_due NUMERIC, other_due NUMERIC,
    total_due NUMERIC, principal_paid NUMERIC, margin_paid NUMERIC, penalty_paid NUMERIC,
    other_paid NUMERIC, paid_at TIMESTAMPTZ, status TEXT, days_overdue INTEGER
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $function$
    SELECT ls.id, ls.loan_account_id, fa.account_number, ls.installment_no, ls.due_date,
           ls.opening_principal, ls.principal_due, ls.margin_due, ls.other_due, ls.total_due,
           ls.principal_paid, ls.margin_paid, ls.penalty_paid, ls.other_paid, ls.paid_at,
           ls.status::TEXT, ls.days_overdue
    FROM bmt_db.loan_schedules ls
    JOIN bmt_db.loan_accounts la ON la.financial_account_id = ls.loan_account_id
    JOIN bmt_db.financial_accounts fa ON fa.id = la.financial_account_id
    JOIN bmt_db.customers c ON c.id = fa.customer_id
    WHERE auth.uid() IS NOT NULL AND c.auth_user_id = auth.uid()
    ORDER BY fa.account_number, ls.installment_no
    LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 50), 100)) OFFSET GREATEST(COALESCE(p_offset, 0), 0);
$function$;

CREATE OR REPLACE FUNCTION bmt_db.portal_get_transactions(p_limit INTEGER DEFAULT 50, p_offset INTEGER DEFAULT 0)
RETURNS TABLE (
    id UUID, transaction_number VARCHAR, transaction_type VARCHAR, financial_account_id UUID,
    account_number VARCHAR, amount NUMERIC, currency CHAR(3), transaction_date DATE, value_date DATE,
    status TEXT, channel TEXT, description TEXT, reference_number VARCHAR, posted_at TIMESTAMPTZ
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $function$
    SELECT t.id, t.transaction_number, t.transaction_type, t.financial_account_id, fa.account_number,
           t.amount, t.currency, t.transaction_date, t.value_date, t.status::TEXT, t.channel::TEXT,
           t.description, t.reference_number, t.posted_at
    FROM bmt_db.transactions t
    JOIN bmt_db.customers c ON c.id = t.customer_id
    LEFT JOIN bmt_db.financial_accounts fa ON fa.id = t.financial_account_id AND fa.customer_id = c.id
    WHERE auth.uid() IS NOT NULL AND c.auth_user_id = auth.uid()
    ORDER BY t.transaction_date DESC, t.created_at DESC, t.transaction_number
    LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 50), 100)) OFFSET GREATEST(COALESCE(p_offset, 0), 0);
$function$;

REVOKE ALL ON FUNCTION bmt_db.portal_get_loan_schedules(INTEGER, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.portal_get_loan_schedules(INTEGER, INTEGER) TO authenticated;
REVOKE ALL ON FUNCTION bmt_db.portal_get_transactions(INTEGER, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.portal_get_transactions(INTEGER, INTEGER) TO authenticated;

CREATE OR REPLACE VIEW bmt_db.security_definer_audit AS
SELECT n.nspname AS schema_name, p.proname AS function_name,
       pg_get_function_identity_arguments(p.oid) AS identity_arguments,
       p.prosecdef AS security_definer, p.proconfig AS configuration,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_can_execute,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated_can_execute,
       has_function_privilege('public', p.oid, 'EXECUTE') AS public_can_execute
FROM pg_catalog.pg_proc p
JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'bmt_db' AND p.prosecdef;

CREATE OR REPLACE VIEW bmt_db.rls_policy_audit AS
SELECT n.nspname AS schema_name, c.relname AS table_name, c.relrowsecurity AS rls_enabled,
       c.relforcerowsecurity AS rls_forced, count(pol.oid)::INTEGER AS policy_count
FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN pg_catalog.pg_policy pol ON pol.polrelid = c.oid
WHERE n.nspname = 'bmt_db' AND c.relkind = 'r'
GROUP BY n.nspname, c.relname, c.relrowsecurity, c.relforcerowsecurity;

CREATE TABLE IF NOT EXISTS bmt_db.operational_retention_policy (
    table_name TEXT PRIMARY KEY, retention_interval INTERVAL NOT NULL,
    archive_strategy TEXT NOT NULL, partition_key TEXT, reviewed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO bmt_db.operational_retention_policy(table_name, retention_interval, archive_strategy, partition_key)
VALUES
 ('financial_mutation_requests', interval '90 days', 'delete after archive export', 'created_at'),
 ('transactions', interval '10 years', 'archive immutable posted rows', 'transaction_date'),
 ('journal_entries', interval '10 years', 'archive immutable posted rows', 'journal_date'),
 ('audit_logs', interval '7 years', 'archive before deletion', 'created_at')
ON CONFLICT (table_name) DO UPDATE SET retention_interval = EXCLUDED.retention_interval,
 archive_strategy = EXCLUDED.archive_strategy, partition_key = EXCLUDED.partition_key, reviewed_at = now();

CREATE OR REPLACE FUNCTION bmt_db.data_volume_snapshot()
RETURNS TABLE (table_name TEXT, row_count BIGINT, recommended_action TEXT)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
    SELECT 'transactions'::TEXT, count(*)::BIGINT,
           CASE WHEN count(*) > 1000000 THEN 'partition by transaction_date' ELSE 'monitor growth' END
      FROM bmt_db.transactions
    UNION ALL
    SELECT 'journal_entries'::TEXT, count(*)::BIGINT,
           CASE WHEN count(*) > 1000000 THEN 'partition by journal_date' ELSE 'monitor growth' END
      FROM bmt_db.journal_entries
    UNION ALL
    SELECT 'installment_payments'::TEXT, count(*)::BIGINT,
           CASE WHEN count(*) > 1000000 THEN 'partition by paid_at' ELSE 'monitor growth' END
      FROM bmt_db.installment_payments;
$$;

REVOKE ALL ON FUNCTION bmt_db.data_volume_snapshot() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.data_volume_snapshot() TO authenticated;
