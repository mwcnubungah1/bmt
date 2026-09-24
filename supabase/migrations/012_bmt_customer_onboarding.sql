-- ============================================================
-- BMT CORE BANKING SYSTEM
-- Migration 012
-- Customer Onboarding & Digital Signature Workflow
--
-- CIF FORMAT:
--   XXXMMYYNNNN
--   XXX  = branch code (3 numeric digits)
--   MM   = joining/finalization month
--   YY   = joining/finalization year
--   NNNN = monthly customer sequence per branch
--
-- Example:
--   00109260057
--   Branch 001, September 2026, sequence 0057
--
-- Workflow:
--   DRAFT
--     -> customer signs current form version
--     -> TELLER_REVIEW
--     -> MANAGER_REVIEW
--     -> APPROVED
--     -> COMPLETED / CIF CREATED
--
-- RETURNED may be used by Teller to return an application
-- to the customer for correction.
--
-- IMPORTANT:
-- - Draft may be saved before signatures are complete.
-- - CIF is created only after full approval.
-- - This migration DOES NOT open/post financial accounts.
-- - Requested products become input to account-opening workflow.
-- ============================================================

BEGIN;


-- ============================================================
-- 1. ONBOARDING ENUMS
-- ============================================================

CREATE TYPE bmt_db.onboarding_status AS ENUM (
    'DRAFT',
    'TELLER_REVIEW',
    'MANAGER_REVIEW',
    'RETURNED',
    'REJECTED',
    'APPROVED',
    'COMPLETED',
    'CANCELLED'
);

CREATE TYPE bmt_db.onboarding_signature_role AS ENUM (
    'CUSTOMER',
    'TELLER',
    'MANAGER'
);

CREATE TYPE bmt_db.onboarding_product_status AS ENUM (
    'REQUESTED',
    'APPROVED',
    'REJECTED'
);

CREATE TYPE bmt_db.onboarding_document_status AS ENUM (
    'UPLOADED',
    'VERIFIED',
    'REJECTED'
);


-- ============================================================
-- 2. ONBOARDING APPLICATION
-- ============================================================

