BEGIN;

ALTER TABLE bmt_db.savings_products
  ADD COLUMN IF NOT EXISTS minimum_monthly_deposit bmt_db.money_amount NOT NULL DEFAULT 0;

ALTER TABLE bmt_db.savings_products
  DROP CONSTRAINT IF EXISTS ck_savings_products_monthly_deposit;
ALTER TABLE bmt_db.savings_products
  ADD CONSTRAINT ck_savings_products_monthly_deposit CHECK (minimum_monthly_deposit >= 0);

-- Existing savings products receive the first operational policy. Managers can
-- change the value through manager_update_savings_product_rules.
UPDATE bmt_db.savings_products
   SET minimum_monthly_deposit = 20000
 WHERE minimum_monthly_deposit = 0;

CREATE OR REPLACE FUNCTION bmt_db.manager_update_savings_product_rules(
  p_product_id UUID,
  p_minimum_monthly_deposit NUMERIC,
  p_dormant_after_days INTEGER
)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT (bmt_db.current_user_is_superadmin() OR bmt_db.current_user_has_role('MANAGER', NULL)) THEN
    RAISE EXCEPTION 'Manager access required';
  END IF;
  IF p_minimum_monthly_deposit IS NULL OR p_minimum_monthly_deposit < 0 THEN RAISE EXCEPTION 'Minimum setoran bulanan tidak valid'; END IF;
  IF p_dormant_after_days IS NOT NULL AND p_dormant_after_days <= 0 THEN RAISE EXCEPTION 'Batas dormant harus lebih besar dari nol'; END IF;
  UPDATE bmt_db.savings_products
     SET minimum_monthly_deposit = p_minimum_monthly_deposit,
         dormant_after_days = p_dormant_after_days,
         updated_at = now()
   WHERE product_id = p_product_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Produk tabungan tidak ditemukan'; END IF;
END;
$$;

-- Re-evaluate savings accounts. Missing a monthly target is reported to the
-- caller; it does not automatically become a debt. Dormancy is based on the
-- product's inactivity policy and changes only ACTIVE/DORMANT accounts.
CREATE OR REPLACE FUNCTION bmt_db.refresh_savings_account_status()
RETURNS TABLE(
  financial_account_id UUID,
  product_code TEXT,
  monthly_deposit NUMERIC,
  minimum_monthly_deposit NUMERIC,
  monthly_target_met BOOLEAN,
  status TEXT,
  dormant_at TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  UPDATE bmt_db.financial_accounts AS account_row
     SET status = CASE
       WHEN savings_product.dormant_after_days IS NOT NULL
        AND COALESCE(savings_account.last_transaction_at, savings_account.created_at) < now() - make_interval(days => savings_product.dormant_after_days)
        AND account_row.status IN ('ACTIVE','DORMANT') THEN 'DORMANT'::bmt_db.account_status
       WHEN account_row.status = 'DORMANT'
        AND COALESCE(savings_account.last_transaction_at, savings_account.created_at) >= now() - make_interval(days => COALESCE(savings_product.dormant_after_days, 1)) THEN 'ACTIVE'::bmt_db.account_status
       ELSE account_row.status
     END,
     updated_at = now()
    FROM bmt_db.savings_accounts AS savings_account,
         bmt_db.savings_products AS savings_product
   WHERE savings_account.financial_account_id = account_row.id
     AND savings_product.product_id = account_row.product_id
     AND account_row.status IN ('ACTIVE','DORMANT');

  UPDATE bmt_db.savings_accounts AS savings_account
     SET dormant_at = CASE WHEN account_row.status = 'DORMANT' THEN COALESCE(savings_account.dormant_at, now()) ELSE NULL END,
         updated_at = now()
    FROM bmt_db.financial_accounts AS account_row
   WHERE account_row.id = savings_account.financial_account_id;

  RETURN QUERY
  SELECT account_row.id,
         product.code::TEXT,
         COALESCE(SUM(CASE WHEN ledger.entry_type = 'CREDIT' AND ledger.entry_date >= date_trunc('month', CURRENT_DATE)::DATE THEN ledger.amount ELSE 0 END), 0)::NUMERIC,
         savings_product.minimum_monthly_deposit::NUMERIC,
         COALESCE(SUM(CASE WHEN ledger.entry_type = 'CREDIT' AND ledger.entry_date >= date_trunc('month', CURRENT_DATE)::DATE THEN ledger.amount ELSE 0 END), 0) >= savings_product.minimum_monthly_deposit,
         account_row.status::TEXT,
         savings_account.dormant_at
    FROM bmt_db.financial_accounts AS account_row
    JOIN bmt_db.savings_accounts AS savings_account ON savings_account.financial_account_id = account_row.id
    JOIN bmt_db.products AS product ON product.id = account_row.product_id
    JOIN bmt_db.savings_products AS savings_product ON savings_product.product_id = product.id
    LEFT JOIN bmt_db.savings_ledger AS ledger ON ledger.account_id = account_row.id
   WHERE account_row.account_type = 'SAVINGS'
   GROUP BY account_row.id, product.code, savings_product.minimum_monthly_deposit, account_row.status, savings_account.dormant_at;
END;
$$;

CREATE OR REPLACE FUNCTION bmt_db.portal_get_savings_compliance()
RETURNS TABLE(
  financial_account_id UUID,
  account_number TEXT,
  product_name TEXT,
  current_balance NUMERIC,
  monthly_deposit NUMERIC,
  minimum_monthly_deposit NUMERIC,
  monthly_target_met BOOLEAN,
  status TEXT,
  dormant_at TIMESTAMPTZ
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT account_row.id, account_row.account_number::TEXT, product.name::TEXT,
         savings_account.current_balance,
         COALESCE(SUM(CASE WHEN ledger.entry_type = 'CREDIT' AND ledger.entry_date >= date_trunc('month', CURRENT_DATE)::DATE THEN ledger.amount ELSE 0 END), 0),
         savings_product.minimum_monthly_deposit,
         COALESCE(SUM(CASE WHEN ledger.entry_type = 'CREDIT' AND ledger.entry_date >= date_trunc('month', CURRENT_DATE)::DATE THEN ledger.amount ELSE 0 END), 0) >= savings_product.minimum_monthly_deposit,
         account_row.status::TEXT, savings_account.dormant_at
    FROM bmt_db.financial_accounts AS account_row
    JOIN bmt_db.customers AS customer_row ON customer_row.id = account_row.customer_id
    JOIN bmt_db.products AS product ON product.id = account_row.product_id
    JOIN bmt_db.savings_products AS savings_product ON savings_product.product_id = product.id
    JOIN bmt_db.savings_accounts AS savings_account ON savings_account.financial_account_id = account_row.id
    LEFT JOIN bmt_db.savings_ledger AS ledger ON ledger.account_id = account_row.id
   WHERE account_row.account_type = 'SAVINGS' AND customer_row.auth_user_id = auth.uid()
   GROUP BY account_row.id, account_row.account_number, product.name, savings_account.current_balance, savings_product.minimum_monthly_deposit, account_row.status, savings_account.dormant_at
   ORDER BY account_row.account_number;
$$;

REVOKE ALL ON FUNCTION bmt_db.manager_update_savings_product_rules(UUID,NUMERIC,INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.manager_update_savings_product_rules(UUID,NUMERIC,INTEGER) TO authenticated;
REVOKE ALL ON FUNCTION bmt_db.refresh_savings_account_status() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.refresh_savings_account_status() TO authenticated;
REVOKE ALL ON FUNCTION bmt_db.portal_get_savings_compliance() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.portal_get_savings_compliance() TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
