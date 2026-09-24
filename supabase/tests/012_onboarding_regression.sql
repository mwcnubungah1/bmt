-- ============================================================
-- BMT CORE BANKING SYSTEM
-- Regression Test 012
-- Customer Onboarding & Digital Signature Workflow
--
-- Compatible with:
--   Migration 012
--   Migration 013 material-change fix
--
-- All test data is rolled back.
-- No auth.users rows are created or modified.
-- ============================================================

\set ON_ERROR_STOP on

\set superadmin_id 'e088ce1d-fb7c-47aa-a15d-7dfa779d7583'
\set manager_id    '570893f3-26dd-44d7-9308-34314250e39c'
\set teller_id     'c6f40c04-6914-4494-9390-7526b953e982'

\set test_nik_main '9909182600000001'
\set test_nik_edit '9909182600000002'

BEGIN;
\o /dev/null

\echo ''
\echo '============================================================'
\echo ' BMT MIGRATION 012/013 - ONBOARDING REGRESSION'
\echo '============================================================'


-- ============================================================
-- T01 - ENVIRONMENT
-- ============================================================

\echo ''
\echo '===== T01: VALIDATE ENVIRONMENT ====='

DO $test$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT count(*)
      INTO v_count
      FROM auth.users
     WHERE id IN (
        'e088ce1d-fb7c-47aa-a15d-7dfa779d7583'::uuid,
        '570893f3-26dd-44d7-9308-34314250e39c'::uuid,
        'c6f40c04-6914-4494-9390-7526b953e982'::uuid
     );

    IF v_count <> 3 THEN
        RAISE EXCEPTION
            'Expected 3 test Auth users, found %',
            v_count;
    END IF;

    SELECT count(*)
      INTO v_count
      FROM bmt_db.user_profiles
     WHERE id IN (
        'e088ce1d-fb7c-47aa-a15d-7dfa779d7583'::uuid,
        '570893f3-26dd-44d7-9308-34314250e39c'::uuid,
        'c6f40c04-6914-4494-9390-7526b953e982'::uuid
     )
       AND is_active = TRUE;

    IF v_count <> 3 THEN
        RAISE EXCEPTION
            'Expected 3 active profiles, found %',
            v_count;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM bmt_db.branches
        WHERE code = '001'
          AND is_active = TRUE
    ) THEN
        RAISE EXCEPTION 'Active branch 001 not found';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM bmt_db.products
        WHERE code = 'SAV40'
          AND is_active = TRUE
    ) THEN
        RAISE EXCEPTION 'Active product SAV40 not found';
    END IF;

    RAISE NOTICE 'T01 PASS';
END;
$test$;


-- ============================================================
-- T02 - APPLICANT SESSION
--
-- SUPERADMIN acts only as the simulated applicant for this SQL
-- regression. This does NOT replace later real CUSTOMER testing
-- through GoTrue/PostgREST.
-- ============================================================

\echo ''
\echo '===== T02: APPLICANT SESSION ====='

SELECT set_config(
    'request.jwt.claims',
    json_build_object(
        'sub', :'superadmin_id',
        'role', 'authenticated'
    )::text,
    TRUE
);

SELECT set_config(
    'request.jwt.claim.sub',
    :'superadmin_id',
    TRUE
);

SELECT set_config(
    'request.jwt.claim.role',
    'authenticated',
    TRUE
);

SET LOCAL ROLE authenticated;

SELECT auth.uid() AS applicant_uid;


-- ============================================================
-- T03 - CREATE MAIN DRAFT
-- ============================================================

\echo ''
\echo '===== T03: CREATE MAIN DRAFT ====='

