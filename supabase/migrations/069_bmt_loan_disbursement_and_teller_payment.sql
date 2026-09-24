BEGIN;

-- Disbursement is performed by a teller after manager approval. It creates the
-- loan account, contractual schedule, transaction, cash movement and journal
-- in one database transaction.
CREATE OR REPLACE FUNCTION bmt_db.teller_disburse_loan(
  p_loan_application_id UUID,
  p_idempotency_key TEXT
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_app bmt_db.loan_applications%ROWTYPE;
  v_customer bmt_db.customers%ROWTYPE;
  v_product bmt_db.loan_products%ROWTYPE;
  v_savings bmt_db.savings_accounts%ROWTYPE;
  v_savings_fa bmt_db.financial_accounts%ROWTYPE;
  v_session bmt_db.teller_cash_sessions%ROWTYPE;
  v_loan_account UUID;
  v_loan_number TEXT;
  v_seq TEXT;
  v_branch_code TEXT;
  v_tx UUID;
  v_journal UUID;
  v_period UUID;
  v_claim RECORD;
  v_margin NUMERIC;
  v_selling_price NUMERIC;
  v_principal_due NUMERIC;
  v_margin_due NUMERIC;
  v_tx_number TEXT;
  v_journal_number TEXT;
  v_i INTEGER;
  v_due DATE;
  v_principal_paid NUMERIC := 0;
  v_margin_paid NUMERIC := 0;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  IF NULLIF(btrim(p_idempotency_key), '') IS NULL THEN RAISE EXCEPTION 'Idempotency key is required'; END IF;
  IF NOT (bmt_db.current_user_is_superadmin() OR bmt_db.current_user_has_role('TELLER', NULL)) THEN RAISE EXCEPTION 'Teller access required'; END IF;

  SELECT * INTO v_claim FROM bmt_db.claim_financial_mutation('teller_disburse_loan', p_idempotency_key, p_loan_application_id::TEXT);
  IF NOT v_claim.is_new THEN
    IF v_claim.status = 'SUCCEEDED' THEN RETURN v_claim.result_id; END IF;
    RAISE EXCEPTION 'Request is already being processed or failed';
  END IF;

  SELECT * INTO v_app FROM bmt_db.loan_applications WHERE id = p_loan_application_id FOR UPDATE;
  IF NOT FOUND OR v_app.status <> 'APPROVED' THEN RAISE EXCEPTION 'Pengajuan belum disetujui manager'; END IF;
  IF EXISTS (SELECT 1 FROM bmt_db.loan_accounts WHERE application_id = v_app.id) THEN
    SELECT financial_account_id INTO v_loan_account FROM bmt_db.loan_accounts WHERE application_id = v_app.id;
    PERFORM bmt_db.complete_financial_mutation(v_claim.request_id, 'SUCCEEDED', v_loan_account, 200);
    RETURN v_loan_account;
  END IF;
  SELECT * INTO v_customer FROM bmt_db.customers WHERE id = v_app.customer_id;
  SELECT * INTO v_savings_fa FROM bmt_db.financial_accounts WHERE id = v_app.savings_account_id AND customer_id = v_app.customer_id FOR SHARE;
  SELECT * INTO v_savings FROM bmt_db.savings_accounts WHERE financial_account_id = v_app.savings_account_id FOR SHARE;
  IF NOT FOUND OR v_savings_fa.status <> 'ACTIVE' THEN RAISE EXCEPTION 'Rekening tabungan aktif tidak ditemukan'; END IF;
  SELECT * INTO v_session FROM bmt_db.teller_cash_sessions WHERE teller_user_id = v_user AND branch_id = v_app.branch_id AND business_date = CURRENT_DATE AND status = 'OPEN' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Sesi kas belum dibuka'; END IF;
  SELECT * INTO v_product FROM bmt_db.loan_products WHERE product_id = v_app.loan_product_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Produk pembiayaan tidak ditemukan'; END IF;

  v_margin := COALESCE(v_app.margin_amount_snapshot, round(v_app.requested_amount * COALESCE(v_product.rate, 0) / 100, 2));
  v_selling_price := COALESCE(v_app.selling_price_snapshot, v_app.requested_amount + v_margin);
  v_principal_due := floor(v_app.requested_amount / v_app.requested_tenor_months);
  v_margin_due := floor(v_margin / v_app.requested_tenor_months);
  SELECT code INTO v_branch_code FROM bmt_db.branches WHERE id = v_app.branch_id;
  v_seq := bmt_db.next_sequence(v_app.branch_id, 'LOAN_ACCOUNT', v_product.product_id::TEXT, '', CURRENT_DATE, 'NEVER', 8);
  v_loan_number := v_branch_code || '.' || v_seq;
  INSERT INTO bmt_db.financial_accounts(account_number, account_type, customer_id, branch_id, product_id, status, opened_at, opened_by, sequence_no)
  VALUES (v_loan_number, 'LOAN', v_customer.id, v_app.branch_id, v_app.loan_product_id, 'ACTIVE', now(), v_user, v_seq::BIGINT)
  RETURNING id INTO v_loan_account;
  INSERT INTO bmt_db.loan_accounts(financial_account_id, application_id, savings_account_id, principal_amount, tenor_months, rate, margin_amount, disbursement_amount, outstanding_principal, outstanding_margin, loan_status, disbursement_date, maturity_date)
  VALUES (v_loan_account, v_app.id, v_app.savings_account_id, v_app.requested_amount, v_app.requested_tenor_months, COALESCE(v_product.rate, 0), v_margin, v_app.requested_amount, v_app.requested_amount, v_margin, 'ACTIVE', CURRENT_DATE, CURRENT_DATE + (v_app.requested_tenor_months || ' months')::INTERVAL);

  FOR v_i IN 1..v_app.requested_tenor_months LOOP
    v_due := CURRENT_DATE + (v_i || ' months')::INTERVAL;
    INSERT INTO bmt_db.loan_schedules(loan_account_id, installment_no, due_date, opening_principal, principal_due, margin_due, other_due, total_due, status)
    VALUES (v_loan_account, v_i, v_due::DATE, v_app.requested_amount - v_principal_paid, CASE WHEN v_i = v_app.requested_tenor_months THEN v_app.requested_amount - v_principal_paid ELSE v_principal_due END, CASE WHEN v_i = v_app.requested_tenor_months THEN v_margin - v_margin_paid ELSE v_margin_due END, 0, CASE WHEN v_i = v_app.requested_tenor_months THEN (v_app.requested_amount - v_principal_paid) + (v_margin - v_margin_paid) ELSE v_principal_due + v_margin_due END, CASE WHEN v_i = 1 THEN 'DUE'::bmt_db.installment_status ELSE 'UPCOMING'::bmt_db.installment_status END);
    v_principal_paid := v_principal_paid + CASE WHEN v_i = v_app.requested_tenor_months THEN v_app.requested_amount - v_principal_paid ELSE v_principal_due END;
    v_margin_paid := v_margin_paid + CASE WHEN v_i = v_app.requested_tenor_months THEN v_margin - v_margin_paid ELSE v_margin_due END;
  END LOOP;

  v_tx_number := 'DIS-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS') || '-' || substr(replace(gen_random_uuid()::TEXT, '-', ''), 1, 8);
  INSERT INTO bmt_db.transactions(transaction_number, branch_id, transaction_type, customer_id, financial_account_id, amount, status, channel, description, created_by, teller_session_id)
  VALUES (v_tx_number, v_app.branch_id, 'LOAN_DISBURSEMENT', v_customer.id, v_app.savings_account_id, v_app.requested_amount, 'DRAFT', 'TELLER', 'Pencairan pembiayaan ' || v_app.application_number, v_user, v_session.id)
  RETURNING id INTO v_tx;
  INSERT INTO bmt_db.teller_cash_movements(cash_session_id, transaction_id, movement_type, amount, description, created_by)
  VALUES (v_session.id, v_tx, 'CASH_OUT', v_app.requested_amount, 'Pencairan pembiayaan ' || v_loan_number, v_user);
  INSERT INTO bmt_db.loan_ledger(loan_account_id, transaction_id, entry_date, value_date, component, entry_type, amount, balance_after, description)
  VALUES (v_loan_account, v_tx, CURRENT_DATE, CURRENT_DATE, 'PRINCIPAL', 'DEBIT', v_app.requested_amount, v_app.requested_amount, 'Pencairan pokok pembiayaan');
  v_period := bmt_db.require_open_fiscal_period(CURRENT_DATE);
  v_journal_number := 'JV-' || v_branch_code || '-' || to_char(CURRENT_DATE, 'YYYYMMDD') || '-' || bmt_db.next_sequence(v_app.branch_id, 'JOURNAL'::bmt_db.sequence_type, '', '', CURRENT_DATE, 'DAILY'::bmt_db.sequence_reset_policy, 6);
  INSERT INTO bmt_db.journal_entries(journal_number, transaction_id, branch_id, fiscal_period_id, journal_date, description, status, created_by)
  VALUES (v_journal_number, v_tx, v_app.branch_id, v_period, CURRENT_DATE, 'Pencairan pembiayaan ' || v_loan_number, 'DRAFT', v_user) RETURNING id INTO v_journal;
  INSERT INTO bmt_db.journal_lines(journal_entry_id, line_no, coa_id, customer_id, financial_account_id, debit, credit, description)
  VALUES (v_journal, 1, v_product.receivable_coa_id, v_customer.id, v_loan_account, v_app.requested_amount, 0, 'Piutang pembiayaan');
  SELECT id INTO v_period FROM bmt_db.chart_of_accounts WHERE code = '1.01.001';
  INSERT INTO bmt_db.journal_lines(journal_entry_id, line_no, coa_id, customer_id, financial_account_id, debit, credit, description)
  VALUES (v_journal, 2, v_period, v_customer.id, v_app.savings_account_id, 0, v_app.requested_amount, 'Kas teller keluar');
  PERFORM bmt_db.post_journal(v_journal, v_user);
  PERFORM bmt_db.mark_transaction_posted(v_tx, v_user);
  PERFORM bmt_db.complete_financial_mutation(v_claim.request_id, 'SUCCEEDED', v_loan_account, 201);
  RETURN v_loan_account;
