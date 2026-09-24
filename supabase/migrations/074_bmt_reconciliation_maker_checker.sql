BEGIN;

ALTER TABLE bmt_db.daily_reconciliation_runs
  ADD COLUMN IF NOT EXISTS branch_id UUID REFERENCES bmt_db.branches(id),
  ADD COLUMN IF NOT EXISTS pillar1_transaction_journal NUMERIC(18,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS pillar2_teller_journal NUMERIC(18,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS pillar3_subledger_gl NUMERIC(18,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS pillar4_physical_system NUMERIC(18,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES bmt_db.user_profiles(id),
  ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ;

CREATE UNIQUE INDEX IF NOT EXISTS uq_daily_reconciliation_approved_branch_date
  ON bmt_db.daily_reconciliation_runs(branch_id, run_date)
  WHERE status = 'APPROVED' AND approved_by IS NOT NULL;

CREATE OR REPLACE FUNCTION bmt_db.run_daily_reconciliation(
  p_run_date DATE DEFAULT CURRENT_DATE,
  p_branch_id UUID DEFAULT NULL
) RETURNS bmt_db.daily_reconciliation_runs
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE r bmt_db.daily_reconciliation_runs; v_p1 NUMERIC := 0; v_p2 NUMERIC := 0; v_p3 NUMERIC := 0; v_p4 NUMERIC := 0;
BEGIN
  IF auth.uid() IS NOT NULL AND NOT (bmt_db.current_user_is_superadmin() OR bmt_db.current_user_has_role('MANAGER', p_branch_id)) THEN
    RAISE EXCEPTION 'Manager reconciliation access required';
  END IF;
  SELECT COALESCE(SUM(ABS(t.amount - COALESCE(j.total_journal,0))),0)
    INTO v_p1
  FROM bmt_db.transactions t
  LEFT JOIN (SELECT je.transaction_id, SUM(jl.debit) AS total_journal FROM bmt_db.journal_entries je JOIN bmt_db.journal_lines jl ON jl.journal_entry_id=je.id WHERE je.status='POSTED' GROUP BY je.transaction_id) j ON j.transaction_id=t.id
  WHERE t.status='POSTED' AND t.posted_at::date=p_run_date AND (p_branch_id IS NULL OR t.branch_id=p_branch_id);
  SELECT COALESCE(SUM(ABS(COALESCE(m.cash_total,0)-COALESCE(j.cash_total,0))),0)
    INTO v_p2
  FROM (SELECT s.id, SUM(CASE WHEN m.movement_type IN ('CASH_IN','TRANSFER_IN') THEN m.amount ELSE -m.amount END) cash_total FROM bmt_db.teller_cash_sessions s LEFT JOIN bmt_db.teller_cash_movements m ON m.cash_session_id=s.id WHERE s.business_date=p_run_date AND (p_branch_id IS NULL OR s.branch_id=p_branch_id) GROUP BY s.id) m
  FULL JOIN (SELECT t.teller_session_id id, SUM(jl.debit-jl.credit) cash_total FROM bmt_db.transactions t JOIN bmt_db.journal_entries je ON je.transaction_id=t.id AND je.status='POSTED' JOIN bmt_db.journal_lines jl ON jl.journal_entry_id=je.id JOIN bmt_db.chart_of_accounts coa ON coa.id=jl.coa_id WHERE t.posted_at::date=p_run_date AND t.teller_session_id IS NOT NULL AND coa.code='1.01.001' GROUP BY t.teller_session_id) j USING(id);
  SELECT ABS(COALESCE((SELECT SUM(sa.current_balance) FROM bmt_db.savings_accounts sa JOIN bmt_db.financial_accounts fa ON fa.id=sa.financial_account_id WHERE fa.status IN ('ACTIVE','DORMANT') AND (p_branch_id IS NULL OR fa.branch_id=p_branch_id)),0)-COALESCE((SELECT SUM(jl.credit-jl.debit) FROM bmt_db.journal_lines jl JOIN bmt_db.journal_entries je ON je.id=jl.journal_entry_id AND je.status='POSTED' JOIN bmt_db.chart_of_accounts coa ON coa.id=jl.coa_id WHERE coa.account_type='LIABILITY' AND (p_branch_id IS NULL OR je.branch_id=p_branch_id)),0)) INTO v_p3;
  SELECT COALESCE(SUM(ABS(COALESCE(s.physical_closing_balance,0)-COALESCE(s.system_closing_balance,s.opening_balance+COALESCE(m.net_movement,0)))),0) INTO v_p4
  FROM bmt_db.teller_cash_sessions s LEFT JOIN (SELECT cash_session_id,SUM(CASE WHEN movement_type IN ('CASH_IN','TRANSFER_IN') THEN amount ELSE -amount END) net_movement FROM bmt_db.teller_cash_movements GROUP BY cash_session_id) m ON m.cash_session_id=s.id
  WHERE s.business_date=p_run_date AND s.status='CLOSED' AND (p_branch_id IS NULL OR s.branch_id=p_branch_id);
  INSERT INTO bmt_db.daily_reconciliation_runs(run_date,branch_id,transaction_count,posted_amount,debit_total,credit_total,variance,status,notes,pillar1_transaction_journal,pillar2_teller_journal,pillar3_subledger_gl,pillar4_physical_system)
  SELECT p_run_date,p_branch_id,COUNT(t.id),COALESCE(SUM(t.amount),0),COALESCE(SUM(j.debit),0),COALESCE(SUM(j.credit),0),v_p1+v_p2+v_p3+v_p4,CASE WHEN v_p1+v_p2+v_p3+v_p4=0 THEN 'BALANCED' ELSE 'EXCEPTION' END,format('P1=%s; P2=%s; P3=%s; P4=%s',v_p1,v_p2,v_p3,v_p4),v_p1,v_p2,v_p3,v_p4
  FROM bmt_db.transactions t LEFT JOIN (SELECT je.transaction_id,SUM(jl.debit) debit,SUM(jl.credit) credit FROM bmt_db.journal_entries je JOIN bmt_db.journal_lines jl ON jl.journal_entry_id=je.id WHERE je.status='POSTED' GROUP BY je.transaction_id) j ON j.transaction_id=t.id
  WHERE t.status='POSTED' AND t.posted_at::date=p_run_date AND (p_branch_id IS NULL OR t.branch_id=p_branch_id) RETURNING * INTO r;
  RETURN r;
END; $$;

CREATE OR REPLACE FUNCTION bmt_db.approve_daily_reconciliation(p_run_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_run bmt_db.daily_reconciliation_runs%ROWTYPE; v_user UUID := auth.uid();
BEGIN
  SELECT * INTO v_run FROM bmt_db.daily_reconciliation_runs WHERE id=p_run_id FOR UPDATE;
  IF NOT FOUND OR v_run.status <> 'BALANCED' THEN RAISE EXCEPTION 'Only a balanced reconciliation can be approved'; END IF;
  IF NOT (bmt_db.current_user_is_superadmin() OR bmt_db.current_user_has_role('MANAGER',v_run.branch_id)) THEN RAISE EXCEPTION 'Manager approval required'; END IF;
  UPDATE bmt_db.daily_reconciliation_runs SET status='APPROVED',approved_by=v_user,approved_at=now() WHERE id=p_run_id;
END; $$;

-- New products are drafts. Approval must be performed by a different manager.
CREATE OR REPLACE FUNCTION bmt_db.manager_create_murabahah_product(
  p_code TEXT,p_name TEXT,p_loan_code TEXT,p_minimum_principal NUMERIC,p_maximum_principal NUMERIC,p_tenor_options INTEGER[],p_margin_rate NUMERIC,p_admin_fee_type TEXT DEFAULT 'FIXED',p_admin_fee_value NUMERIC DEFAULT 0,p_terms_and_conditions TEXT DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_user UUID:=auth.uid(); v_product UUID;
BEGIN
  IF v_user IS NULL OR NOT (bmt_db.current_user_is_superadmin() OR bmt_db.current_user_has_role('MANAGER',NULL)) THEN RAISE EXCEPTION 'Manager access required'; END IF;
  IF p_minimum_principal<=0 OR p_maximum_principal<p_minimum_principal OR p_margin_rate<0 OR p_admin_fee_value<0 OR cardinality(p_tenor_options)=0 THEN RAISE EXCEPTION 'Konfigurasi produk tidak valid'; END IF;
  INSERT INTO bmt_db.products(code,name,category,is_active,description,terms_and_conditions,created_by) VALUES(upper(btrim(p_code)),btrim(p_name),'LOAN',FALSE,'Pembiayaan murabahah',p_terms_and_conditions,v_user) RETURNING id INTO v_product;
  INSERT INTO bmt_db.loan_products(product_id,loan_code,akad_code,calculation_method,margin_type,margin_rate,minimum_principal,maximum_principal,minimum_tenor_months,maximum_tenor_months,tenor_options,installment_frequency,admin_fee_type,admin_fee_value) VALUES(v_product,btrim(p_loan_code),'MURABAHAH','FLAT','PERCENTAGE',p_margin_rate,p_minimum_principal,p_maximum_principal,(SELECT min(x) FROM unnest(p_tenor_options)x),(SELECT max(x) FROM unnest(p_tenor_options)x),p_tenor_options,'MONTHLY',p_admin_fee_type,p_admin_fee_value);
  INSERT INTO bmt_db.loan_product_versions(loan_product_id,version_number,margin_rate,minimum_principal,maximum_principal,tenor_options,admin_fee_value,status,approved_by) VALUES(v_product,1,p_margin_rate,p_minimum_principal,p_maximum_principal,p_tenor_options,p_admin_fee_value,'DRAFT',NULL);
  INSERT INTO bmt_db.loan_product_requirements(loan_product_id,requirement_code,requirement_name,description,sort_order) VALUES(v_product,'KTP','KTP','Kartu tanda penduduk pemohon',1),(v_product,'KK','Kartu Keluarga','Kartu keluarga terbaru',2),(v_product,'PURPOSE','Rincian tujuan pembiayaan','Penjelasan penggunaan dana atau barang',3);
  RETURN v_product;
END; $$;

CREATE OR REPLACE FUNCTION bmt_db.manager_approve_murabahah_product(p_product_id UUID)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_user UUID:=auth.uid(); v_creator UUID; v_version UUID;
BEGIN
  IF v_user IS NULL OR NOT (bmt_db.current_user_is_superadmin() OR bmt_db.current_user_has_role('MANAGER',NULL)) THEN RAISE EXCEPTION 'Manager approval required'; END IF;
  SELECT p.created_by,v.id INTO v_creator,v_version FROM bmt_db.products p JOIN bmt_db.loan_product_versions v ON v.loan_product_id=p.id WHERE p.id=p_product_id AND v.status='DRAFT' ORDER BY v.version_number DESC LIMIT 1;
  IF v_version IS NULL THEN RAISE EXCEPTION 'Draft product version not found'; END IF;
  IF v_creator=v_user THEN RAISE EXCEPTION 'Maker cannot approve own product'; END IF;
  UPDATE bmt_db.loan_product_versions SET status='ACTIVE',approved_by=v_user,effective_from=CURRENT_DATE WHERE id=v_version;
  UPDATE bmt_db.products SET is_active=TRUE,updated_at=now() WHERE id=p_product_id;
  RETURN p_product_id;
END; $$;

REVOKE ALL ON FUNCTION bmt_db.run_daily_reconciliation(DATE,UUID), bmt_db.approve_daily_reconciliation(UUID), bmt_db.manager_approve_murabahah_product(UUID) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION bmt_db.run_daily_reconciliation(DATE,UUID), bmt_db.approve_daily_reconciliation(UUID), bmt_db.manager_approve_murabahah_product(UUID) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
