BEGIN;

CREATE TABLE IF NOT EXISTS bmt_db.loan_application_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  loan_application_id uuid NOT NULL REFERENCES bmt_db.loan_applications(id) ON DELETE CASCADE,
  customer_id uuid NOT NULL REFERENCES bmt_db.customers(id) ON DELETE RESTRICT,
  requirement_code text NOT NULL,
  document_name text NOT NULL,
  storage_bucket text NOT NULL DEFAULT 'loan-documents',
  storage_path text NOT NULL,
  mime_type text NOT NULL,
  file_size_bytes bigint NOT NULL CHECK (file_size_bytes > 0 AND file_size_bytes <= 5242880),
  status text NOT NULL DEFAULT 'UPLOADED' CHECK (status IN ('UPLOADED','VERIFIED','REJECTED')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (loan_application_id, requirement_code)
);

ALTER TABLE bmt_db.loan_application_documents ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE ON bmt_db.loan_application_documents TO authenticated;

INSERT INTO storage.buckets (id, name, public)
VALUES ('loan-documents', 'loan-documents', false)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY loan_documents_insert_own ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'loan-documents' AND (storage.foldername(name))[1] = (select auth.uid()::text));

CREATE POLICY loan_documents_select_own ON storage.objects
FOR SELECT TO authenticated
USING (bucket_id = 'loan-documents' AND (storage.foldername(name))[1] = (select auth.uid()::text));

CREATE OR REPLACE FUNCTION bmt_db.customer_upload_loan_document(
  p_loan_application_id uuid,
  p_requirement_code text,
  p_document_name text,
  p_storage_bucket text,
  p_storage_path text,
  p_mime_type text,
  p_file_size_bytes bigint
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = bmt_db, public
AS $$
DECLARE v_customer_id uuid; v_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sesi pengguna tidak ditemukan'; END IF;
  IF p_storage_bucket <> 'loan-documents' OR split_part(p_storage_path, '/', 1) <> auth.uid()::text THEN RAISE EXCEPTION 'Lokasi dokumen tidak valid'; END IF;
  IF p_mime_type NOT IN ('application/pdf','image/jpeg','image/png') THEN RAISE EXCEPTION 'Jenis dokumen tidak didukung'; END IF;
  IF p_file_size_bytes <= 0 OR p_file_size_bytes > 5242880 THEN RAISE EXCEPTION 'Ukuran dokumen maksimal 5 MB'; END IF;
  SELECT c.id INTO v_customer_id FROM customers c WHERE c.user_id = auth.uid() LIMIT 1;
  IF v_customer_id IS NULL OR NOT EXISTS (SELECT 1 FROM loan_applications a WHERE a.id = p_loan_application_id AND a.customer_id = v_customer_id) THEN RAISE EXCEPTION 'Pengajuan tidak ditemukan'; END IF;
  INSERT INTO loan_application_documents (loan_application_id, customer_id, requirement_code, document_name, storage_bucket, storage_path, mime_type, file_size_bytes)
  VALUES (p_loan_application_id, v_customer_id, p_requirement_code, p_document_name, p_storage_bucket, p_storage_path, p_mime_type, p_file_size_bytes)
  ON CONFLICT (loan_application_id, requirement_code) DO UPDATE SET document_name = EXCLUDED.document_name, storage_path = EXCLUDED.storage_path, mime_type = EXCLUDED.mime_type, file_size_bytes = EXCLUDED.file_size_bytes, status = 'UPLOADED', updated_at = now()
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION bmt_db.customer_upload_loan_document(uuid,text,text,text,text,text,bigint) TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
