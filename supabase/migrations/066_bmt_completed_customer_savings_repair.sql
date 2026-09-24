BEGIN;

-- One account-opening path for manager completion, legacy CIF repair and portal retries.
CREATE OR REPLACE FUNCTION bmt_db.open_completed_customer_savings(p_application_id UUID, p_actor UUID)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_app bmt_db.onboarding_applications%ROWTYPE;
  v_customer bmt_db.customers%ROWTYPE;
  v_product bmt_db.products%ROWTYPE;
  v_account_id UUID;
  v_branch_code TEXT;
  v_sequence TEXT;
  v_attempt INTEGER;
BEGIN
  SELECT * INTO v_app FROM bmt_db.onboarding_applications WHERE id = p_application_id AND status = 'COMPLETED';
  IF NOT FOUND OR v_app.customer_id IS NULL THEN RAISE EXCEPTION 'Completed onboarding application is required'; END IF;
  SELECT * INTO v_customer FROM bmt_db.customers WHERE id = v_app.customer_id FOR UPDATE;
  IF NOT FOUND OR v_customer.status <> 'ACTIVE' THEN RAISE EXCEPTION 'Active customer profile is required'; END IF;
  IF v_customer.auth_user_id IS NULL AND v_app.applicant_user_id IS NOT NULL THEN
    UPDATE bmt_db.customers SET auth_user_id = v_app.applicant_user_id WHERE id = v_customer.id;
  END IF;
  SELECT id INTO v_account_id FROM bmt_db.financial_accounts
  WHERE customer_id = v_customer.id AND account_type = 'SAVINGS' AND status IN ('ACTIVE','PENDING')
  ORDER BY created_at LIMIT 1;
  IF v_account_id IS NOT NULL THEN RETURN v_account_id; END IF;

  SELECT p.* INTO v_product FROM bmt_db.onboarding_product_requests r
  JOIN bmt_db.products p ON p.id = r.product_id
  WHERE r.application_id = v_app.id AND p.category = 'SAVINGS' AND p.is_active
  ORDER BY r.created_at DESC LIMIT 1;
  IF NOT FOUND THEN
    SELECT p.* INTO v_product FROM bmt_db.products p
    WHERE p.category = 'SAVINGS' AND p.is_active ORDER BY p.code LIMIT 1;
  END IF;
  IF NOT FOUND THEN RAISE EXCEPTION 'Active savings product is required'; END IF;
  SELECT code INTO v_branch_code FROM bmt_db.branches WHERE id = v_customer.branch_id AND is_active;
  IF v_branch_code IS NULL THEN RAISE EXCEPTION 'Active customer branch is required'; END IF;

  -- Legacy/seed accounts may have consumed sequence numbers without advancing
  -- number_sequences. Retry under next_sequence's row lock until both unique
  -- account identifiers are free; never overwrite an existing account.
  FOR v_attempt IN 1..1000 LOOP
    v_sequence := bmt_db.next_sequence(v_customer.branch_id, 'SAVINGS_ACCOUNT', '', '', CURRENT_DATE, 'NEVER', 8);
    IF NOT EXISTS (
      SELECT 1 FROM bmt_db.financial_accounts fa
      WHERE fa.account_number = v_branch_code || '.' || v_sequence
         OR (fa.branch_id = v_customer.branch_id AND fa.account_type = 'SAVINGS'
           AND fa.product_id = v_product.id AND fa.sequence_no = v_sequence::BIGINT)
    ) THEN EXIT; END IF;
    v_sequence := NULL;
  END LOOP;
  IF v_sequence IS NULL THEN RAISE EXCEPTION 'No available savings account number'; END IF;
  INSERT INTO bmt_db.financial_accounts(account_number, account_type, customer_id, branch_id, product_id, status, opened_at, opened_by, sequence_no)
  VALUES (v_branch_code || '.' || v_sequence, 'SAVINGS', v_customer.id, v_customer.branch_id, v_product.id, 'ACTIVE', now(), p_actor, v_sequence::BIGINT)
  RETURNING id INTO v_account_id;
  INSERT INTO bmt_db.savings_accounts(financial_account_id, current_balance, available_balance)
  VALUES (v_account_id, 0, 0);
  INSERT INTO bmt_db.audit_logs(user_id, branch_id, action, entity_type, entity_id, new_data, metadata)
  VALUES (p_actor, v_customer.branch_id, 'SAVINGS_ACCOUNT_OPENED', 'FINANCIAL_ACCOUNT', v_account_id,
    jsonb_build_object('product_id', v_product.id, 'account_number', v_branch_code || '.' || v_sequence),
    jsonb_build_object('source', 'COMPLETED_ONBOARDING', 'application_id', v_app.id));
  RETURN v_account_id;
