BEGIN;

INSERT INTO storage.buckets (id, name, public)
VALUES
  ('onboarding-documents', 'onboarding-documents', false),
  ('demo-signatures', 'demo-signatures', false)
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public;

DROP POLICY IF EXISTS onboarding_documents_storage_insert ON storage.objects;
CREATE POLICY onboarding_documents_storage_insert ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id IN ('onboarding-documents', 'demo-signatures') AND (storage.foldername(name))[1] = auth.uid()::text);
DROP POLICY IF EXISTS onboarding_documents_storage_select ON storage.objects;
CREATE POLICY onboarding_documents_storage_select ON storage.objects FOR SELECT TO authenticated
USING (bucket_id IN ('onboarding-documents', 'demo-signatures') AND (storage.foldername(name))[1] = auth.uid()::text);
DROP POLICY IF EXISTS onboarding_documents_storage_update ON storage.objects;
CREATE POLICY onboarding_documents_storage_update ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id IN ('onboarding-documents', 'demo-signatures') AND (storage.foldername(name))[1] = auth.uid()::text)
WITH CHECK (bucket_id IN ('onboarding-documents', 'demo-signatures') AND (storage.foldername(name))[1] = auth.uid()::text);

COMMIT;
