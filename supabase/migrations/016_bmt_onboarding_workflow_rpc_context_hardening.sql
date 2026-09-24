-- ============================================================
-- BMT CORE BANKING SYSTEM
-- Migration 016
-- Onboarding Workflow RPC Context Hardening
--
-- Purpose:
--   Prevent trusted bmt.onboarding_workflow context from leaking
--   beyond public workflow RPC execution in a surrounding
--   transaction.
--
-- Hardened RPCs:
--   1. submit_onboarding_application(uuid)
--   2. complete_teller_onboarding_review(uuid,boolean,text)
--   3. complete_manager_onboarding_review(uuid,boolean,text)
--   4. finalize_onboarding_application(uuid)
--
-- Migration 015 already hardened:
--   touch_onboarding_material_change()
-- ============================================================

BEGIN;

CREATE OR REPLACE FUNCTION bmt_db.submit_onboarding_application(p_application_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_previous_workflow TEXT :=
        current_setting(
            'bmt.onboarding_workflow',
            TRUE
        );
    v_app bmt_db.onboarding_applications%ROWTYPE;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    SELECT *
      INTO v_app
      FROM bmt_db.onboarding_applications
     WHERE id = p_application_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Onboarding application not found';
    END IF;

    IF v_app.applicant_user_id IS DISTINCT FROM auth.uid()
       AND NOT (
           bmt_db.current_user_is_superadmin()
           OR (
               bmt_db.current_user_has_branch_access(
                   v_app.branch_id
               )
               AND bmt_db.current_user_has_permission(
                   'onboarding.create',
                   v_app.branch_id
               )
           )
       ) THEN
        RAISE EXCEPTION
            'Not authorized to submit this application';
    END IF;

    IF v_app.status NOT IN ('DRAFT', 'RETURNED') THEN
        RAISE EXCEPTION
            'Application cannot be submitted from status %',
            v_app.status;
    END IF;

    IF v_app.nik IS NULL
       OR v_app.nik !~ '^[0-9]{16}$'
       OR NULLIF(btrim(v_app.full_name), '') IS NULL
       OR v_app.birth_date IS NULL
       OR v_app.gender IS NULL
       OR NULLIF(btrim(v_app.phone), '') IS NULL THEN
        RAISE EXCEPTION
            'Mandatory identity data is incomplete';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM bmt_db.customers c
        WHERE c.nik = v_app.nik
    ) THEN
        RAISE EXCEPTION
            'NIK is already registered as customer';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM bmt_db.onboarding_applications oa
        WHERE oa.id <> p_application_id
          AND oa.nik = v_app.nik
          AND oa.status IN (
              'TELLER_REVIEW',
              'MANAGER_REVIEW',
              'APPROVED',
              'COMPLETED'
          )
    ) THEN
        RAISE EXCEPTION
            'NIK already has another active onboarding application';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM bmt_db.onboarding_addresses a
        WHERE a.application_id = p_application_id
          AND a.address_type = 'ID_CARD'
    ) THEN
        RAISE EXCEPTION
            'KTP address is required';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM bmt_db.onboarding_documents d
        WHERE d.application_id = p_application_id
          AND d.document_type = 'KTP'
          AND d.status <> 'REJECTED'
    ) THEN
        RAISE EXCEPTION
            'KTP document is required';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM bmt_db.onboarding_product_requests pr
        JOIN bmt_db.products p
          ON p.id = pr.product_id
        WHERE pr.application_id = p_application_id
          AND p.is_active = TRUE
          AND p.effective_from <= CURRENT_DATE
          AND (
              p.effective_until IS NULL
              OR p.effective_until >= CURRENT_DATE
          )
    ) THEN
        RAISE EXCEPTION
            'At least one currently active product is required';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM bmt_db.onboarding_signatures s
        WHERE s.application_id = p_application_id
          AND s.signer_role = 'CUSTOMER'
          AND s.signed_version = v_app.form_version
          AND s.is_valid = TRUE
    ) THEN
        RAISE EXCEPTION
            'Valid customer signature for current form version is required';
    END IF;

    PERFORM set_config(
        'bmt.onboarding_workflow',
        '1',
        TRUE
    );

    UPDATE bmt_db.onboarding_applications
       SET status = 'TELLER_REVIEW',
           submitted_at = now(),
           return_reason = NULL,
           rejection_reason = NULL,
           updated_at = now()
     WHERE id = p_application_id;

    -- Restore trusted workflow context immediately after
    -- the workflow-controlled UPDATE.
    PERFORM set_config(
        'bmt.onboarding_workflow',
        COALESCE(v_previous_workflow, ''),
        TRUE
    );

    INSERT INTO bmt_db.onboarding_status_history (
        application_id,
        from_status,
        to_status,
        changed_by
    )
    VALUES (
        p_application_id,
        v_app.status,
        'TELLER_REVIEW',
        auth.uid()
    );