CREATE TABLE bmt_db.onboarding_applications (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    branch_id               UUID NOT NULL,
    applicant_user_id       UUID NULL,

    status                  bmt_db.onboarding_status
                            NOT NULL DEFAULT 'DRAFT',

    form_version            INTEGER NOT NULL DEFAULT 1,

    -- Identity
    nik                     VARCHAR(16) NULL,
    full_name               VARCHAR(150) NULL,

    birth_place             VARCHAR(100) NULL,
    birth_date              DATE NULL,

    gender                  bmt_db.gender_type NULL,
    marital_status          VARCHAR(30) NULL,

    mother_name             VARCHAR(150) NULL,

    identity_type           VARCHAR(30) NOT NULL DEFAULT 'KTP',
    identity_expired_at     DATE NULL,

    nationality             VARCHAR(50) NOT NULL DEFAULT 'INDONESIA',
    religion                VARCHAR(50) NULL,
    education               VARCHAR(100) NULL,

    npwp                    VARCHAR(30) NULL,

    -- Contact
    phone                   VARCHAR(30) NULL,
    email                   VARCHAR(255) NULL,

    -- Occupation
    occupation              VARCHAR(100) NULL,
    employer_name           VARCHAR(150) NULL,
    position_name           VARCHAR(100) NULL,

    -- Financial summary
    monthly_income          bmt_db.money_amount NULL,
    monthly_expense         bmt_db.money_amount NULL,
    source_of_funds         VARCHAR(150) NULL,
    purpose_of_account      VARCHAR(200) NULL,

    -- Emergency contact
    emergency_contact_name  VARCHAR(150) NULL,
    emergency_contact_phone VARCHAR(30) NULL,
    emergency_relationship  VARCHAR(50) NULL,

    -- Workflow
    submitted_at            TIMESTAMPTZ NULL,

    teller_reviewed_by      UUID NULL,
    teller_reviewed_at      TIMESTAMPTZ NULL,

    manager_reviewed_by     UUID NULL,
    manager_reviewed_at     TIMESTAMPTZ NULL,

    approved_at             TIMESTAMPTZ NULL,

    return_reason           TEXT NULL,
    rejection_reason        TEXT NULL,

    -- Finalization
    customer_id             UUID NULL,
    completed_at            TIMESTAMPTZ NULL,

    created_by              UUID NULL,

    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_onboarding_app_branch
        FOREIGN KEY (branch_id)
        REFERENCES bmt_db.branches(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_onboarding_app_auth_user
        FOREIGN KEY (applicant_user_id)
        REFERENCES auth.users(id)
        ON UPDATE RESTRICT
        ON DELETE SET NULL,

    CONSTRAINT fk_onboarding_app_teller
        FOREIGN KEY (teller_reviewed_by)
        REFERENCES bmt_db.user_profiles(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_onboarding_app_manager
        FOREIGN KEY (manager_reviewed_by)
        REFERENCES bmt_db.user_profiles(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_onboarding_app_customer
        FOREIGN KEY (customer_id)
        REFERENCES bmt_db.customers(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_onboarding_app_created_by
        FOREIGN KEY (created_by)
        REFERENCES bmt_db.user_profiles(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT uq_onboarding_app_customer
        UNIQUE (customer_id),

    CONSTRAINT ck_onboarding_form_version
        CHECK (form_version >= 1),

    CONSTRAINT ck_onboarding_nik
        CHECK (
            nik IS NULL
            OR nik ~ '^[0-9]{16}$'
        ),

    CONSTRAINT ck_onboarding_full_name
        CHECK (
            full_name IS NULL
            OR btrim(full_name) <> ''
        ),

    CONSTRAINT ck_onboarding_birth_date
        CHECK (
            birth_date IS NULL
            OR birth_date <= CURRENT_DATE
        ),

    CONSTRAINT ck_onboarding_monthly_income
        CHECK (
            monthly_income IS NULL
            OR monthly_income >= 0
        ),

    CONSTRAINT ck_onboarding_monthly_expense
        CHECK (
            monthly_expense IS NULL
            OR monthly_expense >= 0
        ),

    CONSTRAINT ck_onboarding_completed
        CHECK (
            status <> 'COMPLETED'
            OR (
                customer_id IS NOT NULL
                AND completed_at IS NOT NULL
            )
        )
);

COMMENT ON TABLE bmt_db.onboarding_applications IS
'Digital onboarding application. CIF/customer master is created only after final approval.';

CREATE INDEX idx_onboarding_app_branch_status
    ON bmt_db.onboarding_applications(branch_id, status);

CREATE INDEX idx_onboarding_app_applicant
    ON bmt_db.onboarding_applications(applicant_user_id)
    WHERE applicant_user_id IS NOT NULL;

CREATE INDEX idx_onboarding_app_nik
    ON bmt_db.onboarding_applications(nik)
    WHERE nik IS NOT NULL;


-- ============================================================
-- 3. ONBOARDING ADDRESSES
-- ============================================================

CREATE TABLE bmt_db.onboarding_addresses (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    application_id      UUID NOT NULL,

    address_type        bmt_db.address_type NOT NULL,

    address             TEXT NOT NULL,

    province            VARCHAR(100) NULL,
    city                VARCHAR(100) NULL,
    district            VARCHAR(100) NULL,
    village             VARCHAR(100) NULL,
    postal_code         VARCHAR(10) NULL,

    rt                  VARCHAR(5) NULL,
    rw                  VARCHAR(5) NULL,

    is_primary          BOOLEAN NOT NULL DEFAULT FALSE,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_onboarding_address_app
        FOREIGN KEY (application_id)
        REFERENCES bmt_db.onboarding_applications(id)
        ON UPDATE RESTRICT
        ON DELETE CASCADE,

    CONSTRAINT ck_onboarding_address_value
        CHECK (btrim(address) <> ''),

    CONSTRAINT ck_onboarding_address_postal
        CHECK (
            postal_code IS NULL
            OR postal_code ~ '^[0-9]{5}$'
        ),

    CONSTRAINT ck_onboarding_address_rt
        CHECK (
            rt IS NULL
            OR rt ~ '^[0-9]{1,5}$'
        ),

    CONSTRAINT ck_onboarding_address_rw
        CHECK (
            rw IS NULL
            OR rw ~ '^[0-9]{1,5}$'
        )
);

CREATE INDEX idx_onboarding_address_app
    ON bmt_db.onboarding_addresses(application_id);


-- ============================================================
-- 4. EMPLOYMENT / BUSINESS
-- ============================================================

CREATE TABLE bmt_db.onboarding_employment (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    application_id          UUID NOT NULL UNIQUE,

    employment_type         VARCHAR(50) NULL,
    occupation              VARCHAR(100) NULL,

    employer_name           VARCHAR(150) NULL,
    position_name           VARCHAR(100) NULL,

    business_name           VARCHAR(150) NULL,
    business_type           VARCHAR(100) NULL,

    years_employed          INTEGER NULL,
    years_in_business       INTEGER NULL,

    office_address          TEXT NULL,
    office_phone            VARCHAR(30) NULL,

    monthly_income          bmt_db.money_amount NULL,
    other_monthly_income    bmt_db.money_amount NULL,

    income_source_detail    TEXT NULL,

    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_onboarding_employment_app
        FOREIGN KEY (application_id)
        REFERENCES bmt_db.onboarding_applications(id)
        ON UPDATE RESTRICT
        ON DELETE CASCADE,

    CONSTRAINT ck_onboarding_employment_years
        CHECK (
            (years_employed IS NULL OR years_employed >= 0)
            AND
            (years_in_business IS NULL OR years_in_business >= 0)
        ),

    CONSTRAINT ck_onboarding_employment_amounts
        CHECK (
            (monthly_income IS NULL OR monthly_income >= 0)
            AND
            (
                other_monthly_income IS NULL
                OR other_monthly_income >= 0
            )
        )
);


-- ============================================================
-- 5. FINANCIAL PROFILE
-- ============================================================

CREATE TABLE bmt_db.onboarding_financial_profiles (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    application_id              UUID NOT NULL UNIQUE,

    monthly_income              bmt_db.money_amount NULL,
    monthly_expense             bmt_db.money_amount NULL,

    total_assets                bmt_db.money_amount NULL,
    total_liabilities           bmt_db.money_amount NULL,

    source_of_funds             VARCHAR(150) NULL,
    source_of_wealth            VARCHAR(150) NULL,

    transaction_purpose         VARCHAR(200) NULL,

    expected_monthly_tx_count   INTEGER NULL,
    expected_monthly_tx_amount  bmt_db.money_amount NULL,

    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_onboarding_financial_app
        FOREIGN KEY (application_id)
        REFERENCES bmt_db.onboarding_applications(id)
        ON UPDATE RESTRICT
        ON DELETE CASCADE,

    CONSTRAINT ck_onboarding_financial_amounts
        CHECK (
            (monthly_income IS NULL OR monthly_income >= 0)
            AND
            (monthly_expense IS NULL OR monthly_expense >= 0)
            AND
            (total_assets IS NULL OR total_assets >= 0)
            AND
            (total_liabilities IS NULL OR total_liabilities >= 0)
            AND
            (
                expected_monthly_tx_amount IS NULL
                OR expected_monthly_tx_amount >= 0
            )
        ),

    CONSTRAINT ck_onboarding_financial_count
        CHECK (
            expected_monthly_tx_count IS NULL
            OR expected_monthly_tx_count >= 0
        )
);


-- ============================================================
-- 6. OTHER BANK ACCOUNTS
-- ============================================================

CREATE TABLE bmt_db.onboarding_bank_accounts (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    application_id      UUID NOT NULL,

    bank_name           VARCHAR(150) NOT NULL,

    account_type        VARCHAR(50) NULL,
    account_number      VARCHAR(100) NULL,
    account_name        VARCHAR(150) NULL,

    credit_card_class   VARCHAR(30) NULL,

    is_primary          BOOLEAN NOT NULL DEFAULT FALSE,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_onboarding_bank_app
        FOREIGN KEY (application_id)
        REFERENCES bmt_db.onboarding_applications(id)
        ON UPDATE RESTRICT
        ON DELETE CASCADE,

    CONSTRAINT ck_onboarding_bank_name
        CHECK (btrim(bank_name) <> '')
);

CREATE INDEX idx_onboarding_bank_app
    ON bmt_db.onboarding_bank_accounts(application_id);


-- ============================================================
-- 7. PRODUCT REQUESTS
-- ============================================================

CREATE TABLE bmt_db.onboarding_product_requests (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    application_id          UUID NOT NULL,
    product_id              UUID NOT NULL,

    status                  bmt_db.onboarding_product_status
                            NOT NULL DEFAULT 'REQUESTED',

    requested_amount        bmt_db.money_amount NULL,
    requested_tenor_months  INTEGER NULL,

    purpose                 TEXT NULL,

    -- Deposit-specific requested instructions.
    rollover_type           VARCHAR(30) NULL,
    profit_payment_method   VARCHAR(50) NULL,
    destination_account     VARCHAR(100) NULL,

    reviewed_by             UUID NULL,
    reviewed_at             TIMESTAMPTZ NULL,
    review_notes            TEXT NULL,

    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_onboarding_product_app
        FOREIGN KEY (application_id)
        REFERENCES bmt_db.onboarding_applications(id)
        ON UPDATE RESTRICT
        ON DELETE CASCADE,

    CONSTRAINT fk_onboarding_product_master
        FOREIGN KEY (product_id)
        REFERENCES bmt_db.products(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_onboarding_product_reviewer
        FOREIGN KEY (reviewed_by)
        REFERENCES bmt_db.user_profiles(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT uq_onboarding_product
        UNIQUE (application_id, product_id),

    CONSTRAINT ck_onboarding_product_amount
        CHECK (
            requested_amount IS NULL
            OR requested_amount >= 0
        ),

    CONSTRAINT ck_onboarding_product_tenor
        CHECK (
            requested_tenor_months IS NULL
            OR requested_tenor_months > 0
        )
);

CREATE INDEX idx_onboarding_product_app
    ON bmt_db.onboarding_product_requests(application_id);


-- ============================================================
-- 8. DOCUMENTS
-- ============================================================

CREATE TABLE bmt_db.onboarding_documents (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    application_id      UUID NOT NULL,

    document_type       VARCHAR(50) NOT NULL,
    document_number     VARCHAR(100) NULL,

    storage_bucket      VARCHAR(100) NOT NULL,
    storage_path        TEXT NOT NULL,

    mime_type           VARCHAR(100) NULL,
    file_size_bytes     BIGINT NULL,
    sha256              VARCHAR(64) NULL,

    issued_at           DATE NULL,
    expired_at          DATE NULL,

    status              bmt_db.onboarding_document_status
                        NOT NULL DEFAULT 'UPLOADED',

    verified_by         UUID NULL,
    verified_at         TIMESTAMPTZ NULL,
    verification_notes  TEXT NULL,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_onboarding_document_app
        FOREIGN KEY (application_id)
        REFERENCES bmt_db.onboarding_applications(id)
        ON UPDATE RESTRICT
        ON DELETE CASCADE,

    CONSTRAINT fk_onboarding_document_verifier
        FOREIGN KEY (verified_by)
        REFERENCES bmt_db.user_profiles(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT ck_onboarding_document_type
        CHECK (
            document_type ~ '^[A-Z][A-Z0-9_]*$'
        ),

    CONSTRAINT ck_onboarding_document_storage
        CHECK (
            btrim(storage_bucket) <> ''
            AND btrim(storage_path) <> ''
        ),

    CONSTRAINT ck_onboarding_document_sha256
        CHECK (
            sha256 IS NULL
            OR sha256 ~ '^[0-9a-fA-F]{64}$'
        ),

    CONSTRAINT ck_onboarding_document_size
        CHECK (
            file_size_bytes IS NULL
            OR file_size_bytes >= 0
        ),

    CONSTRAINT ck_onboarding_document_expiry
        CHECK (
            expired_at IS NULL
            OR issued_at IS NULL
            OR expired_at >= issued_at
        )
);

CREATE INDEX idx_onboarding_document_app
    ON bmt_db.onboarding_documents(application_id);


-- ============================================================
-- 9. SIGNATURES
-- ============================================================

CREATE TABLE bmt_db.onboarding_signatures (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    application_id          UUID NOT NULL,

    signer_role             bmt_db.onboarding_signature_role NOT NULL,
    signer_user_id          UUID NOT NULL,

    signed_version          INTEGER NOT NULL,

    storage_bucket          VARCHAR(100) NOT NULL,
    storage_path            TEXT NOT NULL,

    signature_sha256        VARCHAR(64) NOT NULL,

    signed_at               TIMESTAMPTZ NOT NULL DEFAULT now(),

    ip_address              INET NULL,
    user_agent              TEXT NULL,

    is_valid                BOOLEAN NOT NULL DEFAULT TRUE,
    invalidated_at          TIMESTAMPTZ NULL,
    invalidation_reason     TEXT NULL,

    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_onboarding_signature_app
        FOREIGN KEY (application_id)
        REFERENCES bmt_db.onboarding_applications(id)
        ON UPDATE RESTRICT
        ON DELETE CASCADE,

    CONSTRAINT fk_onboarding_signature_user
        FOREIGN KEY (signer_user_id)
        REFERENCES auth.users(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT ck_onboarding_signature_version
        CHECK (signed_version >= 1),

    CONSTRAINT ck_onboarding_signature_storage
        CHECK (
            btrim(storage_bucket) <> ''
            AND btrim(storage_path) <> ''
        ),

    CONSTRAINT ck_onboarding_signature_sha256
        CHECK (
            signature_sha256 ~ '^[0-9a-fA-F]{64}$'
        ),

    CONSTRAINT ck_onboarding_signature_invalidation
        CHECK (
            is_valid = TRUE
            OR invalidated_at IS NOT NULL
        )
);

CREATE UNIQUE INDEX uq_onboarding_valid_signature
    ON bmt_db.onboarding_signatures(
        application_id,
        signer_role
    )
    WHERE is_valid = TRUE;

CREATE INDEX idx_onboarding_signature_app
    ON bmt_db.onboarding_signatures(application_id);


-- ============================================================
-- 10. STATUS HISTORY
-- ============================================================

CREATE TABLE bmt_db.onboarding_status_history (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    application_id      UUID NOT NULL,

    from_status         bmt_db.onboarding_status NULL,
    to_status           bmt_db.onboarding_status NOT NULL,

    changed_by          UUID NULL,

    reason              TEXT NULL,

    metadata            JSONB NOT NULL DEFAULT '{}'::jsonb,

    changed_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_onboarding_history_app
        FOREIGN KEY (application_id)
        REFERENCES bmt_db.onboarding_applications(id)
        ON UPDATE RESTRICT
        ON DELETE CASCADE,

    CONSTRAINT fk_onboarding_history_user
        FOREIGN KEY (changed_by)
        REFERENCES auth.users(id)
        ON UPDATE RESTRICT
        ON DELETE SET NULL
);

CREATE INDEX idx_onboarding_history_app
    ON bmt_db.onboarding_status_history(
        application_id,
        changed_at
    );


-- ============================================================
-- 11. ONBOARDING PERMISSIONS
-- ============================================================

INSERT INTO bmt_db.permissions (
    code,
    module,
    description
)
VALUES
(
    'onboarding.view',
    'onboarding',
    'View customer onboarding applications'
),
(
    'onboarding.create',
    'onboarding',
    'Create and maintain customer onboarding drafts'
),
(
    'onboarding.teller.verify',
    'onboarding',
    'Verify and sign onboarding as teller'
),
(
    'onboarding.manager.approve',
    'onboarding',
    'Approve and sign onboarding as manager'
),
(
    'onboarding.finalize',
    'onboarding',
    'Finalize approved onboarding into customer CIF'
)
ON CONFLICT (code) DO NOTHING;


-- SUPERADMIN

INSERT INTO bmt_db.role_permissions (
    role_id,
    permission_id
)
SELECT
    r.id,
    p.id
FROM bmt_db.roles r
CROSS JOIN bmt_db.permissions p
WHERE r.code = 'SUPERADMIN'
  AND p.code LIKE 'onboarding.%'
ON CONFLICT DO NOTHING;


-- MANAGER

INSERT INTO bmt_db.role_permissions (
    role_id,
    permission_id
)
SELECT
    r.id,
    p.id
FROM bmt_db.roles r
JOIN bmt_db.permissions p
  ON p.code IN (
      'onboarding.view',
      'onboarding.manager.approve',
      'onboarding.finalize'
  )
WHERE r.code = 'MANAGER'
ON CONFLICT DO NOTHING;


-- MARKETING

INSERT INTO bmt_db.role_permissions (
    role_id,
    permission_id
)
SELECT
    r.id,
    p.id
FROM bmt_db.roles r
JOIN bmt_db.permissions p
  ON p.code IN (
      'onboarding.view',
      'onboarding.create'
  )
WHERE r.code = 'MARKETING'
ON CONFLICT DO NOTHING;


-- TELLER

INSERT INTO bmt_db.role_permissions (
    role_id,
    permission_id
)
SELECT
    r.id,
    p.id
FROM bmt_db.roles r
JOIN bmt_db.permissions p
  ON p.code IN (
      'onboarding.view',
      'onboarding.create',
      'onboarding.teller.verify'
  )
WHERE r.code = 'TELLER'
ON CONFLICT DO NOTHING;


-- ============================================================
-- 12. ACCESS HELPER
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.current_user_can_access_onboarding(
    p_application_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM bmt_db.onboarding_applications oa
        WHERE oa.id = p_application_id
          AND (
              oa.applicant_user_id = auth.uid()

              OR bmt_db.current_user_is_superadmin()

              OR (
                  bmt_db.current_user_has_branch_access(
                      oa.branch_id
                  )
                  AND bmt_db.current_user_has_permission(
                      'onboarding.view',
                      oa.branch_id
                  )
              )
          )
    );
$$;

REVOKE ALL
ON FUNCTION bmt_db.current_user_can_access_onboarding(UUID)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION bmt_db.current_user_can_access_onboarding(UUID)
TO authenticated;


CREATE OR REPLACE FUNCTION bmt_db.current_user_can_edit_onboarding(
    p_application_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM bmt_db.onboarding_applications oa
        WHERE oa.id = p_application_id
          AND oa.status IN ('DRAFT', 'RETURNED')
          AND (
              oa.applicant_user_id = auth.uid()

              OR bmt_db.current_user_is_superadmin()

              OR (
                  bmt_db.current_user_has_branch_access(
                      oa.branch_id
                  )
                  AND bmt_db.current_user_has_permission(
                      'onboarding.create',
                      oa.branch_id
                  )
              )
          )
    );
$$;

REVOKE ALL
ON FUNCTION bmt_db.current_user_can_edit_onboarding(UUID)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION bmt_db.current_user_can_edit_onboarding(UUID)
TO authenticated;


-- ============================================================
-- 13. INVALIDATE SIGNATURES
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.invalidate_onboarding_signatures(
    p_application_id UUID,
    p_reason TEXT DEFAULT 'FORM_CHANGED'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    UPDATE bmt_db.onboarding_signatures
       SET is_valid = FALSE,
           invalidated_at = now(),
           invalidation_reason =
               COALESCE(
                   NULLIF(btrim(p_reason), ''),
                   'FORM_CHANGED'
               )
     WHERE application_id = p_application_id
       AND is_valid = TRUE;
END;
$$;

REVOKE ALL
ON FUNCTION bmt_db.invalidate_onboarding_signatures(UUID, TEXT)
FROM PUBLIC, anon, authenticated;


-- ============================================================
-- 14. CHILD MATERIAL CHANGE TRIGGER
-- ============================================================

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

    UPDATE bmt_db.onboarding_applications
       SET form_version = form_version + 1,
           updated_at = now()
     WHERE id = v_application_id;

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


CREATE TRIGGER trg_onboarding_address_material
AFTER INSERT OR UPDATE OR DELETE
ON bmt_db.onboarding_addresses
FOR EACH ROW
EXECUTE FUNCTION bmt_db.touch_onboarding_material_change();

CREATE TRIGGER trg_onboarding_employment_material
AFTER INSERT OR UPDATE OR DELETE
ON bmt_db.onboarding_employment
FOR EACH ROW
EXECUTE FUNCTION bmt_db.touch_onboarding_material_change();

CREATE TRIGGER trg_onboarding_financial_material
AFTER INSERT OR UPDATE OR DELETE
ON bmt_db.onboarding_financial_profiles
FOR EACH ROW
EXECUTE FUNCTION bmt_db.touch_onboarding_material_change();

CREATE TRIGGER trg_onboarding_bank_material
AFTER INSERT OR UPDATE OR DELETE
ON bmt_db.onboarding_bank_accounts
FOR EACH ROW
EXECUTE FUNCTION bmt_db.touch_onboarding_material_change();

CREATE TRIGGER trg_onboarding_product_material
AFTER INSERT OR UPDATE OR DELETE
ON bmt_db.onboarding_product_requests
FOR EACH ROW
EXECUTE FUNCTION bmt_db.touch_onboarding_material_change();

CREATE TRIGGER trg_onboarding_document_material
AFTER INSERT OR UPDATE OR DELETE
ON bmt_db.onboarding_documents
FOR EACH ROW
EXECUTE FUNCTION bmt_db.touch_onboarding_material_change();


-- ============================================================
-- 15. MAIN APPLICATION GUARD
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.onboarding_application_guard()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_workflow BOOLEAN;
BEGIN
    v_workflow :=
        COALESCE(
            current_setting(
                'bmt.onboarding_workflow',
                TRUE
            ),
            ''
        ) = '1';

    IF NOT v_workflow THEN

        -- Workflow/system-controlled fields cannot be edited
        -- directly from PostgREST/table updates.

        IF
            NEW.status IS DISTINCT FROM OLD.status
            OR NEW.form_version IS DISTINCT FROM OLD.form_version
            OR NEW.submitted_at IS DISTINCT FROM OLD.submitted_at
            OR NEW.teller_reviewed_by
                IS DISTINCT FROM OLD.teller_reviewed_by
            OR NEW.teller_reviewed_at
                IS DISTINCT FROM OLD.teller_reviewed_at
            OR NEW.manager_reviewed_by
                IS DISTINCT FROM OLD.manager_reviewed_by
            OR NEW.manager_reviewed_at
                IS DISTINCT FROM OLD.manager_reviewed_at
            OR NEW.approved_at IS DISTINCT FROM OLD.approved_at
            OR NEW.return_reason IS DISTINCT FROM OLD.return_reason
            OR NEW.rejection_reason
                IS DISTINCT FROM OLD.rejection_reason
            OR NEW.customer_id IS DISTINCT FROM OLD.customer_id
            OR NEW.completed_at IS DISTINCT FROM OLD.completed_at
            OR NEW.branch_id IS DISTINCT FROM OLD.branch_id
            OR NEW.applicant_user_id
                IS DISTINCT FROM OLD.applicant_user_id
            OR NEW.created_by IS DISTINCT FROM OLD.created_by
        THEN
            RAISE EXCEPTION
                'Workflow-controlled onboarding fields cannot be changed directly';
        END IF;

        IF OLD.status NOT IN ('DRAFT', 'RETURNED') THEN
            RAISE EXCEPTION
                'Application cannot be edited in status %',
                OLD.status;
        END IF;

        -- Any permitted main-row update represents a new form
        -- version. This intentionally favors audit safety over
        -- micro-optimizing field comparisons.

        NEW.form_version := OLD.form_version + 1;

        PERFORM bmt_db.invalidate_onboarding_signatures(
            OLD.id,
            'FORM_CHANGED'
        );
    END IF;

    NEW.updated_at := now();

    RETURN NEW;
END;
$$;

REVOKE ALL
ON FUNCTION bmt_db.onboarding_application_guard()
FROM PUBLIC, anon, authenticated;

CREATE TRIGGER trg_onboarding_application_guard
BEFORE UPDATE
ON bmt_db.onboarding_applications
FOR EACH ROW
EXECUTE FUNCTION bmt_db.onboarding_application_guard();


-- ============================================================
-- 16. SIGN APPLICATION RPC
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.sign_onboarding_application(
    p_application_id UUID,
    p_signer_role bmt_db.onboarding_signature_role,
    p_storage_bucket TEXT,
    p_storage_path TEXT,
    p_signature_sha256 TEXT,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_app               bmt_db.onboarding_applications%ROWTYPE;
    v_signature_id      UUID;
    v_signer_profile_id UUID;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    IF NULLIF(btrim(p_storage_bucket), '') IS NULL
       OR NULLIF(btrim(p_storage_path), '') IS NULL THEN
        RAISE EXCEPTION
            'Signature storage bucket/path is required';
    END IF;

    IF p_signature_sha256 IS NULL
       OR p_signature_sha256 !~ '^[0-9a-fA-F]{64}$' THEN
        RAISE EXCEPTION
            'Valid SHA-256 signature hash is required';
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

    IF p_signer_role = 'CUSTOMER' THEN

        IF v_app.applicant_user_id IS DISTINCT FROM auth.uid() THEN
            RAISE EXCEPTION
                'Only application owner may sign as customer';
        END IF;

        IF v_app.status NOT IN ('DRAFT', 'RETURNED') THEN
            RAISE EXCEPTION
                'Customer signature is not allowed in status %',
                v_app.status;
        END IF;

    ELSIF p_signer_role = 'TELLER' THEN

        IF v_app.status <> 'TELLER_REVIEW' THEN
            RAISE EXCEPTION
                'Teller signature requires TELLER_REVIEW';
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

        SELECT up.id
          INTO v_signer_profile_id
          FROM bmt_db.user_profiles up
         WHERE up.id = auth.uid()
           AND up.is_active = TRUE;

        IF v_signer_profile_id IS NULL THEN
            RAISE EXCEPTION
                'Active teller user profile required';
        END IF;

    ELSIF p_signer_role = 'MANAGER' THEN

        IF v_app.status <> 'MANAGER_REVIEW' THEN
            RAISE EXCEPTION
                'Manager signature requires MANAGER_REVIEW';
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

        SELECT up.id
          INTO v_signer_profile_id
          FROM bmt_db.user_profiles up
         WHERE up.id = auth.uid()
           AND up.is_active = TRUE;

        IF v_signer_profile_id IS NULL THEN
            RAISE EXCEPTION
                'Active manager user profile required';
        END IF;

        IF v_app.teller_reviewed_by = auth.uid() THEN
            RAISE EXCEPTION
                'Maker-checker violation: teller and manager must be different users';
        END IF;

    END IF;

    UPDATE bmt_db.onboarding_signatures
       SET is_valid = FALSE,
           invalidated_at = now(),
           invalidation_reason = 'REPLACED'
     WHERE application_id = p_application_id
       AND signer_role = p_signer_role
       AND is_valid = TRUE;

    INSERT INTO bmt_db.onboarding_signatures (
        application_id,
        signer_role,
        signer_user_id,
        signed_version,
        storage_bucket,
        storage_path,
        signature_sha256,
        ip_address,
        user_agent
    )
    VALUES (
        p_application_id,
        p_signer_role,
        auth.uid(),
        v_app.form_version,
        p_storage_bucket,
        p_storage_path,
        lower(p_signature_sha256),
        p_ip_address,
        p_user_agent
    )
    RETURNING id
      INTO v_signature_id;

    RETURN v_signature_id;
END;
$$;

REVOKE ALL
ON FUNCTION bmt_db.sign_onboarding_application(
    UUID,
    bmt_db.onboarding_signature_role,
    TEXT,
    TEXT,
    TEXT,
    INET,
    TEXT
)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION bmt_db.sign_onboarding_application(
    UUID,
    bmt_db.onboarding_signature_role,
    TEXT,
    TEXT,
    TEXT,
    INET,
    TEXT
)
TO authenticated;


-- ============================================================
-- 17. SUBMIT APPLICATION RPC
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.submit_onboarding_application(
    p_application_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
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
$$;

REVOKE ALL
ON FUNCTION bmt_db.submit_onboarding_application(UUID)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION bmt_db.submit_onboarding_application(UUID)
TO authenticated;


-- ============================================================
-- 18. TELLER REVIEW RPC
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.complete_teller_onboarding_review(
    p_application_id UUID,
    p_approve BOOLEAN,
    p_reason TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
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
$$;

REVOKE ALL
ON FUNCTION bmt_db.complete_teller_onboarding_review(
    UUID,
    BOOLEAN,
    TEXT
)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION bmt_db.complete_teller_onboarding_review(
    UUID,
    BOOLEAN,
    TEXT
)
TO authenticated;


-- ============================================================
-- 19. MANAGER REVIEW RPC
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.complete_manager_onboarding_review(
    p_application_id UUID,
    p_approve BOOLEAN,
    p_reason TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
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
$$;

REVOKE ALL
ON FUNCTION bmt_db.complete_manager_onboarding_review(
    UUID,
    BOOLEAN,
    TEXT
)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION bmt_db.complete_manager_onboarding_review(
    UUID,
    BOOLEAN,
    TEXT
)
TO authenticated;


-- ============================================================
-- 20. FINALIZE APPLICATION / CREATE CIF
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.finalize_onboarding_application(
    p_application_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
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
$$;

REVOKE ALL
ON FUNCTION bmt_db.finalize_onboarding_application(UUID)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION bmt_db.finalize_onboarding_application(UUID)
TO authenticated;


-- ============================================================
-- 21. ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE bmt_db.onboarding_applications
    ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.onboarding_applications
    FORCE ROW LEVEL SECURITY;

ALTER TABLE bmt_db.onboarding_addresses
    ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.onboarding_addresses
    FORCE ROW LEVEL SECURITY;

ALTER TABLE bmt_db.onboarding_employment
    ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.onboarding_employment
    FORCE ROW LEVEL SECURITY;

ALTER TABLE bmt_db.onboarding_financial_profiles
    ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.onboarding_financial_profiles
    FORCE ROW LEVEL SECURITY;

ALTER TABLE bmt_db.onboarding_bank_accounts
    ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.onboarding_bank_accounts
    FORCE ROW LEVEL SECURITY;

ALTER TABLE bmt_db.onboarding_product_requests
    ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.onboarding_product_requests
    FORCE ROW LEVEL SECURITY;

ALTER TABLE bmt_db.onboarding_documents
    ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.onboarding_documents
    FORCE ROW LEVEL SECURITY;

ALTER TABLE bmt_db.onboarding_signatures
    ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.onboarding_signatures
    FORCE ROW LEVEL SECURITY;

ALTER TABLE bmt_db.onboarding_status_history
    ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.onboarding_status_history
    FORCE ROW LEVEL SECURITY;


-- ============================================================
-- 22. MAIN APPLICATION RLS
-- ============================================================

CREATE POLICY onboarding_applications_select
ON bmt_db.onboarding_applications
FOR SELECT
TO authenticated
USING (
    applicant_user_id = auth.uid()

    OR bmt_db.current_user_is_superadmin()

    OR (
        bmt_db.current_user_has_branch_access(branch_id)
        AND bmt_db.current_user_has_permission(
            'onboarding.view',
            branch_id
        )
    )
);


CREATE POLICY onboarding_applications_insert
ON bmt_db.onboarding_applications
FOR INSERT
TO authenticated
WITH CHECK (
    (
        applicant_user_id = auth.uid()
        AND status = 'DRAFT'
    )

    OR bmt_db.current_user_is_superadmin()

    OR (
        status = 'DRAFT'
        AND bmt_db.current_user_has_branch_access(branch_id)
        AND bmt_db.current_user_has_permission(
            'onboarding.create',
            branch_id
        )
    )
);


CREATE POLICY onboarding_applications_update
ON bmt_db.onboarding_applications
FOR UPDATE
TO authenticated
USING (
    (
        applicant_user_id = auth.uid()
        AND status IN ('DRAFT', 'RETURNED')
    )

    OR bmt_db.current_user_is_superadmin()

    OR (
        status IN ('DRAFT', 'RETURNED')
        AND bmt_db.current_user_has_branch_access(branch_id)
        AND bmt_db.current_user_has_permission(
            'onboarding.create',
            branch_id
        )
    )
)
WITH CHECK (
    applicant_user_id = auth.uid()

    OR bmt_db.current_user_is_superadmin()

    OR (
        bmt_db.current_user_has_branch_access(branch_id)
        AND bmt_db.current_user_has_permission(
            'onboarding.create',
            branch_id
        )
    )
);


-- ============================================================
-- 23. CHILD SELECT RLS
-- ============================================================

CREATE POLICY onboarding_addresses_select
ON bmt_db.onboarding_addresses
FOR SELECT TO authenticated
USING (
    bmt_db.current_user_can_access_onboarding(application_id)
);

CREATE POLICY onboarding_employment_select
ON bmt_db.onboarding_employment
FOR SELECT TO authenticated
USING (
    bmt_db.current_user_can_access_onboarding(application_id)
);

CREATE POLICY onboarding_financial_select
ON bmt_db.onboarding_financial_profiles
FOR SELECT TO authenticated
USING (
    bmt_db.current_user_can_access_onboarding(application_id)
);

CREATE POLICY onboarding_bank_select
ON bmt_db.onboarding_bank_accounts
FOR SELECT TO authenticated
USING (
    bmt_db.current_user_can_access_onboarding(application_id)
);

CREATE POLICY onboarding_products_select
ON bmt_db.onboarding_product_requests
FOR SELECT TO authenticated
USING (
    bmt_db.current_user_can_access_onboarding(application_id)
);

CREATE POLICY onboarding_documents_select
ON bmt_db.onboarding_documents
FOR SELECT TO authenticated
USING (
    bmt_db.current_user_can_access_onboarding(application_id)
);

CREATE POLICY onboarding_signatures_select
ON bmt_db.onboarding_signatures
FOR SELECT TO authenticated
USING (
    bmt_db.current_user_can_access_onboarding(application_id)
);

CREATE POLICY onboarding_history_select
ON bmt_db.onboarding_status_history
FOR SELECT TO authenticated
USING (
    bmt_db.current_user_can_access_onboarding(application_id)
);


-- ============================================================
-- 24. CHILD EDIT RLS
-- ============================================================

CREATE POLICY onboarding_addresses_insert
ON bmt_db.onboarding_addresses
FOR INSERT TO authenticated
WITH CHECK (
    bmt_db.current_user_can_edit_onboarding(application_id)
);

CREATE POLICY onboarding_addresses_update
ON bmt_db.onboarding_addresses
FOR UPDATE TO authenticated
USING (
    bmt_db.current_user_can_edit_onboarding(application_id)
)
WITH CHECK (
    bmt_db.current_user_can_edit_onboarding(application_id)
);

CREATE POLICY onboarding_addresses_delete
ON bmt_db.onboarding_addresses
FOR DELETE TO authenticated
USING (
    bmt_db.current_user_can_edit_onboarding(application_id)
);


CREATE POLICY onboarding_employment_insert
ON bmt_db.onboarding_employment
FOR INSERT TO authenticated
WITH CHECK (
    bmt_db.current_user_can_edit_onboarding(application_id)
);

CREATE POLICY onboarding_employment_update
ON bmt_db.onboarding_employment
FOR UPDATE TO authenticated
USING (
    bmt_db.current_user_can_edit_onboarding(application_id)
)
WITH CHECK (
    bmt_db.current_user_can_edit_onboarding(application_id)
);

CREATE POLICY onboarding_employment_delete
ON bmt_db.onboarding_employment
FOR DELETE TO authenticated
USING (
    bmt_db.current_user_can_edit_onboarding(application_id)
);


CREATE POLICY onboarding_financial_insert
ON bmt_db.onboarding_financial_profiles
FOR INSERT TO authenticated
WITH CHECK (
    bmt_db.current_user_can_edit_onboarding(application_id)
);

CREATE POLICY onboarding_financial_update
ON bmt_db.onboarding_financial_profiles
FOR UPDATE TO authenticated
USING (
    bmt_db.current_user_can_edit_onboarding(application_id)
)
WITH CHECK (
    bmt_db.current_user_can_edit_onboarding(application_id)
);

CREATE POLICY onboarding_financial_delete
ON bmt_db.onboarding_financial_profiles
FOR DELETE TO authenticated
USING (
    bmt_db.current_user_can_edit_onboarding(application_id)
);


CREATE POLICY onboarding_bank_insert
ON bmt_db.onboarding_bank_accounts
FOR INSERT TO authenticated
WITH CHECK (
    bmt_db.current_user_can_edit_onboarding(application_id)
);

CREATE POLICY onboarding_bank_update
ON bmt_db.onboarding_bank_accounts
FOR UPDATE TO authenticated
USING (
    bmt_db.current_user_can_edit_onboarding(application_id)
)
WITH CHECK (
    bmt_db.current_user_can_edit_onboarding(application_id)
);

CREATE POLICY onboarding_bank_delete
ON bmt_db.onboarding_bank_accounts
FOR DELETE TO authenticated
USING (
    bmt_db.current_user_can_edit_onboarding(application_id)
);


CREATE POLICY onboarding_products_insert
ON bmt_db.onboarding_product_requests
FOR INSERT TO authenticated
WITH CHECK (
    bmt_db.current_user_can_edit_onboarding(application_id)
);

CREATE POLICY onboarding_products_update
ON bmt_db.onboarding_product_requests
FOR UPDATE TO authenticated
USING (
    bmt_db.current_user_can_edit_onboarding(application_id)
)
WITH CHECK (
    bmt_db.current_user_can_edit_onboarding(application_id)
);

CREATE POLICY onboarding_products_delete
ON bmt_db.onboarding_product_requests
FOR DELETE TO authenticated
USING (
    bmt_db.current_user_can_edit_onboarding(application_id)
);


CREATE POLICY onboarding_documents_insert
ON bmt_db.onboarding_documents
FOR INSERT TO authenticated
WITH CHECK (
    bmt_db.current_user_can_edit_onboarding(application_id)
);

CREATE POLICY onboarding_documents_update
ON bmt_db.onboarding_documents
FOR UPDATE TO authenticated
USING (
    bmt_db.current_user_can_edit_onboarding(application_id)
)
WITH CHECK (
    bmt_db.current_user_can_edit_onboarding(application_id)
);

CREATE POLICY onboarding_documents_delete
ON bmt_db.onboarding_documents
FOR DELETE TO authenticated
USING (
    bmt_db.current_user_can_edit_onboarding(application_id)
);


-- Signatures and status history intentionally have no direct
-- INSERT/UPDATE/DELETE policies. Workflow RPCs own these writes.


-- ============================================================
-- 25. TABLE PRIVILEGES
-- ============================================================

GRANT SELECT, INSERT, UPDATE
ON bmt_db.onboarding_applications
TO authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE
ON bmt_db.onboarding_addresses
TO authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE
ON bmt_db.onboarding_employment
TO authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE
ON bmt_db.onboarding_financial_profiles
TO authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE
ON bmt_db.onboarding_bank_accounts
TO authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE
ON bmt_db.onboarding_product_requests
TO authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE
ON bmt_db.onboarding_documents
TO authenticated;

GRANT SELECT
ON bmt_db.onboarding_signatures
TO authenticated;

GRANT SELECT
ON bmt_db.onboarding_status_history
TO authenticated;


-- ============================================================
-- 26. COMMENTS
-- ============================================================

COMMENT ON TABLE bmt_db.onboarding_signatures IS
'Version-bound customer/teller/manager signature metadata. Signature files remain in private object storage.';

COMMENT ON TABLE bmt_db.onboarding_product_requests IS
'Products requested during onboarding. Approval does not itself open or post a financial account.';

COMMENT ON COLUMN bmt_db.onboarding_applications.form_version IS
'Incremented whenever material form data changes. Existing signatures are invalidated.';

COMMIT;
