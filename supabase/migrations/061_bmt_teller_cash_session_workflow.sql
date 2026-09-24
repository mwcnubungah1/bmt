BEGIN;

CREATE OR REPLACE FUNCTION bmt_db.teller_get_cash_session()
RETURNS TABLE(id UUID, branch_id UUID, business_date DATE, opening_balance NUMERIC, system_closing_balance NUMERIC, physical_closing_balance NUMERIC, difference NUMERIC, status TEXT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT (bmt_db.current_user_is_superadmin() OR bmt_db.current_user_has_role('TELLER', NULL)) THEN RAISE EXCEPTION 'Teller access required'; END IF;
  RETURN QUERY SELECT s.id, s.branch_id, s.business_date, s.opening_balance, s.system_closing_balance, s.physical_closing_balance, s.difference, s.status::TEXT
  FROM bmt_db.teller_cash_sessions s WHERE s.teller_user_id = auth.uid() AND s.business_date = CURRENT_DATE ORDER BY s.opened_at DESC LIMIT 1;
END; $$;

CREATE OR REPLACE FUNCTION bmt_db.teller_open_cash_session(p_opening_balance NUMERIC, p_branch_id UUID DEFAULT NULL)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_user UUID := auth.uid(); v_branch UUID; v_session UUID;
BEGIN
  IF v_user IS NULL OR NOT (bmt_db.current_user_is_superadmin() OR bmt_db.current_user_has_role('TELLER', NULL)) THEN RAISE EXCEPTION 'Teller access required'; END IF;
  IF p_opening_balance IS NULL OR p_opening_balance < 0 THEN RAISE EXCEPTION 'Saldo awal kas tidak valid'; END IF;
  IF p_branch_id IS NULL THEN
    SELECT ub.branch_id INTO v_branch FROM bmt_db.user_branches ub WHERE ub.user_id = v_user ORDER BY ub.branch_id LIMIT 1;
  ELSE
    v_branch := p_branch_id;
  END IF;
  IF v_branch IS NULL OR NOT EXISTS (SELECT 1 FROM bmt_db.user_branches WHERE user_id = v_user AND branch_id = v_branch) THEN RAISE EXCEPTION 'Cabang teller belum ditentukan'; END IF;
  IF EXISTS (SELECT 1 FROM bmt_db.teller_cash_sessions WHERE teller_user_id = v_user AND branch_id = v_branch AND business_date = CURRENT_DATE AND status = 'OPEN') THEN RAISE EXCEPTION 'Sesi kas sudah dibuka'; END IF;
  INSERT INTO bmt_db.teller_cash_sessions(branch_id, teller_user_id, business_date, opening_balance, status) VALUES (v_branch, v_user, CURRENT_DATE, p_opening_balance, 'OPEN') RETURNING id INTO v_session;
  RETURN v_session;
END; $$;

CREATE OR REPLACE FUNCTION bmt_db.teller_close_cash_session(p_physical_closing_balance NUMERIC)
RETURNS TABLE(id UUID, system_closing_balance NUMERIC, physical_closing_balance NUMERIC, difference NUMERIC)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_user UUID := auth.uid(); v_session bmt_db.teller_cash_sessions%ROWTYPE; v_system NUMERIC; v_difference NUMERIC;
BEGIN
  IF v_user IS NULL OR NOT (bmt_db.current_user_is_superadmin() OR bmt_db.current_user_has_role('TELLER', NULL)) THEN RAISE EXCEPTION 'Teller access required'; END IF;
  IF p_physical_closing_balance IS NULL OR p_physical_closing_balance < 0 THEN RAISE EXCEPTION 'Saldo fisik kas tidak valid'; END IF;
  SELECT * INTO v_session FROM bmt_db.teller_cash_sessions WHERE teller_user_id = v_user AND business_date = CURRENT_DATE AND status = 'OPEN' ORDER BY opened_at DESC LIMIT 1 FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Sesi kas belum dibuka'; END IF;
  SELECT v_session.opening_balance + COALESCE(sum(CASE WHEN movement_type IN ('CASH_IN','TRANSFER_IN') THEN amount ELSE -amount END), 0) INTO v_system FROM bmt_db.teller_cash_movements WHERE cash_session_id = v_session.id;
  v_difference := p_physical_closing_balance - v_system;
  UPDATE bmt_db.teller_cash_sessions SET system_closing_balance = v_system, physical_closing_balance = p_physical_closing_balance, difference = v_difference, status = 'CLOSED', closed_at = now(), updated_at = now() WHERE id = v_session.id;
  RETURN QUERY SELECT v_session.id, v_system, p_physical_closing_balance, v_difference;
END; $$;

REVOKE ALL ON FUNCTION bmt_db.teller_get_cash_session() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.teller_get_cash_session() TO authenticated;
REVOKE ALL ON FUNCTION bmt_db.teller_open_cash_session(NUMERIC, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.teller_open_cash_session(NUMERIC, UUID) TO authenticated;
REVOKE ALL ON FUNCTION bmt_db.teller_close_cash_session(NUMERIC) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.teller_close_cash_session(NUMERIC) TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
