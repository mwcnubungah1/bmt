BEGIN;

-- The payment RPC is intentionally idempotent. Its exception path must not
-- dereference an unassigned RECORD when a retry returns an existing claim.
DO $migration$
DECLARE
  v_definition TEXT;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_definition
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'bmt_db'
    AND p.proname = 'customer_request_installment_payment'
    AND pg_get_function_identity_arguments(p.oid) = 'p_loan_schedule_id uuid, p_amount numeric, p_idempotency_key text';
  IF v_definition IS NULL THEN RAISE EXCEPTION 'Payment function not found'; END IF;
  v_definition := replace(v_definition, 'v_new_balance NUMERIC;', 'v_new_balance NUMERIC;' || chr(10) || '    v_claimed BOOLEAN := FALSE;');
  v_definition := replace(v_definition, 'IF NOT v_claim.is_new THEN', 'IF NOT v_claim.is_new THEN');
  v_definition := replace(v_definition, 'END IF;' || chr(10) || '    PERFORM pg_advisory_xact_lock(hashtext(''installment-post:'' || p_loan_schedule_id::TEXT));', 'END IF;' || chr(10) || '    v_claimed := TRUE;' || chr(10) || '    PERFORM pg_advisory_xact_lock(hashtext(''installment-post:'' || p_loan_schedule_id::TEXT));');
  v_definition := replace(v_definition, 'IF FOUND AND v_claim.request_id IS NOT NULL THEN', 'IF v_claimed AND v_claim.request_id IS NOT NULL THEN');
  EXECUTE v_definition;
END;
$migration$;

COMMIT;