INSERT INTO bmt_db.onboarding_applications (
    branch_id,
    applicant_user_id,
    nik,
    full_name,
    birth_place,
    birth_date,
    gender,
    marital_status,
    mother_name,
    identity_type,
    nationality,
    religion,
    education,
    phone,
    email,
    occupation,
    monthly_income,
    source_of_funds,
    purpose_of_account,
    created_by
)
SELECT
    b.id,
    :'superadmin_id'::uuid,
    :'test_nik_main',
    'REGRESSION TEST NASABAH 012',
    'GRESIK',
    DATE '1990-01-01',
    'MALE'::bmt_db.gender_type,
    'MARRIED',
    'IBU REGRESSION TEST',
    'KTP',
    'INDONESIA',
    'ISLAM',
    'SMA',
    '081200000012',
    'regression012@example.invalid',
    'WIRASWASTA',
    5000000,
    'USAHA',
    'TABUNGAN',
    :'superadmin_id'::uuid
FROM bmt_db.branches b
WHERE b.code = '001'
RETURNING id AS application_id
\gset

SELECT set_config(
    'bmt.test.application_id',
    :'application_id',
    TRUE
);

\echo 'Application ID :' :application_id


-- ============================================================
-- T04 - ADDRESS
-- ============================================================

\echo ''
\echo '===== T04: ADD ADDRESS ====='

INSERT INTO bmt_db.onboarding_addresses (
    application_id,
    address_type,
    address,
    province,
    city,
    district,
    village,
    postal_code,
    rt,
    rw,
    is_primary
)
VALUES (
    :'application_id'::uuid,
    'ID_CARD'::bmt_db.address_type,
    'Jl. Regression Test No. 12',
    'JAWA TIMUR',
    'GRESIK',
    'BUNGAH',
    'BUNGAH',
    '61152',
    '001',
    '002',
    TRUE
);


-- ============================================================
-- T05 - DOCUMENT
-- ============================================================

\echo ''
\echo '===== T05: ADD KTP DOCUMENT ====='

INSERT INTO bmt_db.onboarding_documents (
    application_id,
    document_type,
    document_number,
    storage_bucket,
    storage_path,
    mime_type,
    file_size_bytes,
    sha256,
    status
)
VALUES (
    :'application_id'::uuid,
    'KTP',
    :'test_nik_main',
    'bmt-regression-test',
    '012/ktp/test-main.jpg',
    'image/jpeg',
    1024,
    repeat('a', 64),
    'UPLOADED'
);


-- ============================================================
-- T06 - PRODUCT
-- ============================================================

\echo ''
\echo '===== T06: ADD PRODUCT REQUEST ====='

INSERT INTO bmt_db.onboarding_product_requests (
    application_id,
    product_id,
    requested_amount,
    purpose
)
SELECT
    :'application_id'::uuid,
    p.id,
    100000,
    'REGRESSION TEST'
FROM bmt_db.products p
WHERE p.code = 'SAV40';


-- ============================================================
-- T07 - VERSIONING
-- ============================================================

\echo ''
\echo '===== T07: MATERIAL VERSIONING ====='

DO $test$
DECLARE
    v_application_id UUID :=
        current_setting('bmt.test.application_id')::uuid;

    v_version INTEGER;
BEGIN
    SELECT form_version
      INTO v_version
      FROM bmt_db.onboarding_applications
     WHERE id = v_application_id;

    IF v_version <> 4 THEN
        RAISE EXCEPTION
            'Expected form_version 4, got %',
            v_version;
    END IF;

    RAISE NOTICE
        'T07 PASS - form_version=%',
        v_version;
END;
$test$;


-- ============================================================
-- T08 - UNSIGNED SUBMISSION MUST FAIL
-- ============================================================

\echo ''
\echo '===== T08: UNSIGNED SUBMISSION MUST FAIL ====='

DO $test$
DECLARE
    v_application_id UUID :=
        current_setting('bmt.test.application_id')::uuid;
BEGIN
    BEGIN
        PERFORM bmt_db.submit_onboarding_application(
            v_application_id
        );

        RAISE EXCEPTION
            'TEST_FAILURE_UNSIGNED_APPLICATION_SUBMITTED';

    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM =
               'TEST_FAILURE_UNSIGNED_APPLICATION_SUBMITTED'
            THEN
                RAISE;
            END IF;

            RAISE NOTICE
                'T08 PASS - submission rejected: %',
                SQLERRM;
    END;

    IF EXISTS (
        SELECT 1
        FROM bmt_db.onboarding_applications
        WHERE id = v_application_id
          AND status <> 'DRAFT'
    ) THEN
        RAISE EXCEPTION
            'Unsigned application left DRAFT state';
    END IF;
