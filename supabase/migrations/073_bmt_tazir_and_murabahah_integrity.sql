BEGIN;

ALTER TABLE bmt_db.loan_products
  ADD COLUMN IF NOT EXISTS penalty_frequency TEXT NOT NULL DEFAULT 'DAILY';
ALTER TABLE bmt_db.loan_products
  DROP CONSTRAINT IF EXISTS ck_loan_products_penalty_frequency;
ALTER TABLE bmt_db.loan_products
  ADD CONSTRAINT ck_loan_products_penalty_frequency
  CHECK (penalty_frequency IN ('DAILY','MONTHLY'));

ALTER TABLE bmt_db.loan_accounts
  ADD COLUMN IF NOT EXISTS ta_z_ir_exempt BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS ta_z_ir_exemption_reason TEXT;
ALTER TABLE bmt_db.loan_accounts
  DROP CONSTRAINT IF EXISTS ck_loan_accounts_ta_z_ir_exemption;
ALTER TABLE bmt_db.loan_accounts
  ADD CONSTRAINT ck_loan_accounts_ta_z_ir_exemption
  CHECK (NOT ta_z_ir_exempt OR NULLIF(btrim(ta_z_ir_exemption_reason), '') IS NOT NULL);

-- Contract-substance fields. They remain nullable while an application is in
-- simulation/review, but must reconcile once a murabahah contract is approved.
ALTER TABLE bmt_db.loan_applications
  ADD COLUMN IF NOT EXISTS cost_price bmt_db.money_amount,
  ADD COLUMN IF NOT EXISTS margin_amount bmt_db.money_amount,
  ADD COLUMN IF NOT EXISTS selling_price bmt_db.money_amount,
  ADD COLUMN IF NOT EXISTS supplier_info JSONB,
  ADD COLUMN IF NOT EXISTS wakalah_agreement_id UUID;
ALTER TABLE bmt_db.loan_accounts
  ADD COLUMN IF NOT EXISTS cost_price bmt_db.money_amount,
  ADD COLUMN IF NOT EXISTS selling_price bmt_db.money_amount,
  ADD COLUMN IF NOT EXISTS supplier_info JSONB,
  ADD COLUMN IF NOT EXISTS wakalah_agreement_id UUID;
ALTER TABLE bmt_db.loan_applications
  DROP CONSTRAINT IF EXISTS ck_loan_applications_murabahah_values;
ALTER TABLE bmt_db.loan_applications
  ADD CONSTRAINT ck_loan_applications_murabahah_values CHECK (
    cost_price IS NULL OR (cost_price > 0 AND margin_amount IS NOT NULL AND margin_amount >= 0
      AND selling_price = cost_price + margin_amount)
  );
ALTER TABLE bmt_db.loan_accounts
  DROP CONSTRAINT IF EXISTS ck_loan_accounts_murabahah_values;
ALTER TABLE bmt_db.loan_accounts
  ADD CONSTRAINT ck_loan_accounts_murabahah_values CHECK (
    cost_price IS NULL OR (cost_price > 0 AND margin_amount >= 0
      AND selling_price = cost_price + margin_amount)
  );

-- Liability account: ta'zir is held for social benefit and is never P&L income.
INSERT INTO bmt_db.chart_of_accounts(code, name, account_type, normal_balance, level, allow_posting, is_active, description)
SELECT '2.04.001', 'Titipan Dana Kebajikan Ta''zir', 'LIABILITY', 'CREDIT', 3, TRUE, TRUE,
       'Kewajiban sosial untuk dana ta''zir/qardhul hasan; bukan pendapatan BMT.'
WHERE NOT EXISTS (SELECT 1 FROM bmt_db.chart_of_accounts WHERE code = '2.04.001');

CREATE OR REPLACE FUNCTION bmt_db.calculate_ta_z_ir_penalty(
  p_loan_schedule_id UUID,
  p_as_of_date DATE DEFAULT CURRENT_DATE
) RETURNS NUMERIC
LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT CASE
    WHEN la.ta_z_ir_exempt
      OR ls.status <> 'OVERDUE'
      OR lp.penalty_rate <= 0
      OR GREATEST(p_as_of_date - ls.due_date, 0) <= lp.grace_period_days
    THEN 0::NUMERIC
    WHEN lp.penalty_frequency = 'MONTHLY'
    THEN ROUND(
      (ls.principal_due + ls.margin_due)
      * lp.penalty_rate / 100
      * CEIL((GREATEST(p_as_of_date - ls.due_date, 0) - lp.grace_period_days)::NUMERIC / 30), 2)
    ELSE ROUND(
      (ls.principal_due + ls.margin_due)
      * lp.penalty_rate / 100
      * (GREATEST(p_as_of_date - ls.due_date, 0) - lp.grace_period_days) / 30, 2)
  END
  FROM bmt_db.loan_schedules ls
  JOIN bmt_db.loan_accounts la ON la.financial_account_id = ls.loan_account_id
  JOIN bmt_db.loan_applications app ON app.id = la.application_id
  JOIN bmt_db.loan_products lp ON lp.product_id = app.loan_product_id
  WHERE ls.id = p_loan_schedule_id;
