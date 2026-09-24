BEGIN;

-- Keep the existing RPC signature for compatibility, but canonicalize the
-- persisted hash inside the database so the browser cannot choose its value.
CREATE OR REPLACE FUNCTION bmt_db.onboarding_application_signature_hash(
    p_application_id UUID
)
RETURNS TEXT
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT encode(
        extensions.digest(
            convert_to(
                jsonb_build_object(
                    'application_id', oa.id,
                    'form_version', oa.form_version,
                    'status', oa.status,
                    'applicant_user_id', oa.applicant_user_id,
                    'branch_id', oa.branch_id,
                    'nik', oa.nik,
                    'full_name', oa.full_name,
                    'birth_place', oa.birth_place,
                    'birth_date', oa.birth_date,
                    'phone', oa.phone,
                    'email', oa.email,
                    'occupation', oa.occupation,
                    'monthly_income', oa.monthly_income,
                    'purpose_of_account', oa.purpose_of_account,
                    'updated_at', oa.updated_at
                )::text,
                'UTF8'
            ),
            'sha256'
        ),
        'hex'
    )
    FROM bmt_db.onboarding_applications oa
    WHERE oa.id = p_application_id;
$$;

CREATE OR REPLACE FUNCTION bmt_db.apply_canonical_onboarding_signature_hash()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    NEW.signature_sha256 := bmt_db.onboarding_application_signature_hash(NEW.application_id);
    IF NEW.signature_sha256 IS NULL THEN
        RAISE EXCEPTION 'Onboarding application not found for signature';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_canonical_onboarding_signature_hash
ON bmt_db.onboarding_signatures;

CREATE TRIGGER trg_canonical_onboarding_signature_hash
BEFORE INSERT ON bmt_db.onboarding_signatures
FOR EACH ROW
EXECUTE FUNCTION bmt_db.apply_canonical_onboarding_signature_hash();

REVOKE ALL ON FUNCTION bmt_db.onboarding_application_signature_hash(UUID)
FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION bmt_db.apply_canonical_onboarding_signature_hash()
FROM PUBLIC, anon, authenticated;

COMMIT;