END;
$test$;


-- ============================================================
-- T09 - CUSTOMER SIGNATURE
-- ============================================================

\echo ''
\echo '===== T09: CUSTOMER SIGNATURE ====='

SELECT bmt_db.sign_onboarding_application(
    :'application_id'::uuid,
    'CUSTOMER'::bmt_db.onboarding_signature_role,
    'bmt-regression-test',
    '012/signatures/customer-main.png',
    repeat('b', 64),
    '127.0.0.1'::inet,
    'BMT-012-REGRESSION'
) AS customer_signature_id
\gset

SELECT set_config(
    'bmt.test.customer_signature_id',
    :'customer_signature_id',
    TRUE
);

\echo 'Customer signature :' :customer_signature_id


-- ============================================================
-- T10 - SUBMIT
-- ============================================================

\echo ''
\echo '===== T10: SUBMIT -> TELLER_REVIEW ====='

SELECT bmt_db.submit_onboarding_application(
    :'application_id'::uuid
);

DO $test$
DECLARE
    v_application_id UUID :=
        current_setting('bmt.test.application_id')::uuid;

    v_status bmt_db.onboarding_status;
BEGIN
    SELECT status
      INTO v_status
      FROM bmt_db.onboarding_applications
     WHERE id = v_application_id;

    IF v_status <> 'TELLER_REVIEW' THEN
        RAISE EXCEPTION
            'Expected TELLER_REVIEW, got %',
            v_status;
    END IF;

    RAISE NOTICE 'T10 PASS - %', v_status;
END;
$test$;


-- ============================================================
-- T11 - TELLER SESSION
-- ============================================================

\echo ''
\echo '===== T11: TELLER SESSION ====='

RESET ROLE;

SELECT set_config(
    'request.jwt.claims',
    json_build_object(
        'sub', :'teller_id',
        'role', 'authenticated'
    )::text,
    TRUE
);

SELECT set_config(
    'request.jwt.claim.sub',
    :'teller_id',
    TRUE
);

SELECT set_config(
    'request.jwt.claim.role',
    'authenticated',
    TRUE
);

SET LOCAL ROLE authenticated;

SELECT auth.uid() AS teller_uid;


-- ============================================================
-- T12 - TELLER SIGNATURE
-- ============================================================

\echo ''
\echo '===== T12: TELLER SIGNATURE ====='

SELECT bmt_db.sign_onboarding_application(
    :'application_id'::uuid,
    'TELLER'::bmt_db.onboarding_signature_role,
    'bmt-regression-test',
    '012/signatures/teller-main.png',
    repeat('c', 64),
    '127.0.0.1'::inet,
    'BMT-012-REGRESSION'
) AS teller_signature_id
\gset

\echo 'Teller signature :' :teller_signature_id


-- ============================================================
-- T13 - TELLER APPROVAL
-- ============================================================

\echo ''
\echo '===== T13: TELLER -> MANAGER_REVIEW ====='

SELECT bmt_db.complete_teller_onboarding_review(
    :'application_id'::uuid,
    TRUE,
    'REGRESSION TEST TELLER VERIFIED'
);

DO $test$
DECLARE
    v_application_id UUID :=
        current_setting('bmt.test.application_id')::uuid;

    v_teller_id UUID :=
        'c6f40c04-6914-4494-9390-7526b953e982'::uuid;

    v_status bmt_db.onboarding_status;
    v_reviewer UUID;
BEGIN
    SELECT
        status,
        teller_reviewed_by
      INTO
        v_status,
        v_reviewer
      FROM bmt_db.onboarding_applications
     WHERE id = v_application_id;

    IF v_status <> 'MANAGER_REVIEW' THEN
        RAISE EXCEPTION
            'Expected MANAGER_REVIEW, got %',
            v_status;
    END IF;

    IF v_reviewer IS DISTINCT FROM v_teller_id THEN
        RAISE EXCEPTION
            'Unexpected teller reviewer: %',
            v_reviewer;
    END IF;

    RAISE NOTICE 'T13 PASS';
