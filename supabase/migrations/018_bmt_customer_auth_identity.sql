BEGIN;

-- ============================================================
-- BMT MIGRATION 018
-- CUSTOMER <-> SUPABASE AUTH IDENTITY
--
-- Goals:
--   1. One optional Auth identity per customer/CIF.
--   2. One Auth identity can belong to at most one customer.
--   3. Digital onboarding propagates applicant_user_id
--      into the finalized customer.
--   4. Manual/teller-created customers remain valid with
--      auth_user_id = NULL.
--   5. Existing onboarding maker-checker/finalization rules
--      remain intact.
-- ============================================================


-- ============================================================
-- 01. CUSTOMER AUTH IDENTITY COLUMN
-- ============================================================

ALTER TABLE bmt_db.customers
    ADD COLUMN auth_user_id UUID NULL;

COMMENT ON COLUMN bmt_db.customers.auth_user_id IS
    'Optional Supabase Auth identity linked one-to-one to this BMT customer/CIF. NULL means the customer does not yet have an application login.';


-- ============================================================
-- 02. FOREIGN KEY TO SUPABASE AUTH
-- ============================================================

ALTER TABLE bmt_db.customers
    ADD CONSTRAINT fk_customers_auth_user
    FOREIGN KEY (auth_user_id)
    REFERENCES auth.users(id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;


-- ============================================================
-- 03. ONE AUTH USER -> MAXIMUM ONE CUSTOMER/CIF
--
-- PostgreSQL UNIQUE permits multiple NULL values, which is
-- exactly what is required for customers without app login.
-- ============================================================

ALTER TABLE bmt_db.customers
    ADD CONSTRAINT uq_customers_auth_user
    UNIQUE (auth_user_id);


-- ============================================================
-- 04. HARDEN FINALIZATION
--
-- Digital onboarding:
--     onboarding.applicant_user_id -> customers.auth_user_id
--
-- Manual/staff onboarding:
--     applicant_user_id NULL -> customers.auth_user_id NULL
--
-- Existing finalization remains idempotent.
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.finalize_onboarding_application(
    p_application_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_previous_workflow TEXT :=
        pg_catalog.current_setting(
            'bmt.onboarding_workflow',
            TRUE
        );

    v_app               bmt_db.onboarding_applications%ROWTYPE;
    v_customer_id       UUID;
    v_branch_code       TEXT;

    v_join_date         DATE;
    v_sequence          TEXT;
    v_cif_number        TEXT;
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

    -- Prevent one Supabase Auth identity from ever producing
    -- multiple BMT customer/CIF records.
    IF v_app.applicant_user_id IS NOT NULL
       AND EXISTS (
           SELECT 1
             FROM bmt_db.customers c
            WHERE c.auth_user_id = v_app.applicant_user_id
       ) THEN
        RAISE EXCEPTION
            'Applicant Auth identity is already linked to a customer';
    END IF;

    -- Require exactly one currently-valid signature for every
    -- required signer role on current form version.

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

    IF v_branch_code !~ '^[0-9]{3}$' THEN
        RAISE EXCEPTION
            'Branch code % must contain exactly 3 numeric digits for CIF generation',
            v_branch_code;
    END IF;

    v_join_date := CURRENT_DATE;

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
        || pg_catalog.to_char(v_join_date, 'MM')
        || pg_catalog.to_char(v_join_date, 'YY')
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
        created_by,
        auth_user_id
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
        pg_catalog.now(),
        auth.uid(),
        v_app.applicant_user_id
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
                THEN COALESCE(
                    d.verified_at,
                    pg_catalog.now()
                )
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

    PERFORM pg_catalog.set_config(
        'bmt.onboarding_workflow',
        '1',
        TRUE
    );

    UPDATE bmt_db.onboarding_applications
       SET status = 'COMPLETED',
           customer_id = v_customer_id,
           completed_at = pg_catalog.now(),
           updated_at = pg_catalog.now()
     WHERE id = p_application_id;

    PERFORM pg_catalog.set_config(
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
        pg_catalog.jsonb_build_object(
            'customer_id',
            v_customer_id,
            'cif_number',
            v_cif_number,
            'join_date',
            v_join_date,
            'branch_code',
            v_branch_code,
            'monthly_sequence',
            v_sequence,
            'auth_user_linked',
            (v_app.applicant_user_id IS NOT NULL)
        )
    );

    RETURN v_customer_id;

EXCEPTION
    WHEN OTHERS THEN
        -- Ensure workflow context is restored even when
        -- finalization fails inside a caller transaction.
        PERFORM pg_catalog.set_config(
            'bmt.onboarding_workflow',
            COALESCE(v_previous_workflow, ''),
            TRUE
        );

        RAISE;
END;
$function$;


-- ============================================================
-- 05. FUNCTION ACL
-- ============================================================

REVOKE ALL
ON FUNCTION bmt_db.finalize_onboarding_application(UUID)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION bmt_db.finalize_onboarding_application(UUID)
FROM anon;

GRANT EXECUTE
ON FUNCTION bmt_db.finalize_onboarding_application(UUID)
TO authenticated;


-- ============================================================
-- 06. STRUCTURAL ASSERTIONS
-- ============================================================

DO $assert$
DECLARE
    v_column_count       INTEGER;
    v_fk_count           INTEGER;
    v_unique_count       INTEGER;
    v_security_definer   BOOLEAN;
    v_search_path_ok     BOOLEAN;
    v_auth_exec          BOOLEAN;
    v_anon_exec          BOOLEAN;
BEGIN
    SELECT count(*)
      INTO v_column_count
      FROM information_schema.columns
     WHERE table_schema = 'bmt_db'
       AND table_name = 'customers'
       AND column_name = 'auth_user_id'
       AND data_type = 'uuid'
       AND is_nullable = 'YES';

    IF v_column_count <> 1 THEN
        RAISE EXCEPTION
            '018 ASSERT FAILED: customers.auth_user_id invalid';
    END IF;

    SELECT count(*)
      INTO v_fk_count
      FROM pg_catalog.pg_constraint con
      JOIN pg_catalog.pg_class c
        ON c.oid = con.conrelid
      JOIN pg_catalog.pg_namespace n
        ON n.oid = c.relnamespace
     WHERE n.nspname = 'bmt_db'
       AND c.relname = 'customers'
       AND con.conname = 'fk_customers_auth_user'
       AND con.contype = 'f';

    IF v_fk_count <> 1 THEN
        RAISE EXCEPTION
            '018 ASSERT FAILED: auth FK missing';
    END IF;

    SELECT count(*)
      INTO v_unique_count
      FROM pg_catalog.pg_constraint con
      JOIN pg_catalog.pg_class c
        ON c.oid = con.conrelid
      JOIN pg_catalog.pg_namespace n
        ON n.oid = c.relnamespace
     WHERE n.nspname = 'bmt_db'
       AND c.relname = 'customers'
       AND con.conname = 'uq_customers_auth_user'
       AND con.contype = 'u';

    IF v_unique_count <> 1 THEN
        RAISE EXCEPTION
            '018 ASSERT FAILED: auth uniqueness missing';
    END IF;

    SELECT
        p.prosecdef,
        COALESCE(
            p.proconfig @> ARRAY['search_path=""']::TEXT[],
            FALSE
        ),
        pg_catalog.has_function_privilege(
            'authenticated',
            p.oid,
            'EXECUTE'
        ),
        pg_catalog.has_function_privilege(
            'anon',
            p.oid,
            'EXECUTE'
        )
      INTO
        v_security_definer,
        v_search_path_ok,
        v_auth_exec,
        v_anon_exec
      FROM pg_catalog.pg_proc p
      JOIN pg_catalog.pg_namespace n
        ON n.oid = p.pronamespace
     WHERE n.nspname = 'bmt_db'
       AND p.proname = 'finalize_onboarding_application'
       AND pg_catalog.pg_get_function_identity_arguments(p.oid)
           = 'p_application_id uuid';

    IF NOT COALESCE(v_security_definer, FALSE) THEN
        RAISE EXCEPTION
            '018 ASSERT FAILED: finalize RPC is not SECURITY DEFINER';
    END IF;

    IF NOT COALESCE(v_search_path_ok, FALSE) THEN
        RAISE EXCEPTION
            '018 ASSERT FAILED: finalize RPC search_path not hardened';
    END IF;

    IF NOT COALESCE(v_auth_exec, FALSE) THEN
        RAISE EXCEPTION
            '018 ASSERT FAILED: authenticated cannot execute finalize RPC';
    END IF;

    IF COALESCE(v_anon_exec, FALSE) THEN
        RAISE EXCEPTION
            '018 ASSERT FAILED: anon can execute finalize RPC';
    END IF;

    RAISE NOTICE
        '018 STRUCTURAL PASS - customer Auth identity mapping installed';
END;
$assert$;

COMMIT;
