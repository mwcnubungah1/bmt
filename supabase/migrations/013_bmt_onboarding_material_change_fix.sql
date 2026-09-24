-- ============================================================
-- BMT CORE BANKING SYSTEM
-- Migration 013
-- Fix Onboarding Material Change Versioning
--
-- Problem discovered by 012 regression:
--
-- Child material-change trigger:
--   touch_onboarding_material_change()
--
-- legitimately updates:
--   onboarding_applications.form_version
--
-- but:
--   onboarding_application_guard()
--
-- rejects that internal update as if it were a direct
-- client-side workflow-field modification.
--
-- Fix:
--   Mark ONLY the internal parent version update as an
--   onboarding workflow operation.
--
-- Security behavior remains:
-- - direct authenticated updates to form_version are rejected
-- - child edits only allowed while DRAFT / RETURNED
-- - material child edits increment form_version
-- - existing signatures are invalidated
-- ============================================================

BEGIN;


CREATE OR REPLACE FUNCTION bmt_db.touch_onboarding_material_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_application_id UUID;
    v_status         bmt_db.onboarding_status;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_application_id := OLD.application_id;
    ELSE
        v_application_id := NEW.application_id;
    END IF;

    SELECT oa.status
      INTO v_status
      FROM bmt_db.onboarding_applications oa
     WHERE oa.id = v_application_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Onboarding application % not found',
            v_application_id;
    END IF;

    IF v_status NOT IN ('DRAFT', 'RETURNED') THEN
        RAISE EXCEPTION
            'Application % cannot be edited in status %',
            v_application_id,
            v_status;
    END IF;

    -- --------------------------------------------------------
    -- IMPORTANT
    --
    -- This update is an INTERNAL system-controlled version
    -- bump caused by a material child-record change.
    --
    -- onboarding_application_guard() must therefore allow this
    -- specific workflow-controlled update.
    --
    -- set_config(..., TRUE) is transaction-local.
    -- --------------------------------------------------------

    PERFORM set_config(
        'bmt.onboarding_workflow',
        '1',
        TRUE
    );

    UPDATE bmt_db.onboarding_applications
       SET form_version = form_version + 1,
           updated_at = now()
     WHERE id = v_application_id;

    -- --------------------------------------------------------
    -- Invalidate every currently-valid signature because the
    -- signed form version no longer represents current data.
    -- --------------------------------------------------------

    PERFORM bmt_db.invalidate_onboarding_signatures(
        v_application_id,
        'FORM_CHANGED'
    );

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$$;


-- Internal trigger function remains inaccessible directly
-- from API roles.

REVOKE ALL
ON FUNCTION bmt_db.touch_onboarding_material_change()
FROM PUBLIC, anon, authenticated;


COMMENT ON FUNCTION bmt_db.touch_onboarding_material_change() IS
'Internal onboarding child material-change handler. Increments parent form_version under workflow context and invalidates existing signatures.';


COMMIT;
