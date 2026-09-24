BEGIN;

CREATE OR REPLACE FUNCTION bmt_db.save_onboarding_draft(p_data jsonb, p_id uuid DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
DECLARE v_id uuid; v_branch uuid;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Login diperlukan'; END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(auth.uid()::text, 26));
 IF p_id IS NULL THEN
   SELECT id INTO v_id FROM bmt_db.onboarding_applications
   WHERE applicant_user_id=auth.uid() AND status IN ('DRAFT','RETURNED') ORDER BY created_at DESC LIMIT 1 FOR UPDATE;
 ELSE
   SELECT id INTO v_id FROM bmt_db.onboarding_applications
   WHERE id=p_id AND applicant_user_id=auth.uid() AND status IN ('DRAFT','RETURNED') FOR UPDATE;
   IF v_id IS NULL THEN RAISE EXCEPTION 'Draft tidak dapat diubah'; END IF;
 END IF;
 IF v_id IS NULL THEN
   v_branch := bmt_db.onboarding_default_branch();
   IF v_branch IS NULL THEN RAISE EXCEPTION 'Cabang belum tersedia'; END IF;
   INSERT INTO bmt_db.onboarding_applications(branch_id,applicant_user_id) VALUES(v_branch,auth.uid()) RETURNING id INTO v_id;
 END IF;
 UPDATE bmt_db.onboarding_applications SET
 full_name=nullif(btrim(p_data->>'fullName'),''), nik=nullif(p_data->>'nik',''), birth_place=nullif(p_data->>'birthPlace',''),
 birth_date=nullif(p_data->>'birthDate','')::date, gender=nullif(p_data->>'gender','')::bmt_db.gender_type,
 mother_name=nullif(p_data->>'motherName',''), nationality=coalesce(nullif(p_data->>'nationality',''),'INDONESIA'),
 identity_type=coalesce(nullif(p_data->>'identityType',''),'KTP'), religion=nullif(p_data->>'religion',''),
 education=nullif(p_data->>'education',''), marital_status=nullif(p_data->>'maritalStatus',''),
 phone=nullif(p_data->>'phone',''), occupation=nullif(p_data->>'occupation',''),
 monthly_income=nullif(p_data->>'monthlyIncome','')::numeric, source_of_funds=nullif(p_data->>'sourceOfFunds',''),
 purpose_of_account=nullif(p_data->>'purpose','') WHERE id=v_id;
 UPDATE bmt_db.onboarding_addresses SET address=coalesce(nullif(p_data->>'address',''),'-'),province=nullif(p_data->>'province',''),city=nullif(p_data->>'city',''),district=nullif(p_data->>'district',''),village=nullif(p_data->>'village',''),postal_code=nullif(p_data->>'postalCode',''),rt=nullif(p_data->>'rt',''),rw=nullif(p_data->>'rw',''),is_primary=true
 WHERE application_id=v_id AND address_type='ID_CARD';
 IF NOT FOUND THEN
   INSERT INTO bmt_db.onboarding_addresses(application_id,address_type,address,province,city,district,village,postal_code,rt,rw,is_primary)
   VALUES(v_id,'ID_CARD',coalesce(nullif(p_data->>'address',''),'-'),nullif(p_data->>'province',''),nullif(p_data->>'city',''),nullif(p_data->>'district',''),nullif(p_data->>'village',''),nullif(p_data->>'postalCode',''),nullif(p_data->>'rt',''),nullif(p_data->>'rw',''),true);
 END IF;
 INSERT INTO bmt_db.onboarding_employment(application_id,employment_type,occupation,monthly_income,income_source_detail)
 VALUES(v_id,nullif(p_data->>'employmentType',''),nullif(p_data->>'occupation',''),nullif(p_data->>'monthlyIncome','')::numeric,nullif(p_data->>'sourceOfFunds',''))
 ON CONFLICT (application_id) DO UPDATE SET employment_type=excluded.employment_type,occupation=excluded.occupation,monthly_income=excluded.monthly_income,income_source_detail=excluded.income_source_detail;
 INSERT INTO bmt_db.onboarding_financial_profiles(application_id,monthly_income,source_of_funds,transaction_purpose)
 VALUES(v_id,nullif(p_data->>'monthlyIncome','')::numeric,nullif(p_data->>'sourceOfFunds',''),nullif(p_data->>'purpose',''))
 ON CONFLICT (application_id) DO UPDATE SET monthly_income=excluded.monthly_income,source_of_funds=excluded.source_of_funds,transaction_purpose=excluded.transaction_purpose;
 RETURN v_id;
END; $$;

REVOKE ALL ON FUNCTION bmt_db.save_onboarding_draft(jsonb,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION bmt_db.save_onboarding_draft(jsonb,uuid) TO authenticated;

INSERT INTO storage.buckets (id, name, public)
VALUES ('onboarding-documents', 'onboarding-documents', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS onboarding_documents_storage_insert ON storage.objects;
CREATE POLICY onboarding_documents_storage_insert ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'onboarding-documents' AND (storage.foldername(name))[1] = auth.uid()::text);
DROP POLICY IF EXISTS onboarding_documents_storage_select ON storage.objects;
CREATE POLICY onboarding_documents_storage_select ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'onboarding-documents' AND (storage.foldername(name))[1] = auth.uid()::text);
DROP POLICY IF EXISTS onboarding_documents_storage_update ON storage.objects;
CREATE POLICY onboarding_documents_storage_update ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'onboarding-documents' AND (storage.foldername(name))[1] = auth.uid()::text)
WITH CHECK (bucket_id = 'onboarding-documents' AND (storage.foldername(name))[1] = auth.uid()::text);

NOTIFY pgrst, 'reload schema';
COMMIT;