EXCEPTION WHEN OTHERS THEN
  IF v_claim.request_id IS NOT NULL THEN PERFORM bmt_db.complete_financial_mutation(v_claim.request_id, 'FAILED', NULL, 400); END IF;
  RAISE;
END;
$$;

CREATE OR REPLACE FUNCTION bmt_db.teller_pay_loan_installment(
  p_loan_schedule_id UUID,
  p_amount NUMERIC,
  p_idempotency_key TEXT
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_schedule bmt_db.loan_schedules%ROWTYPE;
  v_loan bmt_db.loan_accounts%ROWTYPE;
  v_app bmt_db.loan_applications%ROWTYPE;
  v_customer bmt_db.customers%ROWTYPE;
  v_fa bmt_db.financial_accounts%ROWTYPE;
  v_session bmt_db.teller_cash_sessions%ROWTYPE;
  v_claim RECORD;
  v_tx UUID;
  v_journal UUID;
  v_period UUID;
  v_cash_coa UUID;
  v_receivable_coa UUID;
  v_margin_coa UUID;
  v_penalty_coa UUID;
  v_left NUMERIC := p_amount;
  v_principal NUMERIC := 0;
  v_margin NUMERIC := 0;
  v_penalty NUMERIC := 0;
  v_other NUMERIC := 0;
  v_remaining NUMERIC;
  v_tx_number TEXT;
  v_journal_number TEXT;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  IF p_amount IS NULL OR p_amount <= 0 OR NULLIF(btrim(p_idempotency_key), '') IS NULL THEN RAISE EXCEPTION 'Nominal dan idempotency key wajib diisi'; END IF;
  IF NOT (bmt_db.current_user_is_superadmin() OR bmt_db.current_user_has_role('TELLER', NULL)) THEN RAISE EXCEPTION 'Teller access required'; END IF;
  SELECT * INTO v_claim FROM bmt_db.claim_financial_mutation('teller_pay_loan_installment', p_idempotency_key, p_loan_schedule_id::TEXT || ':' || p_amount::TEXT);
  IF NOT v_claim.is_new THEN IF v_claim.status = 'SUCCEEDED' THEN RETURN v_claim.result_id; END IF; RAISE EXCEPTION 'Request is already being processed or failed'; END IF;
  SELECT * INTO v_schedule FROM bmt_db.loan_schedules WHERE id = p_loan_schedule_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Jadwal angsuran tidak ditemukan'; END IF;
  SELECT * INTO v_loan FROM bmt_db.loan_accounts WHERE financial_account_id = v_schedule.loan_account_id FOR UPDATE;
  SELECT * INTO v_app FROM bmt_db.loan_applications WHERE id = v_loan.application_id;
  SELECT * INTO v_customer FROM bmt_db.customers WHERE id = v_app.customer_id;
  SELECT * INTO v_fa FROM bmt_db.financial_accounts WHERE id = v_loan.savings_account_id;
  SELECT * INTO v_session FROM bmt_db.teller_cash_sessions WHERE teller_user_id = v_user AND branch_id = v_fa.branch_id AND business_date = CURRENT_DATE AND status = 'OPEN' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Sesi kas belum dibuka'; END IF;
  v_remaining := v_schedule.total_due - v_schedule.principal_paid - v_schedule.margin_paid - v_schedule.penalty_paid - v_schedule.other_paid;
  IF v_schedule.status = 'PAID' OR v_remaining <= 0 THEN RAISE EXCEPTION 'Angsuran sudah lunas'; END IF;
  IF p_amount > v_remaining THEN RAISE EXCEPTION 'Pembayaran melebihi sisa angsuran'; END IF;
  v_principal := LEAST(v_left, v_schedule.principal_due - v_schedule.principal_paid); v_left := v_left - v_principal;
  v_margin := LEAST(v_left, v_schedule.margin_due - v_schedule.margin_paid); v_left := v_left - v_margin;
  v_penalty := 0; v_left := v_left - v_penalty;
  v_other := v_left;
  v_tx_number := 'PAY-TELLER-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS') || '-' || substr(replace(gen_random_uuid()::TEXT, '-', ''), 1, 8);
  INSERT INTO bmt_db.transactions(transaction_number, branch_id, transaction_type, customer_id, financial_account_id, amount, status, channel, description, created_by, teller_session_id)
  VALUES (v_tx_number, v_fa.branch_id, 'INSTALLMENT_PAYMENT', v_customer.id, v_loan.savings_account_id, p_amount, 'DRAFT', 'TELLER', 'Pembayaran angsuran ' || v_fa.account_number, v_user, v_session.id) RETURNING id INTO v_tx;
  INSERT INTO bmt_db.teller_cash_movements(cash_session_id, transaction_id, movement_type, amount, description, created_by)
  VALUES (v_session.id, v_tx, 'CASH_IN', p_amount, 'Pembayaran angsuran ' || v_fa.account_number, v_user);
  INSERT INTO bmt_db.installment_payments(loan_schedule_id, transaction_id, principal_amount, margin_amount, penalty_amount, other_amount, created_by)
  VALUES (p_loan_schedule_id, v_tx, v_principal, v_margin, v_penalty, v_other, v_user);
  UPDATE bmt_db.loan_schedules SET principal_paid = principal_paid + v_principal, margin_paid = margin_paid + v_margin, penalty_paid = penalty_paid + v_penalty, other_paid = other_paid + v_other, paid_at = CASE WHEN p_amount = v_remaining THEN now() ELSE paid_at END, status = CASE WHEN p_amount = v_remaining THEN 'PAID'::bmt_db.installment_status ELSE 'PARTIAL'::bmt_db.installment_status END, days_overdue = GREATEST(CURRENT_DATE - due_date, 0), updated_at = now() WHERE id = p_loan_schedule_id;
  UPDATE bmt_db.loan_accounts SET outstanding_principal = GREATEST(outstanding_principal - v_principal, 0), outstanding_margin = GREATEST(outstanding_margin - v_margin, 0), outstanding_penalty = GREATEST(outstanding_penalty - v_penalty, 0), loan_status = CASE WHEN outstanding_principal - v_principal <= 0 AND outstanding_margin - v_margin <= 0 THEN 'PAID_OFF'::bmt_db.loan_account_status WHEN CURRENT_DATE > v_schedule.due_date AND p_amount < v_remaining THEN 'PAST_DUE'::bmt_db.loan_account_status ELSE loan_status END, updated_at = now() WHERE financial_account_id = v_loan.financial_account_id;
  INSERT INTO bmt_db.loan_ledger(loan_account_id, transaction_id, entry_date, value_date, component, entry_type, amount, balance_after, description) VALUES (v_loan.financial_account_id, v_tx, CURRENT_DATE, CURRENT_DATE, 'PRINCIPAL', 'CREDIT', v_principal, GREATEST(v_schedule.opening_principal - v_schedule.principal_paid - v_principal, 0), 'Pembayaran pokok');
  IF v_margin > 0 THEN INSERT INTO bmt_db.loan_ledger(loan_account_id, transaction_id, entry_date, value_date, component, entry_type, amount, balance_after, description) VALUES (v_loan.financial_account_id, v_tx, CURRENT_DATE, CURRENT_DATE, 'MARGIN', 'CREDIT', v_margin, v_margin, 'Pembayaran margin'); END IF;
  SELECT id INTO v_cash_coa FROM bmt_db.chart_of_accounts WHERE code = '1.01.001';
  SELECT lp.receivable_coa_id, lp.margin_income_coa_id, lp.penalty_income_coa_id INTO v_receivable_coa, v_margin_coa, v_penalty_coa FROM bmt_db.loan_products lp WHERE lp.product_id = v_app.loan_product_id;
  IF v_cash_coa IS NULL OR v_receivable_coa IS NULL THEN RAISE EXCEPTION 'Accounting mappings are incomplete'; END IF;
  v_period := bmt_db.require_open_fiscal_period(CURRENT_DATE);
  v_journal_number := 'JV-PAY-' || to_char(CURRENT_DATE, 'YYYYMMDDHH24MISSMS') || '-' || substr(replace(gen_random_uuid()::TEXT, '-', ''), 1, 6);
  INSERT INTO bmt_db.journal_entries(journal_number, transaction_id, branch_id, fiscal_period_id, journal_date, description, status, created_by) VALUES (v_journal_number, v_tx, v_fa.branch_id, v_period, CURRENT_DATE, 'Pembayaran angsuran ' || v_fa.account_number, 'DRAFT', v_user) RETURNING id INTO v_journal;
  INSERT INTO bmt_db.journal_lines(journal_entry_id, line_no, coa_id, customer_id, financial_account_id, debit, credit, description) VALUES (v_journal, 1, v_cash_coa, v_customer.id, v_loan.savings_account_id, p_amount, 0, 'Kas teller masuk');
  IF v_principal > 0 THEN INSERT INTO bmt_db.journal_lines(journal_entry_id, line_no, coa_id, customer_id, financial_account_id, debit, credit, description) VALUES (v_journal, 2, v_receivable_coa, v_customer.id, v_loan.financial_account_id, 0, v_principal, 'Pelunasan pokok'); END IF;
  IF v_margin > 0 THEN INSERT INTO bmt_db.journal_lines(journal_entry_id, line_no, coa_id, customer_id, financial_account_id, debit, credit, description) VALUES (v_journal, 3, v_margin_coa, v_customer.id, v_loan.financial_account_id, 0, v_margin, 'Pendapatan margin'); END IF;
  IF v_penalty > 0 THEN IF v_penalty_coa IS NULL THEN RAISE EXCEPTION 'Penalty accounting mapping is incomplete'; END IF; INSERT INTO bmt_db.journal_lines(journal_entry_id, line_no, coa_id, customer_id, financial_account_id, debit, credit, description) VALUES (v_journal, 4, v_penalty_coa, v_customer.id, v_loan.financial_account_id, 0, v_penalty, 'Pendapatan denda'); END IF;
  IF v_other > 0 THEN RAISE EXCEPTION 'Komponen pembayaran lain belum dikonfigurasi'; END IF;
  PERFORM bmt_db.post_journal(v_journal, v_user); PERFORM bmt_db.mark_transaction_posted(v_tx, v_user);
  PERFORM bmt_db.complete_financial_mutation(v_claim.request_id, 'SUCCEEDED', v_tx, 201);
  RETURN v_tx;
