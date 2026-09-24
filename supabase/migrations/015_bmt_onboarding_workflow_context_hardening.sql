-- ============================================================
-- BMT CORE BANKING SYSTEM
-- Migration 015
-- Onboarding Workflow Context Hardening
--
-- Problem:
-- Migration 013 used:
--
--   set_config('bmt.onboarding_workflow', '1', TRUE)
--
-- TRUE makes the setting transaction-local, not function-local.
-- The value therefore leaked into subsequent statements in the
-- same transaction and could cause onboarding_application_guard()
-- to treat unrelated direct edits as trusted workflow operations.
--
-- Fix:
-- 1. Save previous workflow context.
-- 2. Enable internal context only around the parent version bump.
-- 3. Restore previous context immediately afterward.
-- 4. Restore it on exceptions as well.
-- 5. Signature invalidation runs after context restoration.
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
    v_status bmt_db.onboarding_status;

    -- Missing custom setting returns NULL.
    v_previous_workflow TEXT :=
        current_setting(
            'bmt.onboarding_workflow',
            TRUE
        );
BEGIN

    -- --------------------------------------------------------
    -- Resolve parent application.
    -- --------------------------------------------------------

    IF TG_OP = 'DELETE' THEN
        v_application_id := OLD.application_id;
    ELSE
        v_application_id := NEW.application_id;
    END IF;


    -- --------------------------------------------------------
    -- Lock and validate parent.
    -- --------------------------------------------------------

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
    -- Scoped trusted workflow context.
    --
    -- The parent version bump changes form_version, which is a
    -- workflow-controlled field. The application guard must
    -- allow exactly this internal UPDATE.
    --
    -- IMPORTANT:
    -- set_config(..., TRUE) is transaction-local. Therefore the
    -- previous value MUST be restored explicitly.
    -- --------------------------------------------------------

    BEGIN

        PERFORM set_config(
            'bmt.onboarding_workflow',
            '1',
            TRUE
        );


        UPDATE bmt_db.onboarding_applications
           SET form_version = form_version + 1,
               updated_at = now()
         WHERE id = v_application_id;


        -- Restore the exact previous logical state.
        --
        -- PostgreSQL custom GUCs cannot truly be "unset" again
        -- after creation in the current session. Empty string is
        -- therefore used to represent the previous unset state.
        PERFORM set_config(
            'bmt.onboarding_workflow',
            COALESCE(v_previous_workflow, ''),
            TRUE
        );

    EXCEPTION
        WHEN OTHERS THEN

            -- Never allow trusted workflow context to leak when
            -- the internal UPDATE fails.
            PERFORM set_config(
                'bmt.onboarding_workflow',
                COALESCE(v_previous_workflow, ''),
                TRUE
            );

            RAISE;
    END;


    -- --------------------------------------------------------
    -- Invalidate signatures only after trusted context has
    -- already been restored.
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


REVOKE ALL
ON FUNCTION bmt_db.touch_onboarding_material_change()
FROM PUBLIC, anon, authenticated;


COMMENT ON FUNCTION bmt_db.touch_onboarding_material_change() IS
'Internal onboarding child material-change handler. Uses scoped workflow context, increments parent form_version, restores prior context including on exceptions, then invalidates existing signatures.';


COMMIT;
