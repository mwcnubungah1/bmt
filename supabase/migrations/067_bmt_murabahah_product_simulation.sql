BEGIN;

-- Extend the existing product model without replacing legacy rows.
ALTER TABLE bmt_db.products
  ADD COLUMN IF NOT EXISTS terms_and_conditions TEXT;

ALTER TABLE bmt_db.loan_products
  ADD COLUMN IF NOT EXISTS akad_code TEXT NOT NULL DEFAULT 'MURABAHAH',
  ADD COLUMN IF NOT EXISTS calculation_method TEXT NOT NULL DEFAULT 'FLAT',
  ADD COLUMN IF NOT EXISTS margin_type TEXT NOT NULL DEFAULT 'PERCENTAGE',
  ADD COLUMN IF NOT EXISTS margin_rate NUMERIC NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS tenor_options INTEGER[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS installment_frequency TEXT NOT NULL DEFAULT 'MONTHLY',
  ADD COLUMN IF NOT EXISTS admin_fee_type TEXT NOT NULL DEFAULT 'FIXED',
  ADD COLUMN IF NOT EXISTS admin_fee_value NUMERIC NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS insurance_fee_type TEXT NOT NULL DEFAULT 'NONE',
  ADD COLUMN IF NOT EXISTS insurance_fee_value NUMERIC NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS late_payment_policy TEXT,
  ADD COLUMN IF NOT EXISTS collateral_required BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS minimum_membership_months INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS minimum_income NUMERIC;

UPDATE bmt_db.loan_products SET margin_rate = rate WHERE margin_rate = 0 AND rate <> 0;
UPDATE bmt_db.loan_products SET tenor_options = ARRAY(SELECT generate_series(minimum_tenor_months, maximum_tenor_months)) WHERE cardinality(tenor_options) = 0 AND maximum_tenor_months - minimum_tenor_months <= 60;
UPDATE bmt_db.loan_products SET collateral_required = require_collateral WHERE collateral_required = FALSE AND require_collateral = TRUE;

CREATE TABLE IF NOT EXISTS bmt_db.loan_product_requirements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  loan_product_id UUID NOT NULL REFERENCES bmt_db.loan_products(product_id) ON DELETE CASCADE,
  requirement_code TEXT NOT NULL,
  requirement_name TEXT NOT NULL,
  description TEXT,
  is_required BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_loan_product_requirement_code UNIQUE (loan_product_id, requirement_code)
);

CREATE TABLE IF NOT EXISTS bmt_db.loan_product_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  loan_product_id UUID NOT NULL REFERENCES bmt_db.loan_products(product_id) ON DELETE RESTRICT,
  version_number INTEGER NOT NULL,
  margin_rate NUMERIC NOT NULL DEFAULT 0,
  minimum_principal NUMERIC NOT NULL,
  maximum_principal NUMERIC,
  tenor_options INTEGER[] NOT NULL DEFAULT '{}',
  admin_fee_value NUMERIC NOT NULL DEFAULT 0,
  effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
  effective_until DATE,
  approved_by UUID REFERENCES bmt_db.user_profiles(id),
  status TEXT NOT NULL DEFAULT 'DRAFT',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_loan_product_version UNIQUE (loan_product_id, version_number),
  CONSTRAINT ck_loan_product_version_status CHECK (status IN ('DRAFT','ACTIVE','INACTIVE','EXPIRED')),
  CONSTRAINT ck_loan_product_version_range CHECK (maximum_principal IS NULL OR maximum_principal >= minimum_principal)
);

INSERT INTO bmt_db.loan_product_versions(loan_product_id, version_number, margin_rate, minimum_principal, maximum_principal, tenor_options, admin_fee_value, status)
SELECT lp.product_id, 1, lp.margin_rate, lp.minimum_principal, lp.maximum_principal, lp.tenor_options,
  CASE WHEN lp.admin_fee_type = 'PERCENTAGE' THEN lp.admin_fee_value ELSE lp.admin_fee END, 'ACTIVE'
FROM bmt_db.loan_products lp
WHERE NOT EXISTS (SELECT 1 FROM bmt_db.loan_product_versions v WHERE v.loan_product_id = lp.product_id);

