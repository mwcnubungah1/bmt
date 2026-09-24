BEGIN;

CREATE OR REPLACE FUNCTION bmt_db.teller_search_savings_accounts(p_search TEXT DEFAULT '')
RETURNS TABLE(financial_account_id UUID, account_number TEXT, customer_id UUID, cif_number TEXT, full_name TEXT, current_balance NUMERIC, branch_id UUID)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT (bmt_db.current_user_is_superadmin() OR bmt_db.current_user_has_role('TELLER', NULL)) THEN
    RAISE EXCEPTION 'Teller access required';
  END IF;
  RETURN QUERY
  SELECT fa.id, fa.account_number::TEXT, c.id, c.cif_number::TEXT, c.full_name::TEXT, sa.current_balance, fa.branch_id
  FROM bmt_db.financial_accounts fa
  JOIN bmt_db.customers c ON c.id = fa.customer_id
  JOIN bmt_db.savings_accounts sa ON sa.financial_account_id = fa.id
  WHERE fa.account_type = 'SAVINGS' AND fa.status = 'ACTIVE'
    AND (NULLIF(btrim(p_search), '') IS NULL OR c.full_name ILIKE '%' || btrim(p_search) || '%' OR c.cif_number ILIKE '%' || btrim(p_search) || '%' OR fa.account_number ILIKE '%' || btrim(p_search) || '%')
  ORDER BY c.full_name, fa.account_number LIMIT 25;
END; $$;

CREATE OR REPLACE FUNCTION bmt_db.teller_post_savings_deposit(p_financial_account_id UUID, p_amount NUMERIC, p_channel TEXT DEFAULT 'CASH', p_reference_number TEXT DEFAULT NULL, p_description TEXT DEFAULT NULL)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_user UUID := auth.uid(); v_account bmt_db.financial_accounts%ROWTYPE; v_savings bmt_db.savings_accounts%ROWTYPE; v_customer bmt_db.customers%ROWTYPE; v_session bmt_db.teller_cash_sessions%ROWTYPE; v_tx UUID; v_balance NUMERIC; v_channel bmt_db.transaction_channel; v_movement bmt_db.cash_movement_type;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  IF NOT (bmt_db.current_user_is_superadmin() OR bmt_db.current_user_has_role('TELLER', NULL)) THEN RAISE EXCEPTION 'Teller access required'; END IF;
  IF p_amount IS NULL OR p_amount <= 0 THEN RAISE EXCEPTION 'Nominal setoran harus lebih besar dari 0'; END IF;
  IF upper(COALESCE(p_channel, 'CASH')) NOT IN ('CASH', 'TRANSFER') THEN RAISE EXCEPTION 'Metode setoran tidak valid'; END IF;
  SELECT * INTO v_account FROM bmt_db.financial_accounts WHERE id = p_financial_account_id AND account_type = 'SAVINGS' AND status = 'ACTIVE' FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Rekening tabungan aktif tidak ditemukan'; END IF;
  SELECT * INTO v_customer FROM bmt_db.customers WHERE id = v_account.customer_id;
  SELECT * INTO v_savings FROM bmt_db.savings_accounts WHERE financial_account_id = p_financial_account_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Data tabungan tidak ditemukan'; END IF;
  IF upper(COALESCE(p_channel, 'CASH')) = 'CASH' THEN
    SELECT * INTO v_session FROM bmt_db.teller_cash_sessions WHERE teller_user_id = v_user AND branch_id = v_account.branch_id AND status = 'OPEN' FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Buka sesi kas teller terlebih dahulu'; END IF;
    v_channel := 'TELLER'; v_movement := 'CASH_IN';
  ELSE
    v_channel := 'ONLINE';
  END IF;
  v_balance := v_savings.current_balance + p_amount;
  INSERT INTO bmt_db.transactions(transaction_number, branch_id, transaction_type, customer_id, financial_account_id, amount, status, channel, description, reference_number, created_by, approved_by, approved_at, posted_by, posted_at, teller_session_id)
  VALUES ('DEP-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS') || '-' || substr(replace(gen_random_uuid()::TEXT, '-', ''), 1, 8), v_account.branch_id, 'SAVINGS_DEPOSIT', v_customer.id, p_financial_account_id, p_amount, 'POSTED', v_channel, COALESCE(NULLIF(btrim(p_description), ''), 'Setoran tabungan'), NULLIF(btrim(p_reference_number), ''), v_user, v_user, now(), v_user, now(), CASE WHEN v_session.id IS NULL THEN NULL ELSE v_session.id END)
  RETURNING id INTO v_tx;
  UPDATE bmt_db.savings_accounts SET current_balance = v_balance, available_balance = available_balance + p_amount, last_transaction_at = now(), updated_at = now() WHERE financial_account_id = p_financial_account_id;
  INSERT INTO bmt_db.savings_ledger(account_id, transaction_id, entry_date, value_date, entry_type, amount, balance_after, description) VALUES (p_financial_account_id, v_tx, CURRENT_DATE, CURRENT_DATE, 'CREDIT', p_amount, v_balance, COALESCE(NULLIF(btrim(p_description), ''), 'Setoran tabungan'));
  IF v_session.id IS NOT NULL THEN
    INSERT INTO bmt_db.teller_cash_movements(cash_session_id, transaction_id, movement_type, amount, description, created_by) VALUES (v_session.id, v_tx, v_movement, p_amount, 'Setoran tabungan ' || v_account.account_number, v_user);
  END IF;
  INSERT INTO bmt_db.transaction_receipts(transaction_id, receipt_number) VALUES (v_tx, 'RCPT-' || replace(v_tx::TEXT, '-', ''));
  RETURN v_tx;
END; $$;

REVOKE ALL ON FUNCTION bmt_db.teller_search_savings_accounts(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.teller_search_savings_accounts(TEXT) TO authenticated;
REVOKE ALL ON FUNCTION bmt_db.teller_post_savings_deposit(UUID, NUMERIC, TEXT, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.teller_post_savings_deposit(UUID, NUMERIC, TEXT, TEXT, TEXT) TO authenticated;
COMMIT;
