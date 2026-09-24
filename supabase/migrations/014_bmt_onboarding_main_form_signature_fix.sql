-- ============================================================
-- BMT CORE BANKING SYSTEM
-- Migration 014
-- Onboarding Main Form Signature Invalidation Fix
--
-- Regression finding:
-- Direct material changes on onboarding_applications were
-- allowed and form_version changed, but existing signatures
-- were not invalidated.
--
-- Invariants:
-- 1. Workflow fields cannot be changed directly.
-- 2. Material form edits are allowed only DRAFT / RETURNED.
-- 3. Material form edits increment form_version exactly once.
-- 4. Material form edits invalidate existing valid signatures.
-- 5. Internal workflow operations remain compatible with
--    Migration 012/013.
-- ============================================================

BEGIN;


CREATE OR REPLACE FUNCTION bmt_db.onboarding_application_guard()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_workflow BOOLEAN :=
        COALESCE(
            current_setting(
                'bmt.onboarding_workflow',
                TRUE
            ),
            '0'
        ) = '1';

    v_material_changed BOOLEAN := FALSE;
BEGIN

    -- ========================================================
    -- INTERNAL WORKFLOW OPERATION
    --
    -- Trusted RPC/internal functions set:
    --   bmt.onboarding_workflow = 1
    --
    -- Migration 013 also uses this context when a child-table
    -- material change bumps the parent form_version.
    -- ========================================================

    IF v_workflow THEN
        NEW.updated_at := now();
        RETURN NEW;
    END IF;


    -- ========================================================
    -- PROTECT WORKFLOW-CONTROLLED FIELDS
    -- ========================================================

    IF NEW.status IS DISTINCT FROM OLD.status
       OR NEW.form_version IS DISTINCT FROM OLD.form_version
       OR NEW.submitted_at IS DISTINCT FROM OLD.submitted_at
       OR NEW.teller_reviewed_by IS DISTINCT FROM OLD.teller_reviewed_by
       OR NEW.teller_reviewed_at IS DISTINCT FROM OLD.teller_reviewed_at
       OR NEW.manager_reviewed_by IS DISTINCT FROM OLD.manager_reviewed_by
       OR NEW.manager_reviewed_at IS DISTINCT FROM OLD.manager_reviewed_at
       OR NEW.approved_at IS DISTINCT FROM OLD.approved_at
       OR NEW.return_reason IS DISTINCT FROM OLD.return_reason
       OR NEW.rejection_reason IS DISTINCT FROM OLD.rejection_reason
       OR NEW.customer_id IS DISTINCT FROM OLD.customer_id
       OR NEW.completed_at IS DISTINCT FROM OLD.completed_at
       OR NEW.created_by IS DISTINCT FROM OLD.created_by
       OR NEW.created_at IS DISTINCT FROM OLD.created_at
    THEN
        RAISE EXCEPTION
            'Workflow-controlled onboarding fields cannot be changed directly';
    END IF;


    -- ========================================================
    -- DETECT MATERIAL FORM CHANGE
    --
    -- Every applicant/business field in the current
    -- onboarding_applications schema is covered here.
    --
    -- Excluded intentionally:
    --   id
    --   status/workflow metadata
    --   form_version
    --   created_by
    --   created_at
    --   updated_at
    -- ========================================================

    v_material_changed :=
        ROW(
            NEW.branch_id,
            NEW.applicant_user_id,
            NEW.nik,
            NEW.full_name,
            NEW.birth_place,
            NEW.birth_date,
            NEW.gender,
            NEW.marital_status,
            NEW.mother_name,
            NEW.identity_type,
            NEW.identity_expired_at,
            NEW.nationality,
            NEW.religion,
            NEW.education,
            NEW.npwp,
            NEW.phone,
            NEW.email,
            NEW.occupation,
            NEW.employer_name,
            NEW.position_name,
            NEW.monthly_income,
            NEW.monthly_expense,
            NEW.source_of_funds,
            NEW.purpose_of_account,
            NEW.emergency_contact_name,
            NEW.emergency_contact_phone,
            NEW.emergency_relationship
        )
        IS DISTINCT FROM
        ROW(
            OLD.branch_id,
            OLD.applicant_user_id,
            OLD.nik,
            OLD.full_name,
            OLD.birth_place,
            OLD.birth_date,
            OLD.gender,
            OLD.marital_status,
            OLD.mother_name,
            OLD.identity_type,
            OLD.identity_expired_at,
            OLD.nationality,
            OLD.religion,
            OLD.education,
            OLD.npwp,
            OLD.phone,
            OLD.email,
            OLD.occupation,
            OLD.employer_name,
            OLD.position_name,
            OLD.monthly_income,
            OLD.monthly_expense,
            OLD.source_of_funds,
            OLD.purpose_of_account,
            OLD.emergency_contact_name,
            OLD.emergency_contact_phone,
            OLD.emergency_relationship
        );


    -- ========================================================
    -- NO MATERIAL CHANGE
    --
    -- Example: harmless update that only touches updated_at.
    -- ========================================================

    IF NOT v_material_changed THEN
        NEW.updated_at := now();
        RETURN NEW;
    END IF;


    -- ========================================================
    -- MATERIAL EDITABILITY
    -- ========================================================

    IF OLD.status NOT IN ('DRAFT', 'RETURNED') THEN
        RAISE EXCEPTION
            'Application % cannot be edited in status %',
            OLD.id,
            OLD.status;
    END IF;


    -- ========================================================
    -- VERSION BUMP
    --
    -- Direct material edit creates a new logical form version.
    -- ========================================================

    NEW.form_version := OLD.form_version + 1;
    NEW.updated_at := now();


    -- ========================================================
    -- SIGNATURE INVALIDATION
    --
    -- Any currently-valid signature belongs to the previous
    -- form version and must no longer authorize current data.
    -- ========================================================

    PERFORM bmt_db.invalidate_onboarding_signatures(
        OLD.id,
        'FORM_CHANGED'
    );


    RETURN NEW;
END;
$$;


-- Trigger guard is internal infrastructure, never a public RPC.

REVOKE ALL
ON FUNCTION bmt_db.onboarding_application_guard()
FROM PUBLIC, anon, authenticated;


COMMENT ON FUNCTION bmt_db.onboarding_application_guard() IS
'Protects onboarding workflow fields. Direct material edits in DRAFT/RETURNED increment form_version and invalidate previous signatures; trusted workflow operations use bmt.onboarding_workflow context.';


COMMIT;