END;
$test$;


-- ============================================================
-- T14 - MAKER CHECKER
-- ============================================================

\echo ''
\echo '===== T14: TELLER CANNOT SIGN AS MANAGER ====='

DO $test$
DECLARE
    v_application_id UUID :=
        current_setting('bmt.test.application_id')::uuid;
BEGIN
    BEGIN
        PERFORM bmt_db.sign_onboarding_application(
            v_application_id,
            'MANAGER'::bmt_db.onboarding_signature_role,
            'bmt-regression-test',
            '012/signatures/illegal-manager.png',
            repeat('d', 64),
            '127.0.0.1'::inet,
            'BMT-012-REGRESSION'
        );

        RAISE EXCEPTION
            'TEST_FAILURE_TELLER_SIGNED_AS_MANAGER';

    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM =
               'TEST_FAILURE_TELLER_SIGNED_AS_MANAGER'
            THEN
                RAISE;
            END IF;

            RAISE NOTICE
                'T14 PASS - rejected: %',
                SQLERRM;
    END;
END;
$test$;


-- ============================================================
-- T15 - MANAGER SESSION
-- ============================================================

\echo ''
\echo '===== T15: MANAGER SESSION ====='

RESET ROLE;

SELECT set_config(
    'request.jwt.claims',
    json_build_object(
        'sub', :'manager_id',
        'role', 'authenticated'
    )::text,
    TRUE
);

SELECT set_config(
    'request.jwt.claim.sub',
    :'manager_id',
    TRUE
);

SELECT set_config(
    'request.jwt.claim.role',
    'authenticated',
    TRUE
);

SET LOCAL ROLE authenticated;

SELECT auth.uid() AS manager_uid;


-- ============================================================
-- T16 - MANAGER SIGNATURE
-- ============================================================

\echo ''
\echo '===== T16: MANAGER SIGNATURE ====='

SELECT bmt_db.sign_onboarding_application(
    :'application_id'::uuid,
    'MANAGER'::bmt_db.onboarding_signature_role,
    'bmt-regression-test',
    '012/signatures/manager-main.png',
    repeat('e', 64),
    '127.0.0.1'::inet,
    'BMT-012-REGRESSION'
) AS manager_signature_id
\gset

\echo 'Manager signature :' :manager_signature_id


-- ============================================================
-- T17 - MANAGER APPROVAL
-- ============================================================

\echo ''
\echo '===== T17: MANAGER -> APPROVED ====='

SELECT bmt_db.complete_manager_onboarding_review(
    :'application_id'::uuid,
    TRUE,
    'REGRESSION TEST MANAGER APPROVED'
);

DO $test$
DECLARE
    v_application_id UUID :=
        current_setting('bmt.test.application_id')::uuid;

    v_manager_id UUID :=
        '570893f3-26dd-44d7-9308-34314250e39c'::uuid;

    v_status bmt_db.onboarding_status;
    v_reviewer UUID;
BEGIN
    SELECT
        status,
        manager_reviewed_by
      INTO
        v_status,
        v_reviewer
      FROM bmt_db.onboarding_applications
     WHERE id = v_application_id;

    IF v_status <> 'APPROVED' THEN
        RAISE EXCEPTION
            'Expected APPROVED, got %',
            v_status;
    END IF;

    IF v_reviewer IS DISTINCT FROM v_manager_id THEN
        RAISE EXCEPTION
            'Unexpected manager reviewer: %',
            v_reviewer;
    END IF;

    RAISE NOTICE 'T17 PASS';
END;
$test$;


-- ============================================================
-- T18 - FINALIZE
-- ============================================================

\echo ''
\echo '===== T18: FINALIZE ====='

SELECT bmt_db.finalize_onboarding_application(
    :'application_id'::uuid
) AS finalized_customer_id
\gset

SELECT set_config(
    'bmt.test.customer_id',
    :'finalized_customer_id',
    TRUE
);

\echo 'Finalized Customer :' :finalized_customer_id