END;
$function$;

CREATE OR REPLACE FUNCTION bmt_db.complete_teller_onboarding_review(p_application_id uuid, p_approve boolean, p_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_previous_workflow TEXT :=
        current_setting(
            'bmt.onboarding_workflow',
            TRUE
        );
    v_app       bmt_db.onboarding_applications%ROWTYPE;
    v_target    bmt_db.onboarding_status;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    SELECT *
      INTO v_app
      FROM bmt_db.onboarding_applications
     WHERE id = p_application_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Onboarding application not found';
    END IF;

    IF v_app.status <> 'TELLER_REVIEW' THEN
        RAISE EXCEPTION
            'Application is not in TELLER_REVIEW';
    END IF;

    IF NOT (
        bmt_db.current_user_is_superadmin()
        OR (
            bmt_db.current_user_has_branch_access(
                v_app.branch_id
            )
            AND bmt_db.current_user_has_permission(
                'onboarding.teller.verify',
                v_app.branch_id
            )
        )
    ) THEN
        RAISE EXCEPTION
            'Teller verification permission required';
    END IF;

    IF p_approve THEN

        IF NOT EXISTS (
            SELECT 1
            FROM bmt_db.onboarding_signatures s
            WHERE s.application_id = p_application_id
              AND s.signer_role = 'TELLER'
              AND s.signed_version = v_app.form_version
              AND s.is_valid = TRUE
        ) THEN
            RAISE EXCEPTION
                'Valid teller signature for current form version is required';
        END IF;

        v_target := 'MANAGER_REVIEW';

    ELSE

        IF NULLIF(btrim(p_reason), '') IS NULL THEN
            RAISE EXCEPTION
                'Return reason is required';
        END IF;

        v_target := 'RETURNED';

        PERFORM bmt_db.invalidate_onboarding_signatures(
            p_application_id,
            'RETURNED_BY_TELLER'
        );
    END IF;

    PERFORM set_config(
        'bmt.onboarding_workflow',
        '1',
        TRUE
    );

    UPDATE bmt_db.onboarding_applications
       SET status = v_target,
           teller_reviewed_by = auth.uid(),
           teller_reviewed_at = now(),
           return_reason =
               CASE
                   WHEN p_approve THEN NULL
                   ELSE p_reason
               END,
           updated_at = now()
     WHERE id = p_application_id;

    -- Restore trusted workflow context immediately after
    -- the workflow-controlled UPDATE.
    PERFORM set_config(
        'bmt.onboarding_workflow',
        COALESCE(v_previous_workflow, ''),
        TRUE
    );

    INSERT INTO bmt_db.onboarding_status_history (
        application_id,
        from_status,
        to_status,
        changed_by,
        reason
    )
    VALUES (
        p_application_id,
        'TELLER_REVIEW',
        v_target,
        auth.uid(),
        p_reason
    );
END;
$function$;

CREATE OR REPLACE FUNCTION bmt_db.complete_manager_onboarding_review(p_application_id uuid, p_approve boolean, p_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_previous_workflow TEXT :=
        current_setting(
            'bmt.onboarding_workflow',
            TRUE
        );
    v_app       bmt_db.onboarding_applications%ROWTYPE;
    v_target    bmt_db.onboarding_status;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    SELECT *
      INTO v_app
      FROM bmt_db.onboarding_applications
     WHERE id = p_application_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Onboarding application not found';
    END IF;

    IF v_app.status <> 'MANAGER_REVIEW' THEN
        RAISE EXCEPTION
            'Application is not in MANAGER_REVIEW';
    END IF;

    IF NOT (
        bmt_db.current_user_is_superadmin()
        OR (
            bmt_db.current_user_has_branch_access(
                v_app.branch_id
            )
            AND bmt_db.current_user_has_permission(
                'onboarding.manager.approve',
                v_app.branch_id
            )
        )
    ) THEN
        RAISE EXCEPTION
            'Manager approval permission required';
    END IF;

    IF v_app.teller_reviewed_by = auth.uid() THEN
        RAISE EXCEPTION
            'Maker-checker violation: teller and manager must be different users';
    END IF;

    IF p_approve THEN

        IF NOT EXISTS (
            SELECT 1
            FROM bmt_db.onboarding_signatures s
            WHERE s.application_id = p_application_id
              AND s.signer_role = 'CUSTOMER'
              AND s.signed_version = v_app.form_version
              AND s.is_valid = TRUE
        ) THEN
            RAISE EXCEPTION
                'Valid customer signature is required';
        END IF;

        IF NOT EXISTS (
            SELECT 1
            FROM bmt_db.onboarding_signatures s
            WHERE s.application_id = p_application_id
              AND s.signer_role = 'TELLER'
              AND s.signed_version = v_app.form_version
              AND s.is_valid = TRUE
        ) THEN
            RAISE EXCEPTION
                'Valid teller signature is required';
        END IF;

        IF NOT EXISTS (
            SELECT 1
            FROM bmt_db.onboarding_signatures s
            WHERE s.application_id = p_application_id
              AND s.signer_role = 'MANAGER'
              AND s.signed_version = v_app.form_version
              AND s.is_valid = TRUE
        ) THEN
            RAISE EXCEPTION
                'Valid manager signature is required';
        END IF;

        v_target := 'APPROVED';

    ELSE

        IF NULLIF(btrim(p_reason), '') IS NULL THEN
            RAISE EXCEPTION
                'Rejection reason is required';
        END IF;

        v_target := 'REJECTED';

    END IF;

    PERFORM set_config(
        'bmt.onboarding_workflow',
        '1',
        TRUE
    );

    UPDATE bmt_db.onboarding_applications
       SET status = v_target,
           manager_reviewed_by = auth.uid(),
           manager_reviewed_at = now(),
           approved_at =
               CASE
                   WHEN p_approve THEN now()
                   ELSE NULL
               END,
           rejection_reason =
               CASE
                   WHEN p_approve THEN NULL
                   ELSE p_reason
               END,
           updated_at = now()
     WHERE id = p_application_id;

    -- Restore trusted workflow context immediately after
    -- the workflow-controlled UPDATE.
    PERFORM set_config(
        'bmt.onboarding_workflow',
        COALESCE(v_previous_workflow, ''),
        TRUE
    );

    INSERT INTO bmt_db.onboarding_status_history (
        application_id,
        from_status,
        to_status,
        changed_by,
        reason
    )
    VALUES (
        p_application_id,
        'MANAGER_REVIEW',
        v_target,
        auth.uid(),
        p_reason
    );
END;
$function$;

CREATE OR REPLACE FUNCTION bmt_db.finalize_onboarding_application(p_application_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_previous_workflow TEXT :=
        current_setting(
            'bmt.onboarding_workflow',
            TRUE
        );
    v_app               bmt_db.onboarding_applications%ROWTYPE;

    v_customer_id       UUID;
    v_branch_code       TEXT;

    v_join_date          DATE;
    v_sequence           TEXT;
    v_cif_number         TEXT;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    SELECT *
      INTO v_app
      FROM bmt_db.onboarding_applications
     WHERE id = p_application_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Onboarding application not found';
    END IF;

    -- Idempotent retry protection.
    IF v_app.status = 'COMPLETED'
       AND v_app.customer_id IS NOT NULL THEN
        RETURN v_app.customer_id;
    END IF;

    IF v_app.status <> 'APPROVED' THEN
        RAISE EXCEPTION
            'Only APPROVED application can be finalized';
    END IF;

    IF NOT (
        bmt_db.current_user_is_superadmin()
        OR (
            bmt_db.current_user_has_branch_access(
                v_app.branch_id
            )
            AND bmt_db.current_user_has_permission(
                'onboarding.finalize',
                v_app.branch_id
            )
        )
    ) THEN
        RAISE EXCEPTION
            'Onboarding finalization permission required';
    END IF;

    IF v_app.nik IS NULL
       OR v_app.nik !~ '^[0-9]{16}$' THEN
        RAISE EXCEPTION
            'Valid NIK is required before finalization';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM bmt_db.customers c
        WHERE c.nik = v_app.nik
    ) THEN
        RAISE EXCEPTION
            'NIK % already exists in customer master',
            v_app.nik;
    END IF;

    -- Require exactly one currently-valid signature for every
    -- required signer role on current version.

    IF NOT EXISTS (
        SELECT 1
        FROM bmt_db.onboarding_signatures s
        WHERE s.application_id = p_application_id
          AND s.signer_role = 'CUSTOMER'
          AND s.signed_version = v_app.form_version
          AND s.is_valid = TRUE
    ) THEN
        RAISE EXCEPTION
            'Valid customer signature is required';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM bmt_db.onboarding_signatures s
        WHERE s.application_id = p_application_id
          AND s.signer_role = 'TELLER'
          AND s.signed_version = v_app.form_version
          AND s.is_valid = TRUE
    ) THEN
        RAISE EXCEPTION
            'Valid teller signature is required';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM bmt_db.onboarding_signatures s
        WHERE s.application_id = p_application_id
          AND s.signer_role = 'MANAGER'
          AND s.signed_version = v_app.form_version
          AND s.is_valid = TRUE
    ) THEN
        RAISE EXCEPTION
            'Valid manager signature is required';
    END IF;

    IF v_app.teller_reviewed_by IS NULL
       OR v_app.manager_reviewed_by IS NULL THEN
        RAISE EXCEPTION
            'Teller and manager review records are required';
    END IF;

    IF v_app.teller_reviewed_by = v_app.manager_reviewed_by THEN
        RAISE EXCEPTION
            'Maker-checker violation: teller and manager must be different users';
    END IF;

    SELECT b.code
      INTO v_branch_code
      FROM bmt_db.branches b
     WHERE b.id = v_app.branch_id
       AND b.is_active = TRUE;

    IF v_branch_code IS NULL THEN
        RAISE EXCEPTION
            'Branch is inactive or not found';
    END IF;

    -- CIF specification requires exactly 3 numeric branch digits.
    IF v_branch_code !~ '^[0-9]{3}$' THEN
        RAISE EXCEPTION
            'Branch code % must contain exactly 3 numeric digits for CIF generation',
            v_branch_code;
    END IF;

    -- Official joining date is CIF finalization date.
    v_join_date := CURRENT_DATE;

    -- Existing sequence engine:
    -- CIF + branch + MONTHLY period.
    -- Product/loan codes intentionally blank.
    -- 4-digit monthly sequence.
    v_sequence :=
        bmt_db.next_sequence(
            p_branch_id      => v_app.branch_id,
            p_sequence_type  => 'CIF'::bmt_db.sequence_type,
            p_product_code   => '',
            p_loan_code      => '',
            p_business_date  => v_join_date,
            p_reset_policy   => 'MONTHLY'::bmt_db.sequence_reset_policy,
            p_padding        => 4
        );

    IF v_sequence !~ '^[0-9]{4}$' THEN
        RAISE EXCEPTION
            'CIF monthly sequence exceeded 4 digits: %',
            v_sequence;
    END IF;

    v_cif_number :=
        v_branch_code
        || to_char(v_join_date, 'MM')
        || to_char(v_join_date, 'YY')
        || v_sequence;

    IF v_cif_number !~ '^[0-9]{11}$' THEN
        RAISE EXCEPTION
            'Generated CIF has invalid format: %',
            v_cif_number;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM bmt_db.customers c
        WHERE c.cif_number = v_cif_number
    ) THEN
        RAISE EXCEPTION
            'Generated CIF % already exists',
            v_cif_number;
    END IF;

    INSERT INTO bmt_db.customers (
        cif_number,
        nik,
        full_name,
        birth_place,
        birth_date,
        gender,
        marital_status,
        mother_name,
        occupation,
        monthly_income,
        phone,
        email,
        branch_id,
        status,
        registered_at,
        created_by
    )
    VALUES (
        v_cif_number,
        v_app.nik,
        v_app.full_name,
        v_app.birth_place,
        v_app.birth_date,
        v_app.gender,
        v_app.marital_status,
        v_app.mother_name,
        v_app.occupation,
        v_app.monthly_income,
        v_app.phone,
        v_app.email,
        v_app.branch_id,
        'ACTIVE',
        now(),
        auth.uid()
    )
    RETURNING id
      INTO v_customer_id;

    -- Copy addresses to permanent customer master.

    INSERT INTO bmt_db.customer_addresses (
        customer_id,
        address_type,
        address,
        province,
        city,
        district,
        village,
        postal_code,
        is_primary
    )
    SELECT
        v_customer_id,
        a.address_type,
        a.address,
        a.province,
        a.city,
        a.district,
        a.village,
        a.postal_code,
        a.is_primary
    FROM bmt_db.onboarding_addresses a
    WHERE a.application_id = p_application_id;

    -- Copy accepted documents to permanent customer document
    -- metadata. Files remain in private object storage.

    INSERT INTO bmt_db.customer_documents (
        customer_id,
        document_type,
        document_number,
        storage_bucket,
        storage_path,
        issued_at,
        expired_at,
        verified_at,
        verified_by
    )
    SELECT
        v_customer_id,
        d.document_type,
        d.document_number,
        d.storage_bucket,
        d.storage_path,
        d.issued_at,
        d.expired_at,
        CASE
            WHEN d.status = 'VERIFIED'
                THEN COALESCE(d.verified_at, now())
            ELSE NULL
        END,
        CASE
            WHEN d.status = 'VERIFIED'
                THEN d.verified_by
            ELSE NULL
        END
    FROM bmt_db.onboarding_documents d
    WHERE d.application_id = p_application_id
      AND d.status <> 'REJECTED';

    PERFORM set_config(
        'bmt.onboarding_workflow',
        '1',
        TRUE
    );

    UPDATE bmt_db.onboarding_applications
       SET status = 'COMPLETED',
           customer_id = v_customer_id,
           completed_at = now(),
           updated_at = now()
     WHERE id = p_application_id;

    -- Restore trusted workflow context immediately after
    -- the workflow-controlled UPDATE.
    PERFORM set_config(
        'bmt.onboarding_workflow',
        COALESCE(v_previous_workflow, ''),
        TRUE
    );

    INSERT INTO bmt_db.onboarding_status_history (
        application_id,
        from_status,
        to_status,
        changed_by,
        metadata
    )
    VALUES (
        p_application_id,
        'APPROVED',
        'COMPLETED',
        auth.uid(),
        jsonb_build_object(
            'customer_id',
            v_customer_id,
            'cif_number',
            v_cif_number,
            'join_date',
            v_join_date,
            'branch_code',
            v_branch_code,
            'monthly_sequence',
            v_sequence
        )
    );

    RETURN v_customer_id;