INSERT INTO bmt_db.loan_product_requirements(loan_product_id, requirement_code, requirement_name, description, is_required, sort_order)
SELECT lp.product_id, req.code, req.name, req.description, TRUE, req.sort_order
FROM bmt_db.loan_products lp
CROSS JOIN (VALUES
  ('KTP', 'KTP', 'Kartu tanda penduduk pemohon', 1),
  ('KK', 'Kartu Keluarga', 'Kartu keluarga terbaru', 2),
  ('PURPOSE', 'Rincian tujuan pembiayaan', 'Penjelasan penggunaan dana atau barang', 3)
) req(code, name, description, sort_order)
WHERE NOT EXISTS (SELECT 1 FROM bmt_db.loan_product_requirements r WHERE r.loan_product_id=lp.product_id AND r.requirement_code=req.code);

ALTER TABLE bmt_db.loan_applications
  ADD COLUMN IF NOT EXISTS loan_product_version_id UUID REFERENCES bmt_db.loan_product_versions(id),
  ADD COLUMN IF NOT EXISTS margin_rate_snapshot NUMERIC,
  ADD COLUMN IF NOT EXISTS margin_amount_snapshot NUMERIC,
  ADD COLUMN IF NOT EXISTS selling_price_snapshot NUMERIC,
  ADD COLUMN IF NOT EXISTS installment_amount_snapshot NUMERIC,
  ADD COLUMN IF NOT EXISTS admin_fee_snapshot NUMERIC,
  ADD COLUMN IF NOT EXISTS simulation_snapshot JSONB,
  ADD COLUMN IF NOT EXISTS idempotency_key UUID;
CREATE UNIQUE INDEX IF NOT EXISTS uq_loan_applications_idempotency_key
  ON bmt_db.loan_applications(idempotency_key) WHERE idempotency_key IS NOT NULL;

ALTER TABLE bmt_db.loan_product_requirements ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.loan_product_versions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS loan_product_requirements_select ON bmt_db.loan_product_requirements;
CREATE POLICY loan_product_requirements_select ON bmt_db.loan_product_requirements FOR SELECT TO authenticated USING (bmt_db.current_user_is_active());
DROP POLICY IF EXISTS loan_product_versions_select ON bmt_db.loan_product_versions;
CREATE POLICY loan_product_versions_select ON bmt_db.loan_product_versions FOR SELECT TO authenticated USING (bmt_db.current_user_is_active());

