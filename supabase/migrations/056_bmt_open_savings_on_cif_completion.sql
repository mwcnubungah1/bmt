BEGIN;

CREATE OR REPLACE FUNCTION bmt_db.open_savings_account_after_onboarding()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_product bmt_db.products%ROWTYPE;
    v_branch_code TEXT;
    v_sequence TEXT;
    v_account_id UUID;
BEGIN
    IF NEW.status <> 'COMPLETED' OR NEW.customer_id IS NULL THEN RETURN NEW; END IF;
    IF EXISTS (
        SELECT 1 FROM bmt_db.financial_accounts
        WHERE customer_id = NEW.customer_id AND account_type = 'SAVINGS' AND status IN ('ACTIVE', 'PENDING')
    ) THEN RETURN NEW; END IF;

    SELECT p.* INTO v_product
    FROM bmt_db.onboarding_product_requests r
    JOIN bmt_db.products p ON p.id = r.product_id
    WHERE r.application_id = NEW.id AND p.category = 'SAVINGS' AND p.is_active
    ORDER BY r.created_at DESC LIMIT 1;
    IF NOT FOUND THEN
        SELECT p.* INTO v_product FROM bmt_db.products p
        WHERE p.category = 'SAVINGS' AND p.is_active ORDER BY p.code LIMIT 1;
    END IF;
    IF NOT FOUND THEN RAISE EXCEPTION 'Active savings product is required before CIF completion'; END IF;

    SELECT b.code INTO v_branch_code FROM bmt_db.branches b
    JOIN bmt_db.customers c ON c.branch_id = b.id
    WHERE c.id = NEW.customer_id AND b.is_active;
    IF v_branch_code IS NULL THEN RAISE EXCEPTION 'Active customer branch is required before savings account opening'; END IF;

    v_sequence := bmt_db.next_sequence(
        (SELECT branch_id FROM bmt_db.customers WHERE id = NEW.customer_id),
        'SAVINGS_ACCOUNT', '', '', CURRENT_DATE, 'NEVER', 8
    );
    INSERT INTO bmt_db.financial_accounts(account_number, account_type, customer_id, branch_id, product_id, status, opened_at, opened_by, sequence_no)
    SELECT v_branch_code || '.' || v_sequence, 'SAVINGS', c.id, c.branch_id, v_product.id, 'ACTIVE', now(), COALESCE(NEW.manager_reviewed_by, NEW.created_by), v_sequence::BIGINT
    FROM bmt_db.customers c WHERE c.id = NEW.customer_id
    RETURNING id INTO v_account_id;
    INSERT INTO bmt_db.savings_accounts(financial_account_id, current_balance, available_balance)
    VALUES (v_account_id, 0, 0);
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_open_savings_after_onboarding ON bmt_db.onboarding_applications;
CREATE TRIGGER trg_open_savings_after_onboarding
AFTER UPDATE OF status, customer_id ON bmt_db.onboarding_applications
FOR EACH ROW
WHEN (NEW.status = 'COMPLETED' AND NEW.customer_id IS NOT NULL)
EXECUTE FUNCTION bmt_db.open_savings_account_after_onboarding();

-- Repair completed CIFs created before this trigger existed.
UPDATE bmt_db.onboarding_applications oa
SET customer_id = oa.customer_id
WHERE oa.status = 'COMPLETED'
  AND oa.customer_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM bmt_db.financial_accounts fa
      WHERE fa.customer_id = oa.customer_id AND fa.account_type = 'SAVINGS' AND fa.status IN ('ACTIVE', 'PENDING')
  );

REVOKE ALL ON FUNCTION bmt_db.open_savings_account_after_onboarding() FROM PUBLIC, anon, authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