-- ============================================================
-- T19 - COMPLETED
-- ============================================================

\echo ''
\echo '===== T19: VERIFY COMPLETED ====='

DO $test$
DECLARE
    v_application_id UUID :=
        current_setting('bmt.test.application_id')::uuid;

    v_customer_id UUID :=
        current_setting('bmt.test.customer_id')::uuid;

    v_status bmt_db.onboarding_status;
    v_linked_customer UUID;
BEGIN
    SELECT
        status,
        customer_id
      INTO
        v_status,
        v_linked_customer
      FROM bmt_db.onboarding_applications
     WHERE id = v_application_id;

    IF v_status <> 'COMPLETED' THEN
        RAISE EXCEPTION
            'Expected COMPLETED, got %',
            v_status;
    END IF;

    IF v_linked_customer IS DISTINCT FROM v_customer_id THEN
        RAISE EXCEPTION
            'Application/customer link mismatch';
    END IF;

    RAISE NOTICE 'T19 PASS';
END;
$test$;


-- ============================================================
-- T20 - CUSTOMER / CIF
-- ============================================================

\echo ''
\echo '===== T20: VERIFY CUSTOMER / CIF ====='

SELECT
    c.id,
    c.cif_number,
    c.nik,
    c.full_name,
    c.status,
    b.code AS branch_code,
    c.registered_at
FROM bmt_db.customers c
JOIN bmt_db.branches b
  ON b.id = c.branch_id
WHERE c.id = :'finalized_customer_id'::uuid;

DO $test$
DECLARE
    v_customer_id UUID :=
        current_setting('bmt.test.customer_id')::uuid;

    v_cif TEXT;
    v_status bmt_db.customer_status;
    v_branch TEXT;
BEGIN
    SELECT
        c.cif_number,
        c.status,
        b.code
      INTO
        v_cif,
        v_status,
        v_branch
      FROM bmt_db.customers c
      JOIN bmt_db.branches b
        ON b.id = c.branch_id
     WHERE c.id = v_customer_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Finalized customer not found';
    END IF;

    IF v_cif !~ '^[0-9]{11}$' THEN
        RAISE EXCEPTION
            'Invalid CIF: %',
            v_cif;
    END IF;

    IF substring(v_cif FROM 1 FOR 3) <> v_branch THEN
        RAISE EXCEPTION
            'CIF branch mismatch: %',
            v_cif;
    END IF;

    IF substring(v_cif FROM 4 FOR 2)
       <> to_char(CURRENT_DATE, 'MM') THEN
        RAISE EXCEPTION
            'CIF month mismatch: %',
            v_cif;
    END IF;

    IF substring(v_cif FROM 6 FOR 2)
       <> to_char(CURRENT_DATE, 'YY') THEN
        RAISE EXCEPTION
            'CIF year mismatch: %',
            v_cif;
    END IF;

    IF v_status <> 'ACTIVE' THEN
        RAISE EXCEPTION
            'Customer expected ACTIVE, got %',
            v_status;
    END IF;

    RAISE NOTICE
        'T20 PASS - CIF=%',
        v_cif;
END;
$test$;


-- ============================================================
-- T21 - CHILD COPY
-- ============================================================

\echo ''
\echo '===== T21: VERIFY ADDRESS / DOCUMENT COPY ====='

DO $test$
DECLARE
    v_customer_id UUID :=
        current_setting('bmt.test.customer_id')::uuid;

    v_addresses INTEGER;
    v_documents INTEGER;
BEGIN
    SELECT count(*)
      INTO v_addresses
      FROM bmt_db.customer_addresses
     WHERE customer_id = v_customer_id;

    SELECT count(*)
      INTO v_documents
      FROM bmt_db.customer_documents
     WHERE customer_id = v_customer_id;

    IF v_addresses <> 1 THEN
        RAISE EXCEPTION
            'Expected 1 copied address, got %',
            v_addresses;
    END IF;

    IF v_documents <> 1 THEN
        RAISE EXCEPTION
            'Expected 1 copied document, got %',
            v_documents;
    END IF;

    RAISE NOTICE
        'T21 PASS - addresses=% documents=%',
        v_addresses,
        v_documents;