DROP FUNCTION IF EXISTS bmt_db.customer_simulate_murabahah(UUID, NUMERIC, INTEGER);
CREATE FUNCTION bmt_db.customer_simulate_murabahah(
  p_loan_product_id UUID, p_requested_amount NUMERIC, p_requested_tenor_months INTEGER
) RETURNS TABLE(
  loan_product_id UUID, loan_product_version_id UUID, akad_code TEXT, calculation_method TEXT,
  principal NUMERIC, margin_rate NUMERIC, margin_amount NUMERIC, selling_price NUMERIC,
  monthly_installment NUMERIC, admin_fee NUMERIC, total_initial_cost NUMERIC, schedule JSONB,
  disclaimer TEXT
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_lp bmt_db.loan_products%ROWTYPE; v_v bmt_db.loan_product_versions%ROWTYPE;
  v_margin NUMERIC; v_selling NUMERIC; v_admin NUMERIC; v_base NUMERIC; v_last NUMERIC; v_schedule JSONB;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  SELECT lp.* INTO v_lp FROM bmt_db.loan_products lp JOIN bmt_db.products p ON p.id=lp.product_id
    WHERE lp.product_id=p_loan_product_id AND p.category='LOAN' AND p.is_active;
  IF NOT FOUND THEN RAISE EXCEPTION 'Produk pembiayaan tidak aktif'; END IF;
  SELECT v.* INTO v_v FROM bmt_db.loan_product_versions v WHERE v.loan_product_id=p_loan_product_id AND v.status='ACTIVE'
    AND v.effective_from <= CURRENT_DATE AND (v.effective_until IS NULL OR v.effective_until >= CURRENT_DATE)
    ORDER BY v.version_number DESC LIMIT 1;
  IF NOT FOUND THEN RAISE EXCEPTION 'Versi produk aktif tidak ditemukan'; END IF;
  IF p_requested_amount < v_v.minimum_principal OR (v_v.maximum_principal IS NOT NULL AND p_requested_amount > v_v.maximum_principal) THEN RAISE EXCEPTION 'Nominal di luar batas produk'; END IF;
  IF p_requested_tenor_months <= 0 OR (cardinality(v_v.tenor_options) > 0 AND NOT p_requested_tenor_months = ANY(v_v.tenor_options)) THEN RAISE EXCEPTION 'Tenor tidak tersedia untuk produk'; END IF;
  v_margin := floor(p_requested_amount * v_v.margin_rate / 100);
  v_selling := p_requested_amount + v_margin;
  v_base := floor(p_requested_amount / p_requested_tenor_months) + floor(v_margin / p_requested_tenor_months);
  v_last := v_selling - (v_base * (p_requested_tenor_months - 1));
  v_admin := CASE WHEN v_lp.admin_fee_type='PERCENTAGE' THEN floor(p_requested_amount * v_lp.admin_fee_value / 100) ELSE v_lp.admin_fee_value END;
  SELECT jsonb_agg(jsonb_build_object('installment_no', n, 'principal_amount', CASE WHEN n=p_requested_tenor_months THEN p_requested_amount-floor(p_requested_amount/p_requested_tenor_months)*(p_requested_tenor_months-1) ELSE floor(p_requested_amount/p_requested_tenor_months) END, 'margin_amount', CASE WHEN n=p_requested_tenor_months THEN v_margin-floor(v_margin/p_requested_tenor_months)*(p_requested_tenor_months-1) ELSE floor(v_margin/p_requested_tenor_months) END, 'total_amount', CASE WHEN n=p_requested_tenor_months THEN v_last ELSE v_base END) ORDER BY n) INTO v_schedule FROM generate_series(1,p_requested_tenor_months) n;
  RETURN QUERY SELECT v_lp.product_id, v_v.id, v_lp.akad_code, v_lp.calculation_method, p_requested_amount, v_v.margin_rate, v_margin, v_selling, v_base, v_admin, p_requested_amount+v_admin, v_schedule, 'Simulasi awal. Nilai final ditetapkan setelah analisis dan akad BMT.';
END; $$;

CREATE OR REPLACE FUNCTION bmt_db.customer_get_loan_product_requirements(p_loan_product_id UUID)
RETURNS TABLE(requirement_code TEXT, requirement_name TEXT, description TEXT, is_required BOOLEAN, sort_order INTEGER)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT r.requirement_code, r.requirement_name, r.description, r.is_required, r.sort_order
  FROM bmt_db.loan_product_requirements r
  WHERE r.loan_product_id = p_loan_product_id AND r.is_active
  ORDER BY r.sort_order, r.requirement_name;
$$;

CREATE OR REPLACE FUNCTION bmt_db.manager_create_murabahah_product(
  p_code TEXT, p_name TEXT, p_loan_code TEXT, p_minimum_principal NUMERIC, p_maximum_principal NUMERIC,
  p_tenor_options INTEGER[], p_margin_rate NUMERIC, p_admin_fee_type TEXT DEFAULT 'FIXED', p_admin_fee_value NUMERIC DEFAULT 0,
  p_terms_and_conditions TEXT DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_user UUID:=auth.uid(); v_product UUID; v_version UUID;
BEGIN
  IF v_user IS NULL OR NOT (bmt_db.current_user_is_superadmin() OR bmt_db.current_user_has_role('MANAGER',NULL)) THEN RAISE EXCEPTION 'Manager access required'; END IF;
  IF p_minimum_principal <= 0 OR p_maximum_principal < p_minimum_principal OR p_margin_rate < 0 OR cardinality(p_tenor_options)=0 THEN RAISE EXCEPTION 'Konfigurasi produk tidak valid'; END IF;
  INSERT INTO bmt_db.products(code,name,category,is_active,description,terms_and_conditions,created_by) VALUES (upper(btrim(p_code)),btrim(p_name),'LOAN',TRUE,'Pembiayaan murabahah',p_terms_and_conditions,v_user) RETURNING id INTO v_product;
  INSERT INTO bmt_db.loan_products(product_id,loan_code,akad_code,calculation_method,margin_type,margin_rate,minimum_principal,maximum_principal,minimum_tenor_months,maximum_tenor_months,tenor_options,installment_frequency,admin_fee_type,admin_fee_value) VALUES (v_product,btrim(p_loan_code),'MURABAHAH','FLAT','PERCENTAGE',p_margin_rate,p_minimum_principal,p_maximum_principal,(SELECT min(x) FROM unnest(p_tenor_options)x),(SELECT max(x) FROM unnest(p_tenor_options)x),p_tenor_options,'MONTHLY',p_admin_fee_type,p_admin_fee_value);
  INSERT INTO bmt_db.loan_product_versions(loan_product_id,version_number,margin_rate,minimum_principal,maximum_principal,tenor_options,admin_fee_value,status,approved_by) VALUES (v_product,1,p_margin_rate,p_minimum_principal,p_maximum_principal,p_tenor_options,p_admin_fee_value,'ACTIVE',v_user) RETURNING id INTO v_version;
  INSERT INTO bmt_db.loan_product_requirements(loan_product_id,requirement_code,requirement_name,description,sort_order) VALUES (v_product,'KTP','KTP','Kartu tanda penduduk pemohon',1),(v_product,'KK','Kartu Keluarga','Kartu keluarga terbaru',2),(v_product,'PURPOSE','Rincian tujuan pembiayaan','Penjelasan penggunaan dana atau barang',3);
  RETURN v_product;
END; $$;

DROP FUNCTION IF EXISTS bmt_db.customer_submit_loan_application(UUID, UUID, NUMERIC, INTEGER, TEXT, TEXT);
DROP FUNCTION IF EXISTS bmt_db.customer_submit_loan_application(UUID, UUID, NUMERIC, INTEGER, TEXT, UUID);
CREATE FUNCTION bmt_db.customer_submit_loan_application(p_savings_account_id UUID, p_loan_product_id UUID, p_requested_amount NUMERIC, p_requested_tenor_months INTEGER, p_purpose TEXT, p_idempotency_key UUID)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_user UUID:=auth.uid(); v_customer bmt_db.customers%ROWTYPE; v_sim RECORD; v_app UUID; v_existing UUID;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  IF p_idempotency_key IS NULL THEN RAISE EXCEPTION 'Idempotency key is required'; END IF;
  SELECT id INTO v_existing FROM bmt_db.loan_applications WHERE idempotency_key=p_idempotency_key;
  IF v_existing IS NOT NULL THEN RETURN v_existing; END IF;
  SELECT * INTO v_customer FROM bmt_db.customers WHERE auth_user_id=v_user AND status='ACTIVE';
  IF NOT FOUND THEN RAISE EXCEPTION 'Active customer profile is required'; END IF;
  IF NOT EXISTS (SELECT 1 FROM bmt_db.savings_accounts sa JOIN bmt_db.financial_accounts fa ON fa.id=sa.financial_account_id WHERE sa.financial_account_id=p_savings_account_id AND fa.customer_id=v_customer.id AND fa.account_type='SAVINGS' AND fa.status='ACTIVE') THEN RAISE EXCEPTION 'Rekening sumber harus aktif dan milik nasabah'; END IF;
  SELECT * INTO v_sim FROM bmt_db.customer_simulate_murabahah(p_loan_product_id,p_requested_amount,p_requested_tenor_months);
  INSERT INTO bmt_db.loan_applications(application_number,customer_id,savings_account_id,loan_product_id,loan_product_version_id,branch_id,requested_amount,requested_tenor_months,purpose,status,submitted_at,created_by,margin_rate_snapshot,margin_amount_snapshot,selling_price_snapshot,installment_amount_snapshot,admin_fee_snapshot,simulation_snapshot,idempotency_key)
  VALUES ('LOAN-'||to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS')||'-'||substr(replace(gen_random_uuid()::text,'-',''),1,8),v_customer.id,p_savings_account_id,p_loan_product_id,v_sim.loan_product_version_id,v_customer.branch_id,p_requested_amount,p_requested_tenor_months,btrim(p_purpose),'SUBMITTED',now(),v_user,v_sim.margin_rate,v_sim.margin_amount,v_sim.selling_price,v_sim.monthly_installment,v_sim.admin_fee,jsonb_build_object('akad_code',v_sim.akad_code,'calculation_method',v_sim.calculation_method,'schedule',v_sim.schedule,'disclaimer',v_sim.disclaimer),p_idempotency_key) RETURNING id INTO v_app;
  RETURN v_app;
EXCEPTION WHEN unique_violation THEN SELECT id INTO v_existing FROM bmt_db.loan_applications WHERE idempotency_key=p_idempotency_key; IF v_existing IS NOT NULL THEN RETURN v_existing; END IF; RAISE;
END; $$;
REVOKE ALL ON FUNCTION bmt_db.customer_simulate_murabahah(UUID,NUMERIC,INTEGER) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION bmt_db.customer_simulate_murabahah(UUID,NUMERIC,INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION bmt_db.customer_get_loan_product_requirements(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION bmt_db.manager_create_murabahah_product(TEXT,TEXT,TEXT,NUMERIC,NUMERIC,INTEGER[],NUMERIC,TEXT,NUMERIC,TEXT) TO authenticated;
REVOKE ALL ON FUNCTION bmt_db.customer_submit_loan_application(UUID,UUID,NUMERIC,INTEGER,TEXT,UUID) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION bmt_db.customer_submit_loan_application(UUID,UUID,NUMERIC,INTEGER,TEXT,UUID) TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
