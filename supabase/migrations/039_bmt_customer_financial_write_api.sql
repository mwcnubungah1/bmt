BEGIN;

CREATE OR REPLACE FUNCTION bmt_db.customer_submit_loan_application(
    p_savings_account_id UUID,
    p_loan_product_id UUID,
    p_requested_amount NUMERIC,
    p_requested_tenor_months INTEGER,
    p_purpose TEXT,
    p_idempotency_key TEXT
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
    v_user UUID := auth.uid();
    v_customer bmt_db.customers%ROWTYPE;
    v_product bmt_db.loan_products%ROWTYPE;
    v_application UUID;
    v_claim RECORD;
BEGIN
    IF v_user IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
    IF NULLIF(btrim(p_idempotency_key), '') IS NULL THEN RAISE EXCEPTION 'Idempotency key is required'; END IF;
    IF p_requested_amount <= 0 OR p_requested_tenor_months <= 0 OR NULLIF(btrim(p_purpose), '') IS NULL THEN
        RAISE EXCEPTION 'Amount, tenor and purpose are required';
    END IF;

    SELECT * INTO v_customer FROM bmt_db.customers WHERE auth_user_id = v_user FOR SHARE;
    IF NOT FOUND OR v_customer.status <> 'ACTIVE' THEN RAISE EXCEPTION 'Active customer profile is required'; END IF;

    SELECT lp.* INTO v_product
    FROM bmt_db.loan_products lp
    JOIN bmt_db.products p ON p.id = lp.product_id
    WHERE lp.product_id = p_loan_product_id AND p.is_active = TRUE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Loan product is not active'; END IF;
    IF p_requested_amount < v_product.minimum_principal OR (v_product.maximum_principal IS NOT NULL AND p_requested_amount > v_product.maximum_principal) THEN
        RAISE EXCEPTION 'Requested amount is outside the product limit';
    END IF;
    IF p_requested_tenor_months < v_product.minimum_tenor_months OR p_requested_tenor_months > v_product.maximum_tenor_months THEN
        RAISE EXCEPTION 'Requested tenor is outside the product limit';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM bmt_db.savings_accounts sa
        JOIN bmt_db.financial_accounts fa ON fa.id = sa.financial_account_id
        WHERE sa.financial_account_id = p_savings_account_id
          AND fa.customer_id = v_customer.id
          AND fa.status IN ('ACTIVE', 'PENDING')
    ) THEN RAISE EXCEPTION 'Source savings account is not owned by the customer'; END IF;

    SELECT * INTO v_claim FROM bmt_db.claim_financial_mutation(
        'customer_submit_loan_application', p_idempotency_key,
        concat(p_savings_account_id, ':', p_loan_product_id, ':', p_requested_amount, ':', p_requested_tenor_months, ':', p_purpose)
    );
    IF NOT v_claim.is_new THEN
        IF v_claim.status = 'SUCCEEDED' THEN RETURN v_claim.result_id; END IF;
        RAISE EXCEPTION 'Request is already being processed or failed';
    END IF;

    INSERT INTO bmt_db.loan_applications(
        application_number, customer_id, savings_account_id, loan_product_id,
        branch_id, requested_amount, requested_tenor_months, purpose,
        status, submitted_at, created_by
    ) VALUES (
        'LOAN-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS') || '-' || substr(replace(gen_random_uuid()::TEXT, '-', ''), 1, 8),
        v_customer.id, p_savings_account_id, p_loan_product_id, v_customer.branch_id,
        p_requested_amount, p_requested_tenor_months, btrim(p_purpose), 'SUBMITTED', now(), v_user
    ) RETURNING id INTO v_application;

    INSERT INTO bmt_db.audit_logs(user_id, branch_id, action, entity_type, entity_id, new_data, metadata)
    VALUES (v_user, v_customer.branch_id, 'LOAN_APPLICATION_SUBMITTED', 'LOAN_APPLICATION', v_application,
            jsonb_build_object('amount', p_requested_amount, 'tenor_months', p_requested_tenor_months),
            jsonb_build_object('channel', 'CUSTOMER_PORTAL'));
    PERFORM bmt_db.complete_financial_mutation(v_claim.request_id, 'SUCCEEDED', v_application, 201);
    RETURN v_application;
EXCEPTION WHEN OTHERS THEN
    IF FOUND AND v_claim.request_id IS NOT NULL THEN
        PERFORM bmt_db.complete_financial_mutation(v_claim.request_id, 'FAILED', NULL, 400);
    END IF;
    RAISE;
END;
$$;

