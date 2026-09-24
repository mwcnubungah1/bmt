BEGIN;

CREATE OR REPLACE FUNCTION bmt_db.save_onboarding_draft(p_data jsonb, p_id uuid DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
DECLARE v_id uuid; v_branch uuid;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Login diperlukan'; END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(auth.uid()::text, 26));
 IF p_id IS NULL THEN
   SELECT id INTO v_id FROM bmt_db.onboarding_applications
   WHERE applicant_user_id=auth.uid() AND status IN ('DRAFT','RETURNED')
   ORDER BY created_at DESC LIMIT 1 FOR UPDATE;
 ELSE
   SELECT id INTO v_id FROM bmt_db.onboarding_applications
   WHERE id=p_id AND applicant_user_id=auth.uid() AND status IN ('DRAFT','RETURNED') FOR UPDATE;
   IF v_id IS NULL THEN RAISE EXCEPTION 'Draft tidak dapat diubah'; END IF;
 END IF;
 IF v_id IS NULL THEN
   v_branch := bmt_db.onboarding_default_branch();
   IF v_branch IS NULL THEN RAISE EXCEPTION 'Cabang belum tersedia'; END IF;
   INSERT INTO bmt_db.onboarding_applications(branch_id,applicant_user_id)
   VALUES(v_branch,auth.uid()) RETURNING id INTO v_id;
 END IF;
 UPDATE bmt_db.onboarding_applications SET
 full_name=nullif(btrim(p_data->>'fullName'),''),nik=nullif(p_data->>'nik',''),
 birth_place=nullif(p_data->>'birthPlace',''),birth_date=nullif(p_data->>'birthDate','')::date,
 gender=nullif(p_data->>'gender','')::bmt_db.gender_type,
 phone=nullif(p_data->>'phone',''),occupation=nullif(p_data->>'occupation',''),
 monthly_income=nullif(p_data->>'monthlyIncome','')::numeric,
 purpose_of_account=nullif(p_data->>'purpose','') WHERE id=v_id;
 UPDATE bmt_db.onboarding_addresses SET address=p_data->>'address'
 WHERE application_id=v_id AND address_type='ID_CARD';
 IF NOT FOUND THEN
   INSERT INTO bmt_db.onboarding_addresses(application_id,address_type,address,is_primary)
   VALUES(v_id,'ID_CARD',p_data->>'address',true);
 END IF;
 RETURN v_id;
END; $$;

REVOKE ALL ON FUNCTION bmt_db.save_onboarding_draft(jsonb,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION bmt_db.save_onboarding_draft(jsonb,uuid) TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
