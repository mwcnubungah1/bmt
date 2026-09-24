BEGIN;

CREATE OR REPLACE FUNCTION bmt_db.ensure_customer_savings_account()
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
    v_customer bmt_db.customers%ROWTYPE;
    v_application bmt_db.onboarding_applications%ROWTYPE;
    v_product bmt_db.products%ROWTYPE;
    v_account bmt_db.financial_accounts%ROWTYPE;
    v_sequence TEXT;
    v_account_id UUID;
BEGIN
    IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
    SELECT * INTO v_customer FROM bmt_db.customers WHERE auth_user_id = auth.uid() FOR UPDATE;
    IF NOT FOUND OR v_customer.status <> 'ACTIVE' THEN RAISE EXCEPTION 'Active customer profile is required'; END IF;

    SELECT * INTO v_account
    FROM bmt_db.financial_accounts
    WHERE customer_id = v_customer.id AND account_type = 'SAVINGS' AND status IN ('ACTIVE', 'PENDING')
    ORDER BY created_at
    LIMIT 1;
    IF FOUND THEN RETURN v_account.id; END IF;

    SELECT oa.* INTO v_application
    FROM bmt_db.onboarding_applications oa
    WHERE oa.customer_id = v_customer.id AND oa.status = 'COMPLETED'
    ORDER BY oa.completed_at DESC NULLS LAST, oa.created_at DESC
    LIMIT 1;
    IF NOT FOUND THEN RAISE EXCEPTION 'Completed onboarding application is required'; END IF;

    SELECT p.* INTO v_product
    FROM bmt_db.onboarding_product_requests r
    JOIN bmt_db.products p ON p.id = r.product_id
    WHERE r.application_id = v_application.id AND p.category = 'SAVINGS' AND p.is_active
    ORDER BY r.created_at DESC LIMIT 1;
    IF NOT FOUND THEN
        SELECT p.* INTO v_product FROM bmt_db.products p WHERE p.category = 'SAVINGS' AND p.is_active ORDER BY p.code LIMIT 1;
    END IF;
    IF NOT FOUND THEN RAISE EXCEPTION 'Active savings product is not configured'; END IF;

    v_sequence := bmt_db.next_sequence(v_customer.branch_id, 'SAVINGS_ACCOUNT', v_product.code, '', CURRENT_DATE, 'NEVER', 8);
    INSERT INTO bmt_db.financial_accounts(account_number, account_type, customer_id, branch_id, product_id, status, opened_at, opened_by, sequence_no)
    VALUES ((SELECT code FROM bmt_db.branches WHERE id = v_customer.branch_id) || '.' || v_sequence, 'SAVINGS', v_customer.id, v_customer.branch_id, v_product.id, 'ACTIVE', now(), auth.uid(), v_sequence::BIGINT)
    RETURNING id INTO v_account_id;
    INSERT INTO bmt_db.savings_accounts(financial_account_id, current_balance, available_balance)
    VALUES (v_account_id, 0, 0);
    INSERT INTO bmt_db.audit_logs(user_id, branch_id, action, entity_type, entity_id, new_data, metadata)
    VALUES (auth.uid(), v_customer.branch_id, 'SAVINGS_ACCOUNT_OPENED', 'FINANCIAL_ACCOUNT', v_account_id, jsonb_build_object('product_id', v_product.id, 'account_number', (SELECT account_number FROM bmt_db.financial_accounts WHERE id = v_account_id)), jsonb_build_object('channel', 'CUSTOMER_PORTAL'));
    RETURN v_account_id;
END;
$$;

REVOKE ALL ON FUNCTION bmt_db.ensure_customer_savings_account() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.ensure_customer_savings_account() TO authenticated;

COMMIT;