EXCEPTION WHEN OTHERS THEN
  IF v_claim.request_id IS NOT NULL THEN PERFORM bmt_db.complete_financial_mutation(v_claim.request_id, 'FAILED', NULL, 400); END IF;
  RAISE;
END;
$$;

-- Refresh payment quality from schedules. This is safe to run repeatedly.
CREATE OR REPLACE FUNCTION bmt_db.refresh_loan_quality()
RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_count INTEGER;
BEGIN
  UPDATE bmt_db.loan_schedules
     SET days_overdue = CASE WHEN status = 'PAID' THEN 0 ELSE GREATEST(CURRENT_DATE - due_date, 0) END,
         status = CASE WHEN status = 'PAID' THEN status WHEN CURRENT_DATE > due_date AND principal_paid + margin_paid + penalty_paid + other_paid < total_due THEN 'OVERDUE'::bmt_db.installment_status WHEN principal_paid + margin_paid + penalty_paid + other_paid > 0 THEN 'PARTIAL'::bmt_db.installment_status WHEN CURRENT_DATE >= due_date THEN 'DUE'::bmt_db.installment_status ELSE 'UPCOMING'::bmt_db.installment_status END,
         updated_at = now()
   WHERE status <> 'PAID';
  GET DIAGNOSTICS v_count = ROW_COUNT;
  UPDATE bmt_db.loan_accounts la SET loan_status = CASE WHEN la.outstanding_principal <= 0 AND la.outstanding_margin <= 0 THEN 'PAID_OFF'::bmt_db.loan_account_status WHEN EXISTS (SELECT 1 FROM bmt_db.loan_schedules ls WHERE ls.loan_account_id = la.financial_account_id AND ls.status = 'OVERDUE') THEN 'PAST_DUE'::bmt_db.loan_account_status ELSE 'ACTIVE'::bmt_db.loan_account_status END, updated_at = now() WHERE la.loan_status NOT IN ('CLOSED','WRITTEN_OFF');
  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION bmt_db.teller_disburse_loan(UUID,TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.teller_disburse_loan(UUID,TEXT) TO authenticated;
REVOKE ALL ON FUNCTION bmt_db.teller_pay_loan_installment(UUID,NUMERIC,TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.teller_pay_loan_installment(UUID,NUMERIC,TEXT) TO authenticated;
REVOKE ALL ON FUNCTION bmt_db.refresh_loan_quality() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.refresh_loan_quality() TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
