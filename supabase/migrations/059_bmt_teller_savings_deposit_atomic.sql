BEGIN;

DROP FUNCTION IF EXISTS bmt_db.teller_post_savings_deposit(UUID, NUMERIC, TEXT, TEXT, TEXT);

ALTER TABLE bmt_db.transactions
  ADD COLUMN IF NOT EXISTS idempotency_key UUID;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_transactions_idempotency_key') THEN
    ALTER TABLE bmt_db.transactions ADD CONSTRAINT uq_transactions_idempotency_key UNIQUE (idempotency_key);
  END IF;
END $$;

CREATE OR REPLACE FUNCTION bmt_db.teller_post_savings_deposit(
  p_financial_account_id UUID,
  p_amount NUMERIC,
  p_channel TEXT DEFAULT 'CASH',
  p_reference_number TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL,
  p_idempotency_key UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_user UUID := auth.uid();
  v_account bmt_db.financial_accounts%ROWTYPE;
  v_savings bmt_db.savings_accounts%ROWTYPE;
  v_customer bmt_db.customers%ROWTYPE;
  v_session bmt_db.teller_cash_sessions%ROWTYPE;
  v_tx UUID;
  v_balance NUMERIC;
  v_channel bmt_db.transaction_channel;
  v_cash_movement bmt_db.cash_movement_type;
  v_liability_coa UUID;
  v_cash_coa UUID;
  v_period UUID;
  v_journal UUID;
  v_branch_code TEXT;
  v_tx_number TEXT;
  v_journal_number TEXT;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  IF p_idempotency_key IS NULL THEN RAISE EXCEPTION 'Idempotency key is required'; END IF;
  IF NOT (bmt_db.current_user_is_superadmin() OR bmt_db.current_user_has_role('TELLER', NULL)) THEN RAISE EXCEPTION 'Teller access required'; END IF;
  IF p_amount IS NULL OR p_amount <= 0 THEN RAISE EXCEPTION 'Nominal setoran harus lebih besar dari 0'; END IF;
  IF upper(COALESCE(p_channel, 'CASH')) <> 'CASH' THEN RAISE EXCEPTION 'Saat ini setoran teller hanya mendukung tunai'; END IF;

  PERFORM pg_advisory_xact_lock(hashtext(p_idempotency_key::TEXT));
  SELECT id INTO v_tx FROM bmt_db.transactions WHERE idempotency_key = p_idempotency_key FOR SHARE;
  IF FOUND THEN RETURN v_tx; END IF;

  SELECT * INTO v_account FROM bmt_db.financial_accounts WHERE id = p_financial_account_id AND account_type = 'SAVINGS' AND status = 'ACTIVE' FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Rekening tabungan aktif tidak ditemukan'; END IF;
  SELECT * INTO v_customer FROM bmt_db.customers WHERE id = v_account.customer_id;
  SELECT * INTO v_savings FROM bmt_db.savings_accounts WHERE financial_account_id = p_financial_account_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Data tabungan tidak ditemukan'; END IF;
  SELECT * INTO v_session FROM bmt_db.teller_cash_sessions WHERE teller_user_id = v_user AND branch_id = v_account.branch_id AND status = 'OPEN' FOR UPDATE;
  IF NOT FOUND OR v_session.business_date <> CURRENT_DATE THEN RAISE EXCEPTION 'Sesi kas belum dibuka'; END IF;

  SELECT sp.liability_coa_id INTO v_liability_coa FROM bmt_db.savings_products sp WHERE sp.product_id = v_account.product_id;
  SELECT id INTO v_cash_coa FROM bmt_db.chart_of_accounts WHERE code = '1.01.001' AND is_active AND allow_posting;
  IF v_liability_coa IS NULL OR v_cash_coa IS NULL THEN RAISE EXCEPTION 'Mapping COA kas atau tabungan belum lengkap'; END IF;

  v_balance := v_savings.current_balance + p_amount;
  v_channel := 'TELLER';
  v_cash_movement := 'CASH_IN';
  v_tx_number := 'DEP-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS') || '-' || substr(replace(gen_random_uuid()::TEXT, '-', ''), 1, 8);
  INSERT INTO bmt_db.transactions(transaction_number, branch_id, transaction_type, customer_id, financial_account_id, amount, status, channel, description, reference_number, created_by, teller_session_id, idempotency_key)
  VALUES (v_tx_number, v_account.branch_id, 'SAVINGS_DEPOSIT', v_customer.id, p_financial_account_id, p_amount, 'DRAFT', v_channel, COALESCE(NULLIF(btrim(p_description), ''), 'Setoran tabungan'), NULLIF(btrim(p_reference_number), ''), v_user, v_session.id, p_idempotency_key)
  RETURNING id INTO v_tx;

  UPDATE bmt_db.savings_accounts SET current_balance = v_balance, available_balance = available_balance + p_amount, last_transaction_at = now(), updated_at = now() WHERE financial_account_id = p_financial_account_id;
  INSERT INTO bmt_db.savings_ledger(account_id, transaction_id, entry_date, value_date, entry_type, amount, balance_after, description)
  VALUES (p_financial_account_id, v_tx, CURRENT_DATE, CURRENT_DATE, 'CREDIT', p_amount, v_balance, COALESCE(NULLIF(btrim(p_description), ''), 'Setoran tabungan'));
  INSERT INTO bmt_db.teller_cash_movements(cash_session_id, transaction_id, movement_type, amount, description, created_by)
  VALUES (v_session.id, v_tx, v_cash_movement, p_amount, 'Setoran tabungan ' || v_account.account_number, v_user);

  SELECT code INTO v_branch_code FROM bmt_db.branches WHERE id = v_account.branch_id;
  v_period := bmt_db.require_open_fiscal_period(CURRENT_DATE);
  v_journal_number := 'JV-' || v_branch_code || '-' || to_char(CURRENT_DATE, 'YYYYMMDD') || '-' || substr(replace(gen_random_uuid()::TEXT, '-', ''), 1, 8);
  INSERT INTO bmt_db.journal_entries(journal_number, transaction_id, branch_id, fiscal_period_id, journal_date, description, status, created_by)
  VALUES (v_journal_number, v_tx, v_account.branch_id, v_period, CURRENT_DATE, 'Setoran tabungan ' || v_account.account_number, 'DRAFT', v_user)
  RETURNING id INTO v_journal;
  INSERT INTO bmt_db.journal_lines(journal_entry_id, line_no, coa_id, customer_id, financial_account_id, debit, credit, description)
  VALUES (v_journal, 1, v_cash_coa, v_customer.id, p_financial_account_id, p_amount, 0, 'Kas teller bertambah');
  INSERT INTO bmt_db.journal_lines(journal_entry_id, line_no, coa_id, customer_id, financial_account_id, debit, credit, description)
  VALUES (v_journal, 2, v_liability_coa, v_customer.id, p_financial_account_id, 0, p_amount, 'Kewajiban tabungan nasabah bertambah');

  PERFORM bmt_db.post_journal(v_journal, v_user);
  PERFORM bmt_db.mark_transaction_posted(v_tx, v_user);
  INSERT INTO bmt_db.transaction_receipts(transaction_id, receipt_number) VALUES (v_tx, 'RCPT-' || replace(v_tx_number, 'DEP-', ''));
  INSERT INTO bmt_db.audit_logs(user_id, branch_id, action, entity_type, entity_id, transaction_id, metadata)
  VALUES (v_user, v_account.branch_id, 'SAVINGS_DEPOSIT_POSTED', 'SAVINGS_ACCOUNT', p_financial_account_id, v_tx, jsonb_build_object('amount', p_amount, 'idempotency_key', p_idempotency_key));
  RETURN v_tx;
EXCEPTION WHEN OTHERS THEN
  RAISE;
END;
$$;

REVOKE ALL ON FUNCTION bmt_db.teller_post_savings_deposit(UUID, NUMERIC, TEXT, TEXT, TEXT, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.teller_post_savings_deposit(UUID, NUMERIC, TEXT, TEXT, TEXT, UUID) TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
