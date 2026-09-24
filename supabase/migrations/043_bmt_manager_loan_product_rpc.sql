BEGIN;
CREATE OR REPLACE FUNCTION bmt_db.manager_create_loan_product(
  p_code TEXT, p_name TEXT, p_loan_code TEXT, p_minimum_principal NUMERIC,
  p_maximum_principal NUMERIC, p_minimum_tenor_months INTEGER,
  p_maximum_tenor_months INTEGER, p_rate NUMERIC
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_product UUID; v_user UUID := auth.uid();
BEGIN
  IF v_user IS NULL OR NOT (bmt_db.current_user_is_superadmin() OR bmt_db.current_user_has_role('MANAGER', NULL)) THEN
    RAISE EXCEPTION 'Manager access required';
  END IF;
  IF p_minimum_principal <= 0 OR p_maximum_principal < p_minimum_principal OR p_minimum_tenor_months <= 0 OR p_maximum_tenor_months < p_minimum_tenor_months THEN
    RAISE EXCEPTION 'Invalid product limits';
  END IF;
  INSERT INTO bmt_db.products(code,name,category,is_active,created_by) VALUES (upper(btrim(p_code)), btrim(p_name), 'LOAN', TRUE, v_user) RETURNING id INTO v_product;
  INSERT INTO bmt_db.loan_products(product_id,loan_code,minimum_principal,maximum_principal,minimum_tenor_months,maximum_tenor_months,rate) VALUES (v_product,btrim(p_loan_code),p_minimum_principal,p_maximum_principal,p_minimum_tenor_months,p_maximum_tenor_months,p_rate);
  RETURN v_product;
END; $$;
REVOKE ALL ON FUNCTION bmt_db.manager_create_loan_product(TEXT,TEXT,TEXT,NUMERIC,NUMERIC,INTEGER,INTEGER,NUMERIC) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION bmt_db.manager_create_loan_product(TEXT,TEXT,TEXT,NUMERIC,NUMERIC,INTEGER,INTEGER,NUMERIC) TO authenticated;
COMMIT;
