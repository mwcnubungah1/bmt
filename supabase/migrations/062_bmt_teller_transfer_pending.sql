BEGIN;

CREATE OR REPLACE FUNCTION bmt_db.teller_submit_savings_transfer(
  p_financial_account_id UUID,
  p_amount NUMERIC,
  p_reference_number TEXT,
  p_description TEXT DEFAULT NULL,
  p_idempotency_key UUID DEFAULT NULL
)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_user UUID := auth.uid(); v_account bmt_db.financial_accounts%ROWTYPE; v_customer bmt_db.customers%ROWTYPE; v_tx UUID;
BEGIN
  IF v_user IS NULL OR NOT (bmt_db.current_user_is_superadmin() OR bmt_db.current_user_has_role('TELLER', NULL)) THEN RAISE EXCEPTION 'Teller access required'; END IF;
  IF p_idempotency_key IS NULL THEN RAISE EXCEPTION 'Idempotency key is required'; END IF;
  IF p_amount IS NULL OR p_amount <= 0 OR NULLIF(btrim(p_reference_number), '') IS NULL THEN RAISE EXCEPTION 'Nominal dan referensi transfer wajib diisi'; END IF;
  PERFORM pg_advisory_xact_lock(hashtext(p_idempotency_key::TEXT));
  SELECT id INTO v_tx FROM bmt_db.transactions WHERE idempotency_key = p_idempotency_key FOR SHARE;
  IF FOUND THEN RETURN v_tx; END IF;
  SELECT * INTO v_account FROM bmt_db.financial_accounts WHERE id = p_financial_account_id AND account_type = 'SAVINGS' AND status = 'ACTIVE' FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Rekening tabungan aktif tidak ditemukan'; END IF;
  SELECT * INTO v_customer FROM bmt_db.customers WHERE id = v_account.customer_id;
  INSERT INTO bmt_db.transactions(transaction_number, branch_id, transaction_type, customer_id, financial_account_id, amount, status, channel, description, reference_number, created_by, idempotency_key)
  VALUES ('DEP-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS') || '-' || substr(replace(gen_random_uuid()::TEXT, '-', ''), 1, 8), v_account.branch_id, 'SAVINGS_DEPOSIT', v_customer.id, p_financial_account_id, p_amount, 'PENDING_APPROVAL', 'ONLINE', COALESCE(NULLIF(btrim(p_description), ''), 'Setoran transfer menunggu verifikasi'), btrim(p_reference_number), v_user, p_idempotency_key)
  RETURNING id INTO v_tx;
  INSERT INTO bmt_db.audit_logs(user_id, branch_id, action, entity_type, entity_id, transaction_id, metadata)
  VALUES (v_user, v_account.branch_id, 'SAVINGS_TRANSFER_DEPOSIT_PENDING', 'SAVINGS_ACCOUNT', p_financial_account_id, v_tx, jsonb_build_object('amount', p_amount, 'reference_number', p_reference_number));
  RETURN v_tx;
END; $$;

REVOKE ALL ON FUNCTION bmt_db.teller_submit_savings_transfer(UUID, NUMERIC, TEXT, TEXT, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.teller_submit_savings_transfer(UUID, NUMERIC, TEXT, TEXT, UUID) TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
