BEGIN;

CREATE OR REPLACE FUNCTION bmt_db.teller_get_cash_session()
RETURNS TABLE(
  id UUID,
  branch_id UUID,
  business_date DATE,
  opening_balance NUMERIC,
  system_balance NUMERIC,
  system_closing_balance NUMERIC,
  physical_closing_balance NUMERIC,
  difference NUMERIC,
  status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_session bmt_db.teller_cash_sessions%ROWTYPE;
  v_system_balance NUMERIC;
BEGIN
  IF auth.uid() IS NULL
     OR NOT (
       bmt_db.current_user_is_superadmin()
       OR bmt_db.current_user_has_role('TELLER', NULL)
     ) THEN
    RAISE EXCEPTION 'Teller access required';
  END IF;

  SELECT session_row.*
    INTO v_session
    FROM bmt_db.teller_cash_sessions AS session_row
   WHERE session_row.teller_user_id = auth.uid()
     AND session_row.business_date = CURRENT_DATE
   ORDER BY session_row.opened_at DESC
   LIMIT 1;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  SELECT v_session.opening_balance
         + COALESCE(
             SUM(
               CASE
                 WHEN movement_row.movement_type IN ('CASH_IN', 'TRANSFER_IN')
                   THEN movement_row.amount
                 ELSE -movement_row.amount
               END
             ),
             0
           )
    INTO v_system_balance
    FROM bmt_db.teller_cash_movements AS movement_row
   WHERE movement_row.cash_session_id = v_session.id;

  RETURN QUERY
  SELECT
    v_session.id,
    v_session.branch_id,
    v_session.business_date,
    v_session.opening_balance::NUMERIC,
    v_system_balance::NUMERIC,
    v_session.system_closing_balance::NUMERIC,
    v_session.physical_closing_balance::NUMERIC,
    v_session.difference::NUMERIC,
    v_session.status::TEXT;
END;
$$;

REVOKE ALL ON FUNCTION bmt_db.teller_get_cash_session() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.teller_get_cash_session() TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
