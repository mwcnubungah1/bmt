DO $$
DECLARE d TEXT;
BEGIN
 SELECT pg_get_functiondef(p.oid) INTO d FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='bmt_db' AND p.proname='customer_request_installment_payment' AND p.pronargs=3;
 d := replace(d, 'IF v_claimed AND v_claim.request_id IS NOT NULL THEN', 'IF FALSE THEN');
 EXECUTE d;
END $$;
