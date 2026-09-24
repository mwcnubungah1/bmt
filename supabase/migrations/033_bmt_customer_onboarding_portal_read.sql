-- Customer portal read access for the applicant's own onboarding status.

CREATE OR REPLACE FUNCTION bmt_db.portal_get_onboarding_applications()
RETURNS TABLE (
    id UUID,
    status TEXT,
    form_version INTEGER,
    full_name VARCHAR,
    nik VARCHAR,
    submitted_at TIMESTAMPTZ,
    return_reason TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
    SELECT oa.id,
           oa.status::TEXT,
           oa.form_version,
           oa.full_name,
           oa.nik,
           oa.submitted_at,
           oa.return_reason,
           oa.created_at,
           oa.updated_at
    FROM bmt_db.onboarding_applications oa
    WHERE auth.uid() IS NOT NULL
      AND oa.applicant_user_id = auth.uid()
    ORDER BY oa.created_at DESC;
$function$;

REVOKE ALL ON FUNCTION bmt_db.portal_get_onboarding_applications() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.portal_get_onboarding_applications() TO authenticated;

COMMENT ON FUNCTION bmt_db.portal_get_onboarding_applications() IS
'Customer portal read-only view of the authenticated applicant own onboarding applications.';
