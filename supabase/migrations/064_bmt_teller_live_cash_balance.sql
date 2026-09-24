BEGIN;

DROP FUNCTION IF EXISTS bmt_db.teller_get_cash_session();
CREATE FUNCTION bmt_db.teller_get_cash_session()
RETURNS TABLE(id UUID, branch_id UUID, business_date DATE, opening_balance NUMERIC, system_balance NUMERIC, system_closing_balance NUMERIC, physical_closing_balance NUMERIC, difference NUMERIC, status TEXT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT (bmt_db.current_user_is_superadmin() OR bmt_db.current_user_has_role('TELLER', NULL)) THEN
    RAISE EXCEPTION 'Teller access required';
  END IF;
  RETURN QUERY
  SELECT s.id, s.branch_id, s.business_date, s.opening_balance::NUMERIC,
    (s.opening_balance + COALESCE((SELECT SUM(CASE WHEN m.movement_type IN ('CASH_IN','TRANSFER_IN') THEN m.amount ELSE -m.amount END)
      FROM bmt_db.teller_cash_movements m WHERE m.cash_session_id = s.id), 0))::NUMERIC,
    s.system_closing_balance::NUMERIC, s.physical_closing_balance::NUMERIC, s.difference::NUMERIC, s.status::TEXT
  FROM bmt_db.teller_cash_sessions s
  WHERE s.teller_user_id = auth.uid() AND s.business_date = CURRENT_DATE
  ORDER BY s.opened_at DESC LIMIT 1;
END; $$;
REVOKE ALL ON FUNCTION bmt_db.teller_get_cash_session() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.teller_get_cash_session() TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