END;
$function$;

-- ------------------------------------------------------------
-- Preserve intended public RPC access model.
-- Do not expose internal trigger/helper functions here.
-- ------------------------------------------------------------

REVOKE ALL ON FUNCTION
    bmt_db.submit_onboarding_application(uuid)
FROM PUBLIC, anon;

REVOKE ALL ON FUNCTION
    bmt_db.complete_teller_onboarding_review(uuid, boolean, text)
FROM PUBLIC, anon;

REVOKE ALL ON FUNCTION
    bmt_db.complete_manager_onboarding_review(uuid, boolean, text)
FROM PUBLIC, anon;

REVOKE ALL ON FUNCTION
    bmt_db.finalize_onboarding_application(uuid)
FROM PUBLIC, anon;


GRANT EXECUTE ON FUNCTION
    bmt_db.submit_onboarding_application(uuid)
TO authenticated;

GRANT EXECUTE ON FUNCTION
    bmt_db.complete_teller_onboarding_review(uuid, boolean, text)
TO authenticated;

GRANT EXECUTE ON FUNCTION
    bmt_db.complete_manager_onboarding_review(uuid, boolean, text)
TO authenticated;

GRANT EXECUTE ON FUNCTION
    bmt_db.finalize_onboarding_application(uuid)
TO authenticated;


COMMENT ON FUNCTION
    bmt_db.submit_onboarding_application(uuid)
IS
    'Submit onboarding application with scoped trusted workflow context.';

COMMENT ON FUNCTION
    bmt_db.complete_teller_onboarding_review(uuid, boolean, text)
IS
    'Complete teller onboarding review with scoped trusted workflow context.';

COMMENT ON FUNCTION
    bmt_db.complete_manager_onboarding_review(uuid, boolean, text)
IS
    'Complete manager onboarding review with scoped trusted workflow context.';

COMMENT ON FUNCTION
    bmt_db.finalize_onboarding_application(uuid)
IS
    'Finalize onboarding application with scoped trusted workflow context.';


COMMIT;