END;
$test$;


-- ============================================================
-- T22 - SIGNATURES
-- ============================================================

\echo ''
\echo '===== T22: VERIFY SIGNATURES ====='

SELECT
    signer_role,
    signer_user_id,
    signed_version,
    is_valid,
    signed_at
FROM bmt_db.onboarding_signatures
WHERE application_id = :'application_id'::uuid
ORDER BY signer_role;

DO $test$
DECLARE
    v_application_id UUID :=
        current_setting('bmt.test.application_id')::uuid;

    v_count INTEGER;
BEGIN
    SELECT count(*)
      INTO v_count
      FROM bmt_db.onboarding_signatures
     WHERE application_id = v_application_id
       AND is_valid = TRUE
       AND signer_role IN (
           'CUSTOMER',
           'TELLER',
           'MANAGER'
       );

    IF v_count <> 3 THEN
        RAISE EXCEPTION
            'Expected 3 valid signatures, got %',
            v_count;
    END IF;

    RAISE NOTICE 'T22 PASS';
END;
$test$;


-- ============================================================
-- T23 - HISTORY
-- ============================================================

\echo ''
\echo '===== T23: VERIFY STATUS HISTORY ====='

SELECT
    from_status,
    to_status,
    changed_by,
    changed_at
FROM bmt_db.onboarding_status_history
WHERE application_id = :'application_id'::uuid
ORDER BY changed_at, id;

DO $test$
DECLARE
    v_application_id UUID :=
        current_setting('bmt.test.application_id')::uuid;

    v_teller_review INTEGER;
    v_manager_review INTEGER;
    v_approved INTEGER;
    v_completed INTEGER;
BEGIN
    SELECT count(*)
      INTO v_teller_review
      FROM bmt_db.onboarding_status_history
     WHERE application_id = v_application_id
       AND to_status = 'TELLER_REVIEW';

    SELECT count(*)
      INTO v_manager_review
      FROM bmt_db.onboarding_status_history
     WHERE application_id = v_application_id
       AND to_status = 'MANAGER_REVIEW';

    SELECT count(*)
      INTO v_approved
      FROM bmt_db.onboarding_status_history
     WHERE application_id = v_application_id
       AND to_status = 'APPROVED';

    SELECT count(*)
      INTO v_completed
      FROM bmt_db.onboarding_status_history
     WHERE application_id = v_application_id
       AND to_status = 'COMPLETED';

    IF v_teller_review <> 1
       OR v_manager_review <> 1
       OR v_approved <> 1
       OR v_completed <> 1 THEN
        RAISE EXCEPTION
            'History mismatch: teller_review %, manager_review %, approved %, completed %',
            v_teller_review,
            v_manager_review,
            v_approved,
            v_completed;
    END IF;

    RAISE NOTICE 'T23 PASS';
END;
$test$;


-- ============================================================
-- T24 - FINALIZE RETRY
-- ============================================================

\echo ''
\echo '===== T24: FINALIZE RETRY / IDEMPOTENCY ====='

SELECT bmt_db.finalize_onboarding_application(
    :'application_id'::uuid
) AS retry_customer_id
\gset

SELECT set_config(
    'bmt.test.retry_customer_id',
    :'retry_customer_id',
    TRUE
);

DO $test$
DECLARE
    v_customer_id UUID :=
        current_setting('bmt.test.customer_id')::uuid;

    v_retry_id UUID :=
        current_setting('bmt.test.retry_customer_id')::uuid;
BEGIN
    IF v_retry_id IS DISTINCT FROM v_customer_id THEN
        RAISE EXCEPTION
            'Finalize retry returned another customer';
    END IF;

    RAISE NOTICE 'T24 PASS';
END;
$test$;


-- ============================================================
-- T25 - SIGNATURE INVALIDATION
-- ============================================================

\echo ''
\echo '===== T25: SIGNATURE INVALIDATION ====='

RESET ROLE;

SELECT set_config(
    'request.jwt.claims',
    json_build_object(
        'sub', :'superadmin_id',
        'role', 'authenticated'
    )::text,
    TRUE
);

