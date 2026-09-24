-- ============================================================
-- BMT CORE BANKING SYSTEM
-- Migration : 003_bmt_customer_product.sql
-- Purpose   : Customer/CIF and financial product master
-- Version   : 1.0.0
-- Requires  : 001_bmt_schema.sql
--             002_bmt_identity.sql
-- ============================================================

BEGIN;


-- ============================================================
-- 1. CUSTOMERS / CIF
-- ============================================================

CREATE TABLE bmt_db.customers (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    cif_number              VARCHAR(20) NOT NULL,
    nik                     VARCHAR(16) NULL,

    full_name               VARCHAR(150) NOT NULL,

    birth_place             VARCHAR(100) NULL,
    birth_date              DATE NULL,

    gender                  bmt_db.gender_type NULL,
    marital_status          VARCHAR(30) NULL,

    mother_name             VARCHAR(150) NULL,

    occupation              VARCHAR(100) NULL,
    monthly_income          bmt_db.money_amount NULL,

    phone                   VARCHAR(30) NULL,
    email                   VARCHAR(255) NULL,

    branch_id               UUID NOT NULL,

    status                  bmt_db.customer_status
                            NOT NULL DEFAULT 'PROSPECT',

    registered_at           TIMESTAMPTZ NULL,

    created_by              UUID NULL,

    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uq_customers_cif
        UNIQUE (cif_number),

    CONSTRAINT uq_customers_nik
        UNIQUE (nik),

    CONSTRAINT fk_customers_branch
        FOREIGN KEY (branch_id)
        REFERENCES bmt_db.branches(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_customers_created_by
        FOREIGN KEY (created_by)
        REFERENCES bmt_db.user_profiles(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT ck_customers_cif
        CHECK (
            cif_number ~ '^[0-9]+$'
        ),

    CONSTRAINT ck_customers_nik
        CHECK (
            nik IS NULL
            OR nik ~ '^[0-9]{16}$'
        ),

    CONSTRAINT ck_customers_name
        CHECK (
            btrim(full_name) <> ''
        ),

    CONSTRAINT ck_customers_birth_date
        CHECK (
            birth_date IS NULL
            OR birth_date <= CURRENT_DATE
        )
);

COMMENT ON TABLE bmt_db.customers IS
'Master nasabah/anggota BMT. Satu customer memiliki satu CIF dan dapat memiliki banyak rekening.';

COMMENT ON COLUMN bmt_db.customers.cif_number IS
'Customer Information File number; business identifier, not primary key.';

COMMENT ON COLUMN bmt_db.customers.nik IS
'NIK Indonesia 16 digit. NULL diperbolehkan untuk prospect yang datanya belum lengkap.';


-- ============================================================
-- 2. CUSTOMER ADDRESSES
-- ============================================================

CREATE TABLE bmt_db.customer_addresses (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    customer_id         UUID NOT NULL,

    address_type        bmt_db.address_type NOT NULL,

    address             TEXT NOT NULL,

    province            VARCHAR(100) NULL,
    city                VARCHAR(100) NULL,
    district            VARCHAR(100) NULL,
    village             VARCHAR(100) NULL,
    postal_code         VARCHAR(10) NULL,

    is_primary          BOOLEAN NOT NULL DEFAULT FALSE,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_customer_addresses_customer
        FOREIGN KEY (customer_id)
        REFERENCES bmt_db.customers(id)
        ON UPDATE RESTRICT
        ON DELETE CASCADE,

    CONSTRAINT ck_customer_addresses_address
        CHECK (
            btrim(address) <> ''
        ),

    CONSTRAINT ck_customer_addresses_postal
        CHECK (
            postal_code IS NULL
            OR postal_code ~ '^[0-9]{5}$'
        )
);

COMMENT ON TABLE bmt_db.customer_addresses IS
'Alamat KTP, domisili, atau usaha milik customer.';


-- ============================================================
-- 3. CUSTOMER DOCUMENTS
-- ============================================================

CREATE TABLE bmt_db.customer_documents (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    customer_id         UUID NOT NULL,

    document_type       VARCHAR(50) NOT NULL,
    document_number     VARCHAR(100) NULL,

    storage_bucket      VARCHAR(100) NULL,
    storage_path        TEXT NULL,

    issued_at           DATE NULL,
    expired_at          DATE NULL,

    verified_at         TIMESTAMPTZ NULL,
    verified_by         UUID NULL,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_customer_documents_customer
        FOREIGN KEY (customer_id)
        REFERENCES bmt_db.customers(id)
        ON UPDATE RESTRICT
        ON DELETE CASCADE,

    CONSTRAINT fk_customer_documents_verified_by
        FOREIGN KEY (verified_by)
        REFERENCES bmt_db.user_profiles(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT ck_customer_documents_type
        CHECK (
            document_type ~ '^[A-Z][A-Z0-9_]*$'
        ),

    CONSTRAINT ck_customer_documents_expiry
        CHECK (
            expired_at IS NULL
            OR issued_at IS NULL
            OR expired_at >= issued_at
        ),

    CONSTRAINT ck_customer_documents_storage
        CHECK (
            (storage_bucket IS NULL AND storage_path IS NULL)
            OR
            (storage_bucket IS NOT NULL AND storage_path IS NOT NULL)
        )
);

COMMENT ON TABLE bmt_db.customer_documents IS
'Metadata dokumen customer. File fisik disimpan di Supabase Storage, bukan PostgreSQL BYTEA.';


-- ============================================================
-- 4. CUSTOMER MARKETING ASSIGNMENT
-- ============================================================

CREATE TABLE bmt_db.customer_marketing (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    customer_id             UUID NOT NULL,
    marketing_user_id       UUID NOT NULL,

    assigned_from           TIMESTAMPTZ NOT NULL DEFAULT now(),
    assigned_until          TIMESTAMPTZ NULL,

    is_active               BOOLEAN NOT NULL DEFAULT TRUE,

    assigned_by             UUID NULL,

    notes                   TEXT NULL,

    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_customer_marketing_customer
        FOREIGN KEY (customer_id)
        REFERENCES bmt_db.customers(id)
        ON UPDATE RESTRICT
        ON DELETE CASCADE,

    CONSTRAINT fk_customer_marketing_user
        FOREIGN KEY (marketing_user_id)
        REFERENCES bmt_db.user_profiles(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_customer_marketing_assigned_by
        FOREIGN KEY (assigned_by)
        REFERENCES bmt_db.user_profiles(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT ck_customer_marketing_period
        CHECK (
            assigned_until IS NULL
            OR assigned_until > assigned_from
        )
);

COMMENT ON TABLE bmt_db.customer_marketing IS
'Histori assignment customer kepada marketing.';


-- ============================================================
-- 5. PRODUCTS
-- ============================================================

CREATE TABLE bmt_db.products (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    code                    VARCHAR(20) NOT NULL,
    name                    VARCHAR(150) NOT NULL,

    category                bmt_db.product_category NOT NULL,

    description             TEXT NULL,

    currency                bmt_db.currency_code
                            NOT NULL DEFAULT 'IDR',

    is_active               BOOLEAN NOT NULL DEFAULT TRUE,

    effective_from          DATE NOT NULL DEFAULT CURRENT_DATE,
    effective_until         DATE NULL,

    created_by              UUID NULL,

    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uq_products_code
        UNIQUE (code),

    CONSTRAINT fk_products_created_by
        FOREIGN KEY (created_by)
        REFERENCES bmt_db.user_profiles(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT ck_products_code
        CHECK (
            code ~ '^[A-Z0-9][A-Z0-9_-]*$'
        ),

    CONSTRAINT ck_products_name
        CHECK (
            btrim(name) <> ''
        ),

    CONSTRAINT ck_products_effective_period
        CHECK (
            effective_until IS NULL
            OR effective_until >= effective_from
        )
);

COMMENT ON TABLE bmt_db.products IS
'Parent master seluruh produk Tabungan, Deposito, dan Kredit/Pembiayaan.';


-- ============================================================
-- 6. SAVINGS PRODUCTS
-- ============================================================

CREATE TABLE bmt_db.savings_products (
    product_id                  UUID PRIMARY KEY,

    account_code                VARCHAR(10) NOT NULL,

    minimum_opening_balance     bmt_db.money_amount
                                NOT NULL DEFAULT 0,

    minimum_balance             bmt_db.money_amount
                                NOT NULL DEFAULT 0,

    minimum_deposit             bmt_db.money_amount
                                NOT NULL DEFAULT 0,

    maximum_deposit             bmt_db.money_amount NULL,

    minimum_withdrawal          bmt_db.money_amount
                                NOT NULL DEFAULT 0,

    maximum_withdrawal          bmt_db.money_amount NULL,

    admin_fee                   bmt_db.money_amount
                                NOT NULL DEFAULT 0,

    profit_sharing_rate         bmt_db.percentage_rate
                                NOT NULL DEFAULT 0,

    dormant_after_days          INTEGER NULL,

    dormant_fee                 bmt_db.money_amount
                                NOT NULL DEFAULT 0,

    allow_negative_balance      BOOLEAN NOT NULL DEFAULT FALSE,

    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_savings_products_product
        FOREIGN KEY (product_id)
        REFERENCES bmt_db.products(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT uq_savings_products_account_code
        UNIQUE (account_code),

    CONSTRAINT ck_savings_products_account_code
        CHECK (
            account_code ~ '^[0-9]{2,10}$'
        ),

    CONSTRAINT ck_savings_products_deposit_range
        CHECK (
            maximum_deposit IS NULL
            OR maximum_deposit >= minimum_deposit
        ),

    CONSTRAINT ck_savings_products_withdrawal_range
        CHECK (
            maximum_withdrawal IS NULL
            OR maximum_withdrawal >= minimum_withdrawal
        ),

    CONSTRAINT ck_savings_products_min_balance
        CHECK (
            minimum_opening_balance >= minimum_balance
        ),

    CONSTRAINT ck_savings_products_dormant
        CHECK (
            dormant_after_days IS NULL
            OR dormant_after_days > 0
        )
);

COMMENT ON TABLE bmt_db.savings_products IS
'Konfigurasi khusus produk tabungan.';


-- ============================================================
-- 7. DEPOSIT PRODUCTS
-- ============================================================

CREATE TABLE bmt_db.deposit_products (
    product_id                  UUID PRIMARY KEY,

    account_code                VARCHAR(10) NOT NULL,

    minimum_amount              bmt_db.money_amount
                                NOT NULL DEFAULT 0,

    tenor_months                INTEGER NOT NULL,

    profit_rate                 bmt_db.percentage_rate
                                NOT NULL DEFAULT 0,

    profit_method               VARCHAR(30)
                                NOT NULL DEFAULT 'MATURITY',

    early_withdrawal_allowed    BOOLEAN NOT NULL DEFAULT FALSE,

    early_withdrawal_penalty    bmt_db.money_amount
                                NOT NULL DEFAULT 0,

    allow_aro                   BOOLEAN NOT NULL DEFAULT FALSE,

    default_aro_type            bmt_db.deposit_aro_type
                                NOT NULL DEFAULT 'NONE',

    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_deposit_products_product
        FOREIGN KEY (product_id)
        REFERENCES bmt_db.products(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT uq_deposit_products_account_code
        UNIQUE (account_code),

    CONSTRAINT ck_deposit_products_account_code
        CHECK (
            account_code ~ '^[0-9]{2,10}$'
        ),

    CONSTRAINT ck_deposit_products_tenor
        CHECK (
            tenor_months > 0
        ),

    CONSTRAINT ck_deposit_products_profit_method
        CHECK (
            profit_method IN (
                'MONTHLY',
                'MATURITY'
            )
        ),

    CONSTRAINT ck_deposit_products_aro
        CHECK (
            allow_aro = TRUE
            OR default_aro_type = 'NONE'
        )
);

COMMENT ON TABLE bmt_db.deposit_products IS
'Konfigurasi produk deposito/simpanan berjangka.';


-- ============================================================
-- 8. LOAN PRODUCTS
-- ============================================================

CREATE TABLE bmt_db.loan_products (
    product_id                  UUID PRIMARY KEY,

    loan_code                   VARCHAR(10) NOT NULL,

    contract_type               bmt_db.contract_type
                                NOT NULL DEFAULT 'CONVENTIONAL',

    minimum_principal           bmt_db.money_amount
                                NOT NULL DEFAULT 0,

    maximum_principal           bmt_db.money_amount NULL,

    minimum_tenor_months        INTEGER NOT NULL DEFAULT 1,

    maximum_tenor_months        INTEGER NOT NULL,

    rate_type                   VARCHAR(30)
                                NOT NULL DEFAULT 'FLAT',

    rate                        bmt_db.percentage_rate
                                NOT NULL DEFAULT 0,

    installment_method          VARCHAR(30)
                                NOT NULL DEFAULT 'MONTHLY',

    admin_fee                   bmt_db.money_amount
                                NOT NULL DEFAULT 0,

    provision_rate              bmt_db.percentage_rate
                                NOT NULL DEFAULT 0,

    penalty_rate                bmt_db.percentage_rate
                                NOT NULL DEFAULT 0,

    grace_period_days           INTEGER NOT NULL DEFAULT 0,

    require_collateral          BOOLEAN NOT NULL DEFAULT FALSE,

    require_manager_approval    BOOLEAN NOT NULL DEFAULT TRUE,

    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_loan_products_product
        FOREIGN KEY (product_id)
        REFERENCES bmt_db.products(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT uq_loan_products_loan_code
        UNIQUE (loan_code),

    CONSTRAINT ck_loan_products_loan_code
        CHECK (
            loan_code ~ '^[0-9]{3,10}$'
        ),

    CONSTRAINT ck_loan_products_principal_range
        CHECK (
            maximum_principal IS NULL
            OR maximum_principal >= minimum_principal
        ),

    CONSTRAINT ck_loan_products_tenor
        CHECK (
            minimum_tenor_months > 0
            AND maximum_tenor_months >= minimum_tenor_months
        ),

    CONSTRAINT ck_loan_products_rate_type
        CHECK (
            rate_type IN (
                'FLAT',
                'EFFECTIVE',
                'ANNUITY',
                'FIXED_MARGIN',
                'PROFIT_SHARING'
            )
        ),

    CONSTRAINT ck_loan_products_installment_method
        CHECK (
            installment_method IN (
                'DAILY',
                'WEEKLY',
                'MONTHLY',
                'MATURITY'
            )
        ),

    CONSTRAINT ck_loan_products_grace_period
        CHECK (
            grace_period_days >= 0
        )
);

COMMENT ON TABLE bmt_db.loan_products IS
'Konfigurasi produk kredit/pembiayaan.';


-- ============================================================
-- 9. INDEXES - CUSTOMERS
-- ============================================================

CREATE INDEX idx_customers_branch
    ON bmt_db.customers(branch_id);

CREATE INDEX idx_customers_status
    ON bmt_db.customers(status);

CREATE INDEX idx_customers_full_name
    ON bmt_db.customers(full_name);

CREATE INDEX idx_customers_phone
    ON bmt_db.customers(phone);

CREATE INDEX idx_customer_addresses_customer
    ON bmt_db.customer_addresses(customer_id);

CREATE INDEX idx_customer_documents_customer
    ON bmt_db.customer_documents(customer_id);

CREATE INDEX idx_customer_marketing_customer
    ON bmt_db.customer_marketing(customer_id);

CREATE INDEX idx_customer_marketing_user
    ON bmt_db.customer_marketing(marketing_user_id);

CREATE INDEX idx_customer_marketing_active
    ON bmt_db.customer_marketing(marketing_user_id, is_active);


-- ============================================================
-- 10. ONE ACTIVE MARKETING PER CUSTOMER
-- ============================================================

CREATE UNIQUE INDEX uq_customer_marketing_one_active
    ON bmt_db.customer_marketing(customer_id)
    WHERE is_active = TRUE;


-- ============================================================
-- 11. PRIMARY CUSTOMER ADDRESS
-- ============================================================
-- Only one primary address for each address type.

CREATE UNIQUE INDEX uq_customer_address_primary_type
    ON bmt_db.customer_addresses(customer_id, address_type)
    WHERE is_primary = TRUE;


-- ============================================================
-- 12. PRODUCT INDEXES
-- ============================================================

CREATE INDEX idx_products_category
    ON bmt_db.products(category);

CREATE INDEX idx_products_active
    ON bmt_db.products(category, is_active);

CREATE INDEX idx_products_effective
    ON bmt_db.products(effective_from, effective_until);


-- ============================================================
-- 13. CATEGORY VALIDATION FUNCTIONS
-- ============================================================
-- Extension tables must match the category of parent products.

CREATE OR REPLACE FUNCTION bmt_db.validate_product_category()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
    v_category bmt_db.product_category;
BEGIN
    SELECT p.category
      INTO v_category
      FROM bmt_db.products p
     WHERE p.id = NEW.product_id;

    IF v_category IS NULL THEN
        RAISE EXCEPTION
            'Product % does not exist',
            NEW.product_id;
    END IF;

    IF TG_TABLE_NAME = 'savings_products'
       AND v_category <> 'SAVINGS' THEN

        RAISE EXCEPTION
            'Product % category must be SAVINGS',
            NEW.product_id;

    ELSIF TG_TABLE_NAME = 'deposit_products'
       AND v_category <> 'DEPOSIT' THEN

        RAISE EXCEPTION
            'Product % category must be DEPOSIT',
            NEW.product_id;

    ELSIF TG_TABLE_NAME = 'loan_products'
       AND v_category <> 'LOAN' THEN

        RAISE EXCEPTION
            'Product % category must be LOAN',
            NEW.product_id;

    END IF;

    RETURN NEW;
END;
$$;


CREATE TRIGGER trg_savings_product_category
BEFORE INSERT OR UPDATE
ON bmt_db.savings_products
FOR EACH ROW
EXECUTE FUNCTION bmt_db.validate_product_category();

CREATE TRIGGER trg_deposit_product_category
BEFORE INSERT OR UPDATE
ON bmt_db.deposit_products
FOR EACH ROW
EXECUTE FUNCTION bmt_db.validate_product_category();

CREATE TRIGGER trg_loan_product_category
BEFORE INSERT OR UPDATE
ON bmt_db.loan_products
FOR EACH ROW
EXECUTE FUNCTION bmt_db.validate_product_category();


-- ============================================================
-- 14. UPDATED_AT TRIGGERS
-- ============================================================

CREATE TRIGGER trg_customers_updated_at
BEFORE UPDATE ON bmt_db.customers
FOR EACH ROW
EXECUTE FUNCTION bmt_db.set_updated_at();

CREATE TRIGGER trg_customer_addresses_updated_at
BEFORE UPDATE ON bmt_db.customer_addresses
FOR EACH ROW
EXECUTE FUNCTION bmt_db.set_updated_at();

CREATE TRIGGER trg_customer_documents_updated_at
BEFORE UPDATE ON bmt_db.customer_documents
FOR EACH ROW
EXECUTE FUNCTION bmt_db.set_updated_at();

CREATE TRIGGER trg_products_updated_at
BEFORE UPDATE ON bmt_db.products
FOR EACH ROW
EXECUTE FUNCTION bmt_db.set_updated_at();

CREATE TRIGGER trg_savings_products_updated_at
BEFORE UPDATE ON bmt_db.savings_products
FOR EACH ROW
EXECUTE FUNCTION bmt_db.set_updated_at();

CREATE TRIGGER trg_deposit_products_updated_at
BEFORE UPDATE ON bmt_db.deposit_products
FOR EACH ROW
EXECUTE FUNCTION bmt_db.set_updated_at();

CREATE TRIGGER trg_loan_products_updated_at
BEFORE UPDATE ON bmt_db.loan_products
FOR EACH ROW
EXECUTE FUNCTION bmt_db.set_updated_at();


-- ============================================================
-- 15. BASE SECURITY
-- ============================================================

REVOKE ALL ON ALL TABLES IN SCHEMA bmt_db FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA bmt_db FROM PUBLIC;


COMMIT;
