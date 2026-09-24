BEGIN;
CREATE OR REPLACE FUNCTION bmt_db.teller_search_savings_accounts(p_search TEXT DEFAULT '')
RETURNS TABLE(financial_account_id UUID, account_number TEXT, customer_id UUID, cif_number TEXT, full_name TEXT, status TEXT, current_balance NUMERIC, branch_id UUID)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT (bmt_db.current_user_is_superadmin() OR bmt_db.current_user_has_role('TELLER', NULL)) THEN
    RAISE EXCEPTION 'Teller access required';
  END IF;
  RETURN QUERY
  SELECT fa.id, fa.account_number::TEXT, c.id, c.cif_number::TEXT,
    c.full_name::TEXT, fa.status::TEXT, sa.current_balance::NUMERIC, fa.branch_id
  FROM bmt_db.financial_accounts fa
  JOIN bmt_db.customers c ON c.id = fa.customer_id
  JOIN bmt_db.savings_accounts sa ON sa.financial_account_id = fa.id
  WHERE fa.account_type = 'SAVINGS'
    AND (NULLIF(btrim(p_search), '') IS NULL OR c.full_name ILIKE '%' || btrim(p_search) || '%'
      OR c.cif_number ILIKE '%' || btrim(p_search) || '%'
      OR fa.account_number ILIKE '%' || btrim(p_search) || '%')
  ORDER BY c.full_name, fa.account_number LIMIT 25;
END; $$;
REVOKE ALL ON FUNCTION bmt_db.teller_search_savings_accounts(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.teller_search_savings_accounts(TEXT) TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
