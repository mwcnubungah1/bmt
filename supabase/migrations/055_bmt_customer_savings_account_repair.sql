BEGIN;

-- Repair environments where the account-creation RPC was not applied even
-- though the customer portal and financial tables are already available.
INSERT INTO bmt_db.number_sequences(branch_id, sequence_type, product_code, loan_code, period_key, current_value, padding, reset_policy)
SELECT fa.branch_id, 'SAVINGS_ACCOUNT', '', '', '', COALESCE(MAX(fa.sequence_no), 0), 8, 'NEVER'
FROM bmt_db.financial_accounts fa
WHERE fa.account_type = 'SAVINGS'
GROUP BY fa.branch_id
ON CONFLICT (branch_id, sequence_type, product_code, loan_code, period_key)
DO UPDATE SET current_value = GREATEST(bmt_db.number_sequences.current_value, EXCLUDED.current_value), updated_at = now();

CREATE OR REPLACE FUNCTION bmt_db.ensure_customer_savings_account()
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
    v_customer bmt_db.customers%ROWTYPE; v_application bmt_db.onboarding_applications%ROWTYPE;
    v_product bmt_db.products%ROWTYPE; v_account bmt_db.financial_accounts%ROWTYPE;
    v_sequence TEXT; v_account_id UUID; v_branch_code TEXT;
BEGIN
    IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
    SELECT * INTO v_customer FROM bmt_db.customers WHERE auth_user_id = auth.uid() FOR UPDATE;
    IF NOT FOUND THEN
        -- Some older CIF seed rows were created before auth_user_id was linked.
        -- Link only through the authenticated user's own completed onboarding.
        SELECT c.* INTO v_customer
        FROM bmt_db.onboarding_applications oa
        JOIN bmt_db.customers c ON c.id = oa.customer_id
        WHERE oa.applicant_user_id = auth.uid() AND oa.status = 'COMPLETED'
        ORDER BY oa.completed_at DESC NULLS LAST, oa.created_at DESC
        LIMIT 1
        FOR UPDATE OF c;
        IF FOUND THEN
            UPDATE bmt_db.customers SET auth_user_id = auth.uid() WHERE id = v_customer.id;
        END IF;
    END IF;
    IF NOT FOUND OR v_customer.status <> 'ACTIVE' THEN RAISE EXCEPTION 'Active customer profile is required'; END IF;
    SELECT * INTO v_account FROM bmt_db.financial_accounts WHERE customer_id = v_customer.id AND account_type = 'SAVINGS' AND status IN ('ACTIVE','PENDING') ORDER BY created_at LIMIT 1;
    IF FOUND THEN RETURN v_account.id; END IF;
    SELECT * INTO v_application FROM bmt_db.onboarding_applications WHERE customer_id = v_customer.id AND status = 'COMPLETED' ORDER BY completed_at DESC NULLS LAST, created_at DESC LIMIT 1;
    IF NOT FOUND THEN RAISE EXCEPTION 'Completed onboarding application is required'; END IF;
    SELECT p.* INTO v_product FROM bmt_db.onboarding_product_requests r JOIN bmt_db.products p ON p.id = r.product_id WHERE r.application_id = v_application.id AND p.category = 'SAVINGS' AND p.is_active ORDER BY r.created_at DESC LIMIT 1;
    IF NOT FOUND THEN SELECT p.* INTO v_product FROM bmt_db.products p WHERE p.category = 'SAVINGS' AND p.is_active ORDER BY p.code LIMIT 1; END IF;
    IF NOT FOUND THEN RAISE EXCEPTION 'Active savings product is not configured'; END IF;
    SELECT code INTO v_branch_code FROM bmt_db.branches WHERE id = v_customer.branch_id AND is_active;
    IF v_branch_code IS NULL THEN RAISE EXCEPTION 'Active customer branch is required'; END IF;
    v_sequence := bmt_db.next_sequence(v_customer.branch_id, 'SAVINGS_ACCOUNT', '', '', CURRENT_DATE, 'NEVER', 8);
    INSERT INTO bmt_db.financial_accounts(account_number, account_type, customer_id, branch_id, product_id, status, opened_at, opened_by, sequence_no)
    VALUES (v_branch_code || '.' || v_sequence, 'SAVINGS', v_customer.id, v_customer.branch_id, v_product.id, 'ACTIVE', now(), auth.uid(), v_sequence::BIGINT) RETURNING id INTO v_account_id;
    INSERT INTO bmt_db.savings_accounts(financial_account_id, current_balance, available_balance) VALUES (v_account_id, 0, 0);
    RETURN v_account_id;
END; $$;

REVOKE ALL ON FUNCTION bmt_db.ensure_customer_savings_account() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.ensure_customer_savings_account() TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