$$;

CREATE OR REPLACE FUNCTION bmt_db.teller_pay_loan_installment(
  p_loan_schedule_id UUID, p_amount NUMERIC, p_idempotency_key TEXT
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_user UUID := auth.uid(); v_schedule bmt_db.loan_schedules%ROWTYPE;
  v_loan bmt_db.loan_accounts%ROWTYPE; v_app bmt_db.loan_applications%ROWTYPE;
  v_customer bmt_db.customers%ROWTYPE; v_fa bmt_db.financial_accounts%ROWTYPE;
  v_session bmt_db.teller_cash_sessions%ROWTYPE; v_claim RECORD;
  v_tx UUID; v_journal UUID; v_period UUID; v_cash_coa UUID; v_receivable_coa UUID;
  v_margin_coa UUID; v_tazir_coa UUID; v_left NUMERIC := p_amount;
  v_principal NUMERIC := 0; v_margin NUMERIC := 0; v_penalty_due NUMERIC := 0;
  v_penalty NUMERIC := 0; v_other NUMERIC := 0; v_remaining NUMERIC;
  v_tx_number TEXT; v_journal_number TEXT;
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
  IF p_amount > v_remaining + bmt_db.calculate_ta_z_ir_penalty(p_loan_schedule_id) THEN RAISE EXCEPTION 'Pembayaran melebihi sisa angsuran'; END IF;
  v_principal := LEAST(v_left, v_schedule.principal_due - v_schedule.principal_paid); v_left := v_left - v_principal;
  v_margin := LEAST(v_left, v_schedule.margin_due - v_schedule.margin_paid); v_left := v_left - v_margin;
  v_penalty_due := GREATEST(bmt_db.calculate_ta_z_ir_penalty(p_loan_schedule_id) - v_schedule.penalty_paid, 0);
  v_penalty := LEAST(v_left, v_penalty_due); v_left := v_left - v_penalty;
  v_other := v_left;
  IF v_other > 0 THEN RAISE EXCEPTION 'Komponen pembayaran lain belum dikonfigurasi'; END IF;
  v_tx_number := 'PAY-TELLER-' || to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS') || '-' || substr(replace(gen_random_uuid()::TEXT,'-',''),1,8);
  INSERT INTO bmt_db.transactions(transaction_number,branch_id,transaction_type,customer_id,financial_account_id,amount,status,channel,description,created_by,teller_session_id)
  VALUES(v_tx_number,v_fa.branch_id,'INSTALLMENT_PAYMENT',v_customer.id,v_loan.savings_account_id,p_amount,'DRAFT','TELLER','Pembayaran angsuran '||v_fa.account_number,v_user,v_session.id) RETURNING id INTO v_tx;
  INSERT INTO bmt_db.teller_cash_movements(cash_session_id,transaction_id,movement_type,amount,description,created_by) VALUES(v_session.id,v_tx,'CASH_IN',p_amount,'Pembayaran angsuran '||v_fa.account_number,v_user);
  INSERT INTO bmt_db.installment_payments(loan_schedule_id,transaction_id,principal_amount,margin_amount,penalty_amount,other_amount,created_by) VALUES(p_loan_schedule_id,v_tx,v_principal,v_margin,v_penalty,v_other,v_user);
  UPDATE bmt_db.loan_schedules SET principal_paid=principal_paid+v_principal,margin_paid=margin_paid+v_margin,penalty_paid=penalty_paid+v_penalty,other_paid=other_paid+v_other,paid_at=CASE WHEN p_amount >= v_remaining THEN now() ELSE paid_at END,status=CASE WHEN p_amount >= v_remaining THEN 'PAID'::bmt_db.installment_status ELSE 'PARTIAL'::bmt_db.installment_status END,days_overdue=GREATEST(CURRENT_DATE-due_date,0),updated_at=now() WHERE id=p_loan_schedule_id;
  UPDATE bmt_db.loan_accounts SET outstanding_principal=GREATEST(outstanding_principal-v_principal,0),outstanding_margin=GREATEST(outstanding_margin-v_margin,0),outstanding_penalty=GREATEST(outstanding_penalty-v_penalty,0),loan_status=CASE WHEN outstanding_principal-v_principal<=0 AND outstanding_margin-v_margin<=0 THEN 'PAID_OFF'::bmt_db.loan_account_status WHEN CURRENT_DATE>v_schedule.due_date AND p_amount<v_remaining THEN 'PAST_DUE'::bmt_db.loan_account_status ELSE loan_status END,updated_at=now() WHERE financial_account_id=v_loan.financial_account_id;
  INSERT INTO bmt_db.loan_ledger(loan_account_id,transaction_id,entry_date,value_date,component,entry_type,amount,balance_after,description) VALUES(v_loan.financial_account_id,v_tx,CURRENT_DATE,CURRENT_DATE,'PRINCIPAL','CREDIT',v_principal,GREATEST(v_schedule.opening_principal-v_schedule.principal_paid-v_principal,0),'Bet pokok');
  IF v_margin > 0 THEN INSERT INTO bmt_db.loan_ledger(loan_account_id,transaction_id,entry_date,value_date,component,entry_type,amount,balance_after,description) VALUES(v_loan.financial_account_id,v_tx,CURRENT_DATE,CURRENT_DATE,'MARGIN','CREDIT',v_margin,v_margin,'Pembayaran margin'); END IF;
  SELECT id INTO v_cash_coa FROM bmt_db.chart_of_accounts WHERE code='1.01.001';
  SELECT lp.receivable_coa_id,lp.margin_income_coa_id INTO v_receivable_coa,v_margin_coa FROM bmt_db.loan_products lp WHERE lp.product_id=v_app.loan_product_id;
  SELECT id INTO v_tazir_coa FROM bmt_db.chart_of_accounts WHERE code='2.04.001' AND account_type='LIABILITY' AND allow_posting;
  IF v_cash_coa IS NULL OR v_receivable_coa IS NULL OR (v_penalty > 0 AND v_tazir_coa IS NULL) THEN RAISE EXCEPTION 'Accounting mappings are incomplete'; END IF;
  v_period := bmt_db.require_open_fiscal_period(CURRENT_DATE);
  v_journal_number := 'JV-PAY-'||to_char(CURRENT_DATE,'YYYYMMDDHH24MISSMS')||'-'||substr(replace(gen_random_uuid()::TEXT,'-',''),1,6);
  INSERT INTO bmt_db.journal_entries(journal_number,transaction_id,branch_id,fiscal_period_id,journal_date,description,status,created_by) VALUES(v_journal_number,v_tx,v_fa.branch_id,v_period,CURRENT_DATE,'Pembayaran angsuran '||v_fa.account_number,'DRAFT',v_user) RETURNING id INTO v_journal;
  INSERT INTO bmt_db.journal_lines(journal_entry_id,line_no,coa_id,customer_id,financial_account_id,debit,credit,description) VALUES(v_journal,1,v_cash_coa,v_customer.id,v_loan.savings_account_id,p_amount,0,'Kas teller masuk');
  IF v_principal > 0 THEN INSERT INTO bmt_db.journal_lines(journal_entry_id,line_no,coa_id,customer_id,financial_account_id,debit,credit,description) VALUES(v_journal,2,v_receivable_coa,v_customer.id,v_loan.financial_account_id,0,v_principal,'Pelunasan pokok'); END IF;
  IF v_margin > 0 THEN INSERT INTO bmt_db.journal_lines(journal_entry_id,line_no,coa_id,customer_id,financial_account_id,debit,credit,description) VALUES(v_journal,3,v_margin_coa,v_customer.id,v_loan.financial_account_id,0,v_margin,'Pendapatan margin'); END IF;
  IF v_penalty > 0 THEN INSERT INTO bmt_db.journal_lines(journal_entry_id,line_no,coa_id,customer_id,financial_account_id,debit,credit,description) VALUES(v_journal,4,v_tazir_coa,v_customer.id,v_loan.financial_account_id,0,v_penalty,'Titipan Dana Kebajikan Ta''zir'); END IF;
  PERFORM bmt_db.post_journal(v_journal,v_user); PERFORM bmt_db.mark_transaction_posted(v_tx,v_user); PERFORM bmt_db.complete_financial_mutation(v_claim.request_id,'SUCCEEDED',v_tx,201); RETURN v_tx;
EXCEPTION WHEN OTHERS THEN IF v_claim.request_id IS NOT NULL THEN PERFORM bmt_db.complete_financial_mutation(v_claim.request_id,'FAILED',NULL,400); END IF; RAISE;
END; $$;

REVOKE ALL ON FUNCTION bmt_db.calculate_ta_z_ir_penalty(UUID,DATE) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.calculate_ta_z_ir_penalty(UUID,DATE) TO authenticated;
REVOKE ALL ON FUNCTION bmt_db.teller_pay_loan_installment(UUID,NUMERIC,TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.teller_pay_loan_installment(UUID,NUMERIC,TEXT) TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
