BEGIN;

-- Storage paths are owned by the applicant, but an onboarding record can be
-- reviewed by an authorized branch staff member. Keep the database helper as
-- the single authorization decision for both customers and staff.
DROP POLICY IF EXISTS onboarding_documents_storage_select ON storage.objects;
CREATE POLICY onboarding_documents_storage_select ON storage.objects
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM bmt_db.onboarding_documents d
        WHERE d.storage_bucket = storage.objects.bucket_id
          AND d.storage_path = storage.objects.name
          AND bmt_db.current_user_can_access_onboarding(d.application_id)
    )
    OR EXISTS (
        SELECT 1
        FROM bmt_db.onboarding_signatures s
        WHERE s.storage_bucket = storage.objects.bucket_id
          AND s.storage_path = storage.objects.name
          AND bmt_db.current_user_can_access_onboarding(s.application_id)
    )
);

CREATE OR REPLACE FUNCTION bmt_db.portal_get_onboarding_documents(p_application_id UUID)
RETURNS TABLE (
    id UUID,
    application_id UUID,
    document_type VARCHAR,
    storage_bucket VARCHAR,
    storage_path TEXT,
    mime_type VARCHAR,
    file_size_bytes BIGINT,
    status TEXT,
    created_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
    SELECT d.id, d.application_id, d.document_type, d.storage_bucket,
           d.storage_path, d.mime_type, d.file_size_bytes,
           d.status::TEXT, d.created_at
    FROM bmt_db.onboarding_documents d
    WHERE d.application_id = p_application_id
      AND EXISTS (
          SELECT 1
          FROM bmt_db.onboarding_applications oa
          WHERE oa.id = d.application_id
            AND oa.applicant_user_id = auth.uid()
      );
$function$;

REVOKE ALL ON FUNCTION bmt_db.portal_get_onboarding_documents(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.portal_get_onboarding_documents(UUID) TO authenticated;

COMMIT;