END; $$;
REVOKE ALL ON FUNCTION bmt_db.open_completed_customer_savings(UUID, UUID) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION bmt_db.open_savings_account_after_onboarding()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NEW.status = 'COMPLETED' AND NEW.customer_id IS NOT NULL THEN
    PERFORM bmt_db.open_completed_customer_savings(NEW.id, COALESCE(NEW.manager_reviewed_by, NEW.created_by));
  END IF;
  RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS trg_open_savings_after_onboarding ON bmt_db.onboarding_applications;
CREATE TRIGGER trg_open_savings_after_onboarding
AFTER UPDATE OF status, customer_id ON bmt_db.onboarding_applications
FOR EACH ROW WHEN (NEW.status = 'COMPLETED' AND NEW.customer_id IS NOT NULL)
EXECUTE FUNCTION bmt_db.open_savings_account_after_onboarding();
REVOKE ALL ON FUNCTION bmt_db.open_savings_account_after_onboarding() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION bmt_db.ensure_customer_savings_account()
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_customer_id UUID; v_application_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  SELECT id INTO v_customer_id FROM bmt_db.customers WHERE auth_user_id = auth.uid() AND status = 'ACTIVE';
  IF v_customer_id IS NULL THEN
    SELECT c.id INTO v_customer_id FROM bmt_db.onboarding_applications oa
    JOIN bmt_db.customers c ON c.id = oa.customer_id
    WHERE oa.applicant_user_id = auth.uid() AND oa.status = 'COMPLETED' AND c.status = 'ACTIVE'
    ORDER BY oa.completed_at DESC NULLS LAST LIMIT 1;
  END IF;
  IF v_customer_id IS NULL THEN RAISE EXCEPTION 'Active customer profile is required'; END IF;
  SELECT id INTO v_application_id FROM bmt_db.onboarding_applications
  WHERE customer_id = v_customer_id AND status = 'COMPLETED'
  ORDER BY completed_at DESC NULLS LAST, created_at DESC LIMIT 1;
  IF v_application_id IS NULL THEN RAISE EXCEPTION 'Completed onboarding application is required'; END IF;
  RETURN bmt_db.open_completed_customer_savings(v_application_id, auth.uid());
END; $$;
REVOKE ALL ON FUNCTION bmt_db.ensure_customer_savings_account() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.ensure_customer_savings_account() TO authenticated;

-- Complete the missing accounts from earlier registrations, including Agil.
DO $$
DECLARE v_application RECORD;
BEGIN
  FOR v_application IN
    SELECT oa.id, COALESCE(oa.manager_reviewed_by, oa.created_by) AS actor
    FROM bmt_db.onboarding_applications oa
    WHERE oa.status = 'COMPLETED' AND oa.customer_id IS NOT NULL
      AND EXISTS (SELECT 1 FROM bmt_db.onboarding_product_requests r JOIN bmt_db.products p ON p.id=r.product_id
        WHERE r.application_id=oa.id AND p.category='SAVINGS' AND p.is_active)
      AND NOT EXISTS (SELECT 1 FROM bmt_db.financial_accounts fa
        WHERE fa.customer_id = oa.customer_id AND fa.account_type = 'SAVINGS' AND fa.status IN ('ACTIVE','PENDING'))
    ORDER BY oa.completed_at, oa.id
  LOOP
    PERFORM bmt_db.open_completed_customer_savings(v_application.id, v_application.actor);
  END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';
COMMIT;