CREATE OR REPLACE FUNCTION bmt_db.staff_review_loan_application(
    p_application_id UUID,
    p_decision TEXT,
    p_reason TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
    v_app bmt_db.loan_applications%ROWTYPE;
    v_target bmt_db.loan_application_status;
BEGIN
    IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
    SELECT * INTO v_app FROM bmt_db.loan_applications WHERE id = p_application_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Loan application not found'; END IF;
    IF NOT (bmt_db.current_user_is_superadmin() OR bmt_db.current_user_has_branch_access(v_app.branch_id)) THEN
        RAISE EXCEPTION 'Branch access required';
    END IF;
    IF upper(p_decision) = 'REVIEW' AND v_app.status = 'SUBMITTED' THEN
        v_target := 'REVIEW';
    ELSIF upper(p_decision) = 'APPROVE' AND v_app.status = 'REVIEW' AND (bmt_db.current_user_is_superadmin() OR bmt_db.current_user_has_role('MANAGER', v_app.branch_id)) THEN
        v_target := 'APPROVED';
    ELSIF upper(p_decision) = 'REJECT' AND v_app.status IN ('SUBMITTED', 'REVIEW') THEN
        v_target := 'REJECTED';
    ELSE
        RAISE EXCEPTION 'Invalid loan application transition';
    END IF;
    UPDATE bmt_db.loan_applications SET status = v_target, decided_at = CASE WHEN v_target IN ('APPROVED','REJECTED') THEN now() ELSE decided_at END, marketing_user_id = CASE WHEN v_target = 'REVIEW' THEN auth.uid() ELSE marketing_user_id END, updated_at = now() WHERE id = p_application_id;
    INSERT INTO bmt_db.loan_application_status_history(loan_application_id, old_status, new_status, changed_by, reason)
    VALUES (p_application_id, v_app.status, v_target, auth.uid(), p_reason);
    INSERT INTO bmt_db.audit_logs(user_id, branch_id, action, entity_type, entity_id, reason, metadata)
    VALUES (auth.uid(), v_app.branch_id, 'LOAN_APPLICATION_STATUS_CHANGED', 'LOAN_APPLICATION', p_application_id, p_reason, jsonb_build_object('from', v_app.status, 'to', v_target));
END;
$$;

CREATE OR REPLACE FUNCTION bmt_db.customer_request_installment_payment(
    p_loan_schedule_id UUID,
    p_amount NUMERIC,
    p_idempotency_key TEXT
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
    v_user UUID := auth.uid(); v_customer bmt_db.customers%ROWTYPE; v_schedule bmt_db.loan_schedules%ROWTYPE;
    v_loan bmt_db.loan_accounts%ROWTYPE; v_fa bmt_db.financial_accounts%ROWTYPE; v_tx UUID; v_claim RECORD;
BEGIN
    IF v_user IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
    IF p_amount <= 0 OR NULLIF(btrim(p_idempotency_key), '') IS NULL THEN RAISE EXCEPTION 'Amount and idempotency key are required'; END IF;
    SELECT * INTO v_customer FROM bmt_db.customers WHERE auth_user_id = v_user;
    SELECT ls.* INTO v_schedule FROM bmt_db.loan_schedules ls WHERE ls.id = p_loan_schedule_id FOR SHARE;
    SELECT * INTO v_loan FROM bmt_db.loan_accounts WHERE financial_account_id = v_schedule.loan_account_id;
    SELECT * INTO v_fa FROM bmt_db.financial_accounts WHERE id = v_loan.savings_account_id;
    IF v_customer.id IS NULL OR v_fa.customer_id <> v_customer.id THEN RAISE EXCEPTION 'Schedule is not owned by the customer'; END IF;
    IF p_amount > (v_schedule.total_due - v_schedule.principal_paid - v_schedule.margin_paid - v_schedule.penalty_paid - v_schedule.other_paid) THEN RAISE EXCEPTION 'Payment exceeds remaining installment'; END IF;
    SELECT * INTO v_claim FROM bmt_db.claim_financial_mutation('customer_request_installment_payment', p_idempotency_key, concat(p_loan_schedule_id, ':', p_amount));
    IF NOT v_claim.is_new THEN IF v_claim.status = 'SUCCEEDED' THEN RETURN v_claim.result_id; END IF; RAISE EXCEPTION 'Request is already being processed or failed'; END IF;
    INSERT INTO bmt_db.transactions(transaction_number, branch_id, transaction_type, customer_id, financial_account_id, amount, status, channel, description, created_by)
    VALUES ('PAY-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS') || '-' || substr(replace(gen_random_uuid()::TEXT, '-', ''), 1, 8), v_fa.branch_id, 'INSTALLMENT_PAYMENT', v_customer.id, v_loan.savings_account_id, p_amount, 'PENDING_APPROVAL', 'ONLINE', 'Permintaan pembayaran angsuran', v_user)
    RETURNING id INTO v_tx;
    INSERT INTO bmt_db.audit_logs(user_id, branch_id, action, entity_type, entity_id, transaction_id, metadata)
    VALUES (v_user, v_fa.branch_id, 'INSTALLMENT_PAYMENT_REQUESTED', 'LOAN_SCHEDULE', p_loan_schedule_id, v_tx, jsonb_build_object('amount', p_amount));
    PERFORM bmt_db.complete_financial_mutation(v_claim.request_id, 'SUCCEEDED', v_tx, 202);
    RETURN v_tx;
EXCEPTION WHEN OTHERS THEN
    IF FOUND AND v_claim.request_id IS NOT NULL THEN PERFORM bmt_db.complete_financial_mutation(v_claim.request_id, 'FAILED', NULL, 400); END IF;
    RAISE;
END;
$$;

REVOKE ALL ON FUNCTION bmt_db.customer_submit_loan_application(UUID, UUID, NUMERIC, INTEGER, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.customer_submit_loan_application(UUID, UUID, NUMERIC, INTEGER, TEXT, TEXT) TO authenticated;
REVOKE ALL ON FUNCTION bmt_db.staff_review_loan_application(UUID, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.staff_review_loan_application(UUID, TEXT, TEXT) TO authenticated;
REVOKE ALL ON FUNCTION bmt_db.customer_request_installment_payment(UUID, NUMERIC, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.customer_request_installment_payment(UUID, NUMERIC, TEXT) TO authenticated;

COMMIT;