SELECT set_config(
    'request.jwt.claim.sub',
    :'superadmin_id',
    TRUE
);

SELECT set_config(
    'request.jwt.claim.role',
    'authenticated',
    TRUE
);

SET LOCAL ROLE authenticated;


INSERT INTO bmt_db.onboarding_applications (
    branch_id,
    applicant_user_id,
    nik,
    full_name,
    birth_place,
    birth_date,
    gender,
    phone,
    occupation,
    monthly_income,
    created_by
)
SELECT
    b.id,
    :'superadmin_id'::uuid,
    :'test_nik_edit',
    'REGRESSION SIGNATURE INVALIDATION',
    'GRESIK',
    DATE '1992-02-02',
    'FEMALE'::bmt_db.gender_type,
    '081200000013',
    'WIRASWASTA',
    4000000,
    :'superadmin_id'::uuid
FROM bmt_db.branches b
WHERE b.code = '001'
RETURNING id AS edit_application_id
\gset

SELECT set_config(
    'bmt.test.edit_application_id',
    :'edit_application_id',
    TRUE
);


SELECT bmt_db.sign_onboarding_application(
    :'edit_application_id'::uuid,
    'CUSTOMER'::bmt_db.onboarding_signature_role,
    'bmt-regression-test',
    '012/signatures/customer-edit-test.png',
    repeat('f', 64),
    '127.0.0.1'::inet,
    'BMT-012-REGRESSION'
) AS edit_signature_id
\gset

SELECT set_config(
    'bmt.test.edit_signature_id',
    :'edit_signature_id',
    TRUE
);


DO $test$
DECLARE
    v_signature_id UUID :=
        current_setting('bmt.test.edit_signature_id')::uuid;

    v_valid BOOLEAN;
BEGIN
    SELECT is_valid
      INTO v_valid
      FROM bmt_db.onboarding_signatures
     WHERE id = v_signature_id;

    IF v_valid IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION
            'Initial signature should be valid';
    END IF;

    RAISE NOTICE 'T25A PASS';
END;
$test$;


UPDATE bmt_db.onboarding_applications
SET phone = '081299999999'
WHERE id = :'edit_application_id'::uuid;


DO $test$
DECLARE
    v_application_id UUID :=
        current_setting('bmt.test.edit_application_id')::uuid;

    v_signature_id UUID :=
        current_setting('bmt.test.edit_signature_id')::uuid;

    v_valid BOOLEAN;
    v_invalidated_at TIMESTAMPTZ;
    v_reason TEXT;
    v_version INTEGER;
BEGIN
    SELECT
        is_valid,
        invalidated_at,
        invalidation_reason
      INTO
        v_valid,
        v_invalidated_at,
        v_reason
      FROM bmt_db.onboarding_signatures
     WHERE id = v_signature_id;

    SELECT form_version
      INTO v_version
      FROM bmt_db.onboarding_applications
     WHERE id = v_application_id;

    IF v_valid IS DISTINCT FROM FALSE THEN
        RAISE EXCEPTION
            'Signature remained valid after edit';
    END IF;

    IF v_invalidated_at IS NULL THEN
        RAISE EXCEPTION
            'invalidated_at not recorded';
    END IF;

    IF v_reason IS DISTINCT FROM 'FORM_CHANGED' THEN
        RAISE EXCEPTION
            'Unexpected invalidation reason: %',
            v_reason;
    END IF;

    IF v_version <> 2 THEN
        RAISE EXCEPTION
            'Expected form_version 2, got %',
            v_version;
    END IF;

    RAISE NOTICE
        'T25B PASS - signature invalidated, version=%',
        v_version;
END;
$test$;


-- ============================================================
-- T26 - INVALIDATED SIGNATURE CANNOT SUBMIT
-- ============================================================

\echo ''
\echo '===== T26: INVALIDATED SIGNATURE CANNOT SUBMIT ====='

DO $test$
DECLARE
    v_application_id UUID :=
        current_setting('bmt.test.edit_application_id')::uuid;
