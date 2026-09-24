BEGIN;

-- Local-only payment fixture for nasabah11@nara.di. This migration is
-- intentionally deterministic and must not be applied to production.
DO $$
DECLARE
  v_user UUID;
  v_branch UUID;
  v_customer UUID;
  v_savings_product UUID;
  v_loan_product UUID;
  v_savings UUID;
  v_loan_app UUID;
  v_loan_account UUID;
BEGIN
  SELECT id INTO v_user FROM auth.users WHERE email = 'nasabah11@nara.di';
  -- This is optional demo data. Production deployments usually do not have
  -- the local fixture user, so skip the fixture instead of failing db push.
  IF v_user IS NULL THEN RETURN; END IF;
  SELECT id INTO v_branch FROM bmt_db.branches WHERE code = '001' LIMIT 1;
  SELECT id INTO v_savings_product FROM bmt_db.products WHERE code = 'SAV40' AND category = 'SAVINGS' LIMIT 1;
  SELECT id INTO v_loan_product FROM bmt_db.products WHERE code = 'LOAN409' AND category = 'LOAN' LIMIT 1;
  IF v_branch IS NULL OR v_savings_product IS NULL OR v_loan_product IS NULL THEN RETURN; END IF;

  SELECT id INTO v_customer FROM bmt_db.customers WHERE auth_user_id = v_user;
  IF v_customer IS NULL THEN
    INSERT INTO bmt_db.customers(cif_number, nik, full_name, birth_place, birth_date, gender, occupation, monthly_income, phone, email, branch_id, status, registered_at, auth_user_id)
    VALUES ('900000000011', '3525000000110011', 'Maghfur Demo', 'Gresik', '1990-01-11', 'MALE', 'Wiraswasta', 8000000, '081234567811', 'nasabah11@nara.di', v_branch, 'ACTIVE', now(), v_user)
    RETURNING id INTO v_customer;
  ELSE
    UPDATE bmt_db.customers SET status = 'ACTIVE', auth_user_id = v_user, email = 'nasabah11@nara.di' WHERE id = v_customer;
  END IF;

  SELECT fa.id INTO v_savings
    FROM bmt_db.financial_accounts fa
   WHERE fa.customer_id = v_customer AND fa.account_type = 'SAVINGS'
   ORDER BY fa.created_at LIMIT 1;
  IF v_savings IS NULL THEN
    INSERT INTO bmt_db.financial_accounts(account_number, account_type, customer_id, branch_id, product_id, status, opened_at, opened_by, sequence_no)
    VALUES ('80000000.11', 'SAVINGS', v_customer, v_branch, v_savings_product, 'ACTIVE', now(), v_user,
      (SELECT COALESCE(max(sequence_no), 0) + 1 FROM bmt_db.financial_accounts WHERE branch_id = v_branch AND account_type = 'SAVINGS' AND product_id = v_savings_product))
    RETURNING id INTO v_savings;
    INSERT INTO bmt_db.savings_accounts(financial_account_id, current_balance, available_balance)
    VALUES (v_savings, 3000000, 3000000);
  ELSE
    UPDATE bmt_db.savings_accounts SET current_balance = 3000000, available_balance = 3000000 WHERE financial_account_id = v_savings;
  END IF;

  SELECT id INTO v_loan_app FROM bmt_db.loan_applications WHERE application_number = 'APP-DEMO-MAGHFUR' AND customer_id = v_customer;
  IF v_loan_app IS NULL THEN
    INSERT INTO bmt_db.loan_applications(application_number, customer_id, savings_account_id, loan_product_id, branch_id, requested_amount, requested_tenor_months, purpose, status, submitted_at, decided_at, created_by)
    VALUES ('APP-DEMO-MAGHFUR', v_customer, v_savings, v_loan_product, v_branch, 1200000, 12, 'Modal usaha demo', 'APPROVED', now(), now(), v_user)
    RETURNING id INTO v_loan_app;
  END IF;

  SELECT financial_account_id INTO v_loan_account FROM bmt_db.loan_accounts WHERE application_id = v_loan_app;
  IF v_loan_account IS NULL THEN
    INSERT INTO bmt_db.financial_accounts(account_number, account_type, customer_id, branch_id, product_id, status, opened_at, opened_by, sequence_no)
    VALUES ('80000000.11.01', 'LOAN', v_customer, v_branch, v_loan_product, 'ACTIVE', now(), v_user,
      (SELECT COALESCE(max(sequence_no), 0) + 1 FROM bmt_db.financial_accounts WHERE branch_id = v_branch AND account_type = 'LOAN' AND product_id = v_loan_product))
    RETURNING id INTO v_loan_account;
    INSERT INTO bmt_db.loan_accounts(financial_account_id, application_id, savings_account_id, principal_amount, tenor_months, rate, margin_amount, disbursement_amount, outstanding_principal, outstanding_margin, loan_status, disbursement_date)
    VALUES (v_loan_account, v_loan_app, v_savings, 1200000, 12, 10, 120000, 1200000, 1200000, 120000, 'ACTIVE', CURRENT_DATE);
    INSERT INTO bmt_db.loan_schedules(loan_account_id, installment_no, due_date, opening_principal, principal_due, margin_due, other_due, total_due, status)
    VALUES (v_loan_account, 1, CURRENT_DATE, 1200000, 100000, 10000, 0, 110000, 'DUE');
  END IF;
END $$;

COMMIT;
