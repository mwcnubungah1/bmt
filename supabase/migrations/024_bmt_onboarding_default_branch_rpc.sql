BEGIN;

CREATE OR REPLACE FUNCTION bmt_db.onboarding_default_branch()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
    SELECT b.id
    FROM bmt_db.branches b
    WHERE b.is_active = TRUE
    ORDER BY b.code
    LIMIT 1;
$function$;

REVOKE ALL ON FUNCTION bmt_db.onboarding_default_branch() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.onboarding_default_branch() TO authenticated;

COMMIT;
