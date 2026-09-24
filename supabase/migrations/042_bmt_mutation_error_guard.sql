BEGIN;

-- Preserve the original RPC error when claiming idempotency fails. The old
-- handler dereferenced an unassigned RECORD and masked it with this error.
DO $migration$
DECLARE
    v_definition TEXT;
BEGIN
    SELECT pg_get_functiondef(p.oid) INTO v_definition
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'bmt_db' AND p.proname = 'customer_submit_loan_application'
      AND pg_get_function_identity_arguments(p.oid) = 'p_savings_account_id uuid, p_loan_product_id uuid, p_requested_amount numeric, p_requested_tenor_months integer, p_purpose text, p_idempotency_key text';
    EXECUTE replace(v_definition, 'IF v_claim.request_id IS NOT NULL THEN', 'IF FOUND AND v_claim.request_id IS NOT NULL THEN');

    SELECT pg_get_functiondef(p.oid) INTO v_definition
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'bmt_db' AND p.proname = 'customer_request_installment_payment'
      AND pg_get_function_identity_arguments(p.oid) = 'p_loan_schedule_id uuid, p_amount numeric, p_idempotency_key text';
    EXECUTE replace(v_definition, 'IF v_claim.request_id IS NOT NULL THEN', 'IF FOUND AND v_claim.request_id IS NOT NULL THEN');
END;
$migration$;

COMMIT;