BEGIN
    BEGIN
        PERFORM bmt_db.submit_onboarding_application(
            v_application_id
        );

        RAISE EXCEPTION
            'TEST_FAILURE_INVALID_SIGNATURE_SUBMITTED';

    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM =
               'TEST_FAILURE_INVALID_SIGNATURE_SUBMITTED'
            THEN
                RAISE;
            END IF;

            RAISE NOTICE
                'T26 PASS - rejected: %',
                SQLERRM;
    END;

    IF EXISTS (
        SELECT 1
        FROM bmt_db.onboarding_applications
        WHERE id = v_application_id
          AND status <> 'DRAFT'
    ) THEN
        RAISE EXCEPTION
            'Invalid-signature application left DRAFT';
    END IF;
END;
$test$;


-- ============================================================
-- T27 - SHOW DATA BEFORE ROLLBACK
-- ============================================================

\echo ''
\echo '===== T27: DATA INSIDE TEST TRANSACTION ====='

RESET ROLE;

SELECT
    c.cif_number,
    c.nik,
    c.full_name,
    c.status
FROM bmt_db.customers c
WHERE c.nik IN (
    :'test_nik_main',
    :'test_nik_edit'
);

SELECT
    oa.id,
    oa.nik,
    oa.status,
    oa.form_version,
    oa.customer_id
FROM bmt_db.onboarding_applications oa
WHERE oa.nik IN (
    :'test_nik_main',
    :'test_nik_edit'
)
ORDER BY oa.nik;

SELECT
    b.code AS branch,
    ns.sequence_type,
    ns.period_key,
    ns.current_value,
    ns.padding,
    ns.reset_policy
FROM bmt_db.number_sequences ns
JOIN bmt_db.branches b
  ON b.id = ns.branch_id
WHERE b.code = '001'
  AND ns.sequence_type = 'CIF'
ORDER BY ns.period_key;


\echo ''
\echo '============================================================'
\echo ' ALL ONBOARDING REGRESSION ASSERTIONS PASSED'
\echo ' ROLLING BACK ALL TEST DATA'
\echo '============================================================'

ROLLBACK;


-- ============================================================
-- POST ROLLBACK
-- ============================================================

\echo ''
\echo '===== T28: VERIFY CLEAN ROLLBACK ====='

SELECT count(*) AS test_customers_after_rollback
FROM bmt_db.customers
WHERE nik IN (
    :'test_nik_main',
    :'test_nik_edit'
);

SELECT count(*) AS test_onboarding_after_rollback
FROM bmt_db.onboarding_applications
WHERE nik IN (
    :'test_nik_main',
    :'test_nik_edit'
);

SELECT count(*) AS cif_sequence_rows_after_rollback
FROM bmt_db.number_sequences ns
JOIN bmt_db.branches b
  ON b.id = ns.branch_id
WHERE b.code = '001'
  AND ns.sequence_type = 'CIF';

\o
SELECT plan(1);

DO $$
DECLARE
  v_customers integer;
  v_applications integer;
BEGIN
  SELECT count(*) INTO v_customers
  FROM bmt_db.customers
  WHERE nik IN ('9909182600000001', '9909182600000002');

  SELECT count(*) INTO v_applications
  FROM bmt_db.onboarding_applications
  WHERE nik IN ('9909182600000001', '9909182600000002');

  IF v_customers <> 0 OR v_applications <> 0 THEN
    RAISE EXCEPTION
      'Expected clean rollback, found customers=%, applications=%',
      v_customers, v_applications;
  END IF;

  RAISE NOTICE
    'T28 PASS - customer/application data rolled back; CIF sequence state is durable';
END $$;

SELECT ok(TRUE, 'onboarding regression completed with clean rollback');
SELECT * FROM finish();


\echo ''
\echo '============================================================'
\echo ' MIGRATION 012/013 REGRESSION FINISHED'
\echo ' Expected:'
\echo '   test_customers_after_rollback    = 0'
\echo '   test_onboarding_after_rollback   = 0'
\echo '   cif_sequence_rows_after_rollback = 0'
\echo '============================================================'
