-- ============================================================
-- BMT CORE BANKING SYSTEM
-- Migration : 004_bmt_accounts_credit.sql
-- Purpose   : Financial accounts, savings, deposits,
--             loan application, analysis, collateral,
--             loan accounts, schedules and payments
-- Version   : 1.0.0
-- Requires  : 001 - 003
-- ============================================================

BEGIN;


-- ============================================================
-- 1. FINANCIAL ACCOUNTS
-- ============================================================

CREATE TABLE bmt_db.financial_accounts (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    account_number      VARCHAR(50) NOT NULL,

    account_type        bmt_db.financial_account_type NOT NULL,

    customer_id         UUID NOT NULL,
    branch_id           UUID NOT NULL,
    product_id          UUID NOT NULL,

    status              bmt_db.account_status
                        NOT NULL DEFAULT 'PENDING',

    opened_at           TIMESTAMPTZ NULL,
    closed_at           TIMESTAMPTZ NULL,

    opened_by           UUID NULL,
    closed_by           UUID NULL,

    sequence_no         BIGINT NOT NULL,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uq_financial_accounts_number
        UNIQUE (account_number),

    CONSTRAINT fk_financial_accounts_customer
        FOREIGN KEY (customer_id)
        REFERENCES bmt_db.customers(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_financial_accounts_branch
        FOREIGN KEY (branch_id)
        REFERENCES bmt_db.branches(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_financial_accounts_product
        FOREIGN KEY (product_id)
        REFERENCES bmt_db.products(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_financial_accounts_opened_by
        FOREIGN KEY (opened_by)
        REFERENCES bmt_db.user_profiles(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_financial_accounts_closed_by
        FOREIGN KEY (closed_by)
        REFERENCES bmt_db.user_profiles(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT ck_financial_accounts_number
        CHECK (
            account_number ~ '^[0-9]+(\.[0-9]+)+$'
        ),

    CONSTRAINT ck_financial_accounts_sequence
        CHECK (sequence_no > 0),

    CONSTRAINT ck_financial_accounts_dates
        CHECK (
            closed_at IS NULL
            OR opened_at IS NULL
            OR closed_at >= opened_at
        ),

    CONSTRAINT ck_financial_accounts_closed
        CHECK (
            status <> 'CLOSED'
            OR closed_at IS NOT NULL
        )
);

COMMENT ON TABLE bmt_db.financial_accounts IS
'Parent universal seluruh rekening tabungan, deposito dan kredit.';

COMMENT ON COLUMN bmt_db.financial_accounts.account_number IS
'Business account number. UUID id remains the internal database identifier.';


-- ============================================================
-- 2. SAVINGS ACCOUNTS
-- ============================================================

CREATE TABLE bmt_db.savings_accounts (
    financial_account_id    UUID PRIMARY KEY,

    current_balance         bmt_db.signed_money_amount
                            NOT NULL DEFAULT 0,

    available_balance       bmt_db.signed_money_amount
                            NOT NULL DEFAULT 0,

    blocked_balance         bmt_db.money_amount
                            NOT NULL DEFAULT 0,

    last_transaction_at     TIMESTAMPTZ NULL,

    dormant_at              TIMESTAMPTZ NULL,

    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_savings_accounts_financial
        FOREIGN KEY (financial_account_id)
        REFERENCES bmt_db.financial_accounts(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT ck_savings_accounts_blocked_balance
        CHECK (
            blocked_balance <= current_balance
            OR current_balance < 0
        )
);

COMMENT ON TABLE bmt_db.savings_accounts IS
'Extension rekening tabungan. Balance columns are cached operational balances; ledger remains source of truth.';


-- ============================================================
-- 3. DEPOSIT ACCOUNTS
-- ============================================================

CREATE TABLE bmt_db.deposit_accounts (
    financial_account_id            UUID PRIMARY KEY,

    settlement_savings_account_id   UUID NOT NULL,

    principal_amount                bmt_db.money_amount NOT NULL,

    start_date                      DATE NOT NULL,
    maturity_date                   DATE NOT NULL,

    profit_rate                     bmt_db.percentage_rate
                                    NOT NULL DEFAULT 0,

    aro_type                        bmt_db.deposit_aro_type
                                    NOT NULL DEFAULT 'NONE',

    deposit_status                  bmt_db.deposit_status
                                    NOT NULL DEFAULT 'PENDING',

    terminated_at                   TIMESTAMPTZ NULL,
    termination_reason              TEXT NULL,

    created_at                      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                      TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_deposit_accounts_financial
        FOREIGN KEY (financial_account_id)
        REFERENCES bmt_db.financial_accounts(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_deposit_accounts_settlement
        FOREIGN KEY (settlement_savings_account_id)
        REFERENCES bmt_db.savings_accounts(financial_account_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT ck_deposit_accounts_principal
        CHECK (principal_amount > 0),

    CONSTRAINT ck_deposit_accounts_dates
        CHECK (maturity_date > start_date),

    CONSTRAINT ck_deposit_accounts_termination
        CHECK (
            deposit_status <> 'EARLY_TERMINATED'
            OR terminated_at IS NOT NULL
        )
);

COMMENT ON TABLE bmt_db.deposit_accounts IS
'Extension deposito/simpanan berjangka. Wajib mempunyai rekening tabungan settlement.';


-- ============================================================
-- 4. LOAN APPLICATIONS
-- ============================================================

CREATE TABLE bmt_db.loan_applications (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    application_number      VARCHAR(50) NOT NULL,

    customer_id             UUID NOT NULL,
    savings_account_id      UUID NOT NULL,
    loan_product_id         UUID NOT NULL,
    branch_id               UUID NOT NULL,

    requested_amount        bmt_db.money_amount NOT NULL,
    requested_tenor_months  INTEGER NOT NULL,

    purpose                 TEXT NOT NULL,

    status                  bmt_db.loan_application_status
                            NOT NULL DEFAULT 'DRAFT',

    marketing_user_id       UUID NULL,

    submitted_at            TIMESTAMPTZ NULL,
    decided_at              TIMESTAMPTZ NULL,

    created_by              UUID NULL,

    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uq_loan_applications_number
        UNIQUE (application_number),

    CONSTRAINT fk_loan_applications_customer
        FOREIGN KEY (customer_id)
        REFERENCES bmt_db.customers(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_loan_applications_savings
        FOREIGN KEY (savings_account_id)
        REFERENCES bmt_db.savings_accounts(financial_account_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_loan_applications_product
        FOREIGN KEY (loan_product_id)
        REFERENCES bmt_db.loan_products(product_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_loan_applications_branch
        FOREIGN KEY (branch_id)
        REFERENCES bmt_db.branches(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_loan_applications_marketing
        FOREIGN KEY (marketing_user_id)
        REFERENCES bmt_db.user_profiles(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_loan_applications_created_by
        FOREIGN KEY (created_by)
        REFERENCES bmt_db.user_profiles(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT ck_loan_applications_amount
        CHECK (requested_amount > 0),

    CONSTRAINT ck_loan_applications_tenor
        CHECK (requested_tenor_months > 0),

    CONSTRAINT ck_loan_applications_purpose
        CHECK (btrim(purpose) <> ''),

    CONSTRAINT ck_loan_applications_submission
        CHECK (
            status = 'DRAFT'
            OR submitted_at IS NOT NULL
        ),

    CONSTRAINT ck_loan_applications_decision
        CHECK (
            status NOT IN ('APPROVED', 'REJECTED')
            OR decided_at IS NOT NULL
        )
);

COMMENT ON TABLE bmt_db.loan_applications IS
'Form/pengajuan kredit sebelum menjadi rekening kredit aktif.';


-- ============================================================
-- 5. CREDIT ANALYSES
-- ============================================================

CREATE TABLE bmt_db.credit_analyses (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    loan_application_id     UUID NOT NULL,

    monthly_income          bmt_db.money_amount NOT NULL DEFAULT 0,
    other_income            bmt_db.money_amount NOT NULL DEFAULT 0,

    living_expenses         bmt_db.money_amount NOT NULL DEFAULT 0,
    business_expenses       bmt_db.money_amount NOT NULL DEFAULT 0,

    existing_installments   bmt_db.money_amount NOT NULL DEFAULT 0,
    other_liabilities       bmt_db.money_amount NOT NULL DEFAULT 0,

    net_income              bmt_db.signed_money_amount
                            NOT NULL DEFAULT 0,

    disposable_income       bmt_db.signed_money_amount
                            NOT NULL DEFAULT 0,

    proposed_installment    bmt_db.money_amount NOT NULL DEFAULT 0,

    debt_service_ratio      bmt_db.percentage_rate
                            NOT NULL DEFAULT 0,

    analyst_notes           TEXT NULL,
    recommendation          TEXT NULL,

    analyzed_by             UUID NOT NULL,
    analyzed_at             TIMESTAMPTZ NOT NULL DEFAULT now(),

    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uq_credit_analyses_application
        UNIQUE (loan_application_id),

    CONSTRAINT fk_credit_analyses_application
        FOREIGN KEY (loan_application_id)
        REFERENCES bmt_db.loan_applications(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_credit_analyses_analyzed_by
        FOREIGN KEY (analyzed_by)
        REFERENCES bmt_db.user_profiles(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT
);

COMMENT ON TABLE bmt_db.credit_analyses IS
'Snapshot analisis kemampuan bayar pada saat pengajuan kredit.';


-- ============================================================
-- 6. LOAN COLLATERALS
-- ============================================================

CREATE TABLE bmt_db.loan_collaterals (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    loan_application_id     UUID NOT NULL,

    collateral_type         VARCHAR(50) NOT NULL,
    description             TEXT NOT NULL,

    ownership_name          VARCHAR(150) NULL,
    document_number         VARCHAR(100) NULL,

    estimated_value         bmt_db.money_amount NULL,
    appraised_value         bmt_db.money_amount NULL,

    storage_bucket          VARCHAR(100) NULL,
    storage_path            TEXT NULL,

    status                  bmt_db.record_status
                            NOT NULL DEFAULT 'ACTIVE',

    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_loan_collaterals_application
        FOREIGN KEY (loan_application_id)
        REFERENCES bmt_db.loan_applications(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT ck_loan_collaterals_type
        CHECK (
            collateral_type ~ '^[A-Z][A-Z0-9_]*$'
        ),

    CONSTRAINT ck_loan_collaterals_description
        CHECK (btrim(description) <> ''),

    CONSTRAINT ck_loan_collaterals_values
        CHECK (
            appraised_value IS NULL
            OR estimated_value IS NULL
            OR appraised_value >= 0
        ),

    CONSTRAINT ck_loan_collaterals_storage
        CHECK (
            (storage_bucket IS NULL AND storage_path IS NULL)
            OR
            (storage_bucket IS NOT NULL AND storage_path IS NOT NULL)
        )
);

COMMENT ON TABLE bmt_db.loan_collaterals IS
'Jaminan/agunan yang terkait dengan pengajuan kredit.';


-- ============================================================
-- 7. LOAN ACCOUNTS
-- ============================================================

CREATE TABLE bmt_db.loan_accounts (
    financial_account_id        UUID PRIMARY KEY,

    application_id              UUID NOT NULL,

    savings_account_id          UUID NOT NULL,

    principal_amount            bmt_db.money_amount NOT NULL,

    tenor_months                INTEGER NOT NULL,

    rate                        bmt_db.percentage_rate
                                NOT NULL DEFAULT 0,

    margin_amount               bmt_db.money_amount
                                NOT NULL DEFAULT 0,

    disbursement_amount         bmt_db.money_amount
                                NOT NULL DEFAULT 0,

    outstanding_principal       bmt_db.money_amount
                                NOT NULL DEFAULT 0,

    outstanding_margin          bmt_db.money_amount
                                NOT NULL DEFAULT 0,

    outstanding_penalty         bmt_db.money_amount
                                NOT NULL DEFAULT 0,

    disbursement_date           DATE NULL,
    maturity_date               DATE NULL,

    loan_status                 bmt_db.loan_account_status
                                NOT NULL DEFAULT 'READY_FOR_DISBURSEMENT',

    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_loan_accounts_financial
        FOREIGN KEY (financial_account_id)
        REFERENCES bmt_db.financial_accounts(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT uq_loan_accounts_application
        UNIQUE (application_id),

    CONSTRAINT fk_loan_accounts_application
        FOREIGN KEY (application_id)
        REFERENCES bmt_db.loan_applications(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_loan_accounts_savings
        FOREIGN KEY (savings_account_id)
        REFERENCES bmt_db.savings_accounts(financial_account_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT ck_loan_accounts_principal
        CHECK (principal_amount > 0),

    CONSTRAINT ck_loan_accounts_tenor
        CHECK (tenor_months > 0),

    CONSTRAINT ck_loan_accounts_disbursement
        CHECK (
            disbursement_amount <= principal_amount
        ),

    CONSTRAINT ck_loan_accounts_dates
        CHECK (
            maturity_date IS NULL
            OR disbursement_date IS NULL
            OR maturity_date >= disbursement_date
        ),

    CONSTRAINT ck_loan_accounts_active_disbursement
        CHECK (
            loan_status = 'READY_FOR_DISBURSEMENT'
            OR disbursement_date IS NOT NULL
        )
);

COMMENT ON TABLE bmt_db.loan_accounts IS
'Rekening kredit/pembiayaan yang dibuat setelah loan application disetujui.';


-- ============================================================
-- 8. LOAN SCHEDULES
-- ============================================================

CREATE TABLE bmt_db.loan_schedules (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    loan_account_id         UUID NOT NULL,

    installment_no          INTEGER NOT NULL,

    due_date                DATE NOT NULL,

    opening_principal       bmt_db.money_amount NOT NULL,

    principal_due           bmt_db.money_amount NOT NULL DEFAULT 0,
    margin_due              bmt_db.money_amount NOT NULL DEFAULT 0,
    other_due               bmt_db.money_amount NOT NULL DEFAULT 0,

    total_due               bmt_db.money_amount NOT NULL,

    principal_paid          bmt_db.money_amount NOT NULL DEFAULT 0,
    margin_paid             bmt_db.money_amount NOT NULL DEFAULT 0,
    penalty_paid            bmt_db.money_amount NOT NULL DEFAULT 0,
    other_paid              bmt_db.money_amount NOT NULL DEFAULT 0,

    paid_at                 TIMESTAMPTZ NULL,

    status                  bmt_db.installment_status
                            NOT NULL DEFAULT 'UPCOMING',

    days_overdue            INTEGER NOT NULL DEFAULT 0,

    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_loan_schedules_account
        FOREIGN KEY (loan_account_id)
        REFERENCES bmt_db.loan_accounts(financial_account_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT uq_loan_schedules_installment
        UNIQUE (loan_account_id, installment_no),

    CONSTRAINT ck_loan_schedules_installment_no
        CHECK (installment_no > 0),

    CONSTRAINT ck_loan_schedules_total
        CHECK (
            total_due =
                principal_due
                + margin_due
                + other_due
        ),

    CONSTRAINT ck_loan_schedules_days_overdue
        CHECK (days_overdue >= 0),

    CONSTRAINT ck_loan_schedules_paid
        CHECK (
            principal_paid <= principal_due
        )
);

COMMENT ON TABLE bmt_db.loan_schedules IS
'Jadwal angsuran contractual kredit. Tidak dihapus ketika terjadi pembayaran parsial.';


-- ============================================================
-- 9. INSTALLMENT PAYMENTS
-- ============================================================
-- transaction_id will be added in Migration 005 after
-- universal transactions table exists.

CREATE TABLE bmt_db.installment_payments (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    loan_schedule_id        UUID NOT NULL,

    principal_amount        bmt_db.money_amount NOT NULL DEFAULT 0,
    margin_amount           bmt_db.money_amount NOT NULL DEFAULT 0,
    penalty_amount          bmt_db.money_amount NOT NULL DEFAULT 0,
    other_amount            bmt_db.money_amount NOT NULL DEFAULT 0,

    paid_at                 TIMESTAMPTZ NOT NULL DEFAULT now(),

    created_by              UUID NULL,

    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_installment_payments_schedule
        FOREIGN KEY (loan_schedule_id)
        REFERENCES bmt_db.loan_schedules(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_installment_payments_created_by
        FOREIGN KEY (created_by)
        REFERENCES bmt_db.user_profiles(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT ck_installment_payments_amount
        CHECK (
            principal_amount
            + margin_amount
            + penalty_amount
            + other_amount > 0
        )
);

COMMENT ON TABLE bmt_db.installment_payments IS
'Detail alokasi pembayaran ke schedule. transaction_id ditambahkan setelah transaction engine table tersedia.';


-- ============================================================
-- 10. FINANCIAL ACCOUNT PRODUCT VALIDATION
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.validate_financial_account()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
    v_category      bmt_db.product_category;
    v_customer_status bmt_db.customer_status;
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

    IF v_category::text <> NEW.account_type::text THEN
        RAISE EXCEPTION
            'Account type % does not match product category %',
            NEW.account_type,
            v_category;
    END IF;

    SELECT c.status
      INTO v_customer_status
      FROM bmt_db.customers c
     WHERE c.id = NEW.customer_id;

    IF v_customer_status IS NULL THEN
        RAISE EXCEPTION
            'Customer % does not exist',
            NEW.customer_id;
    END IF;

    -- A new financial account may only be opened for ACTIVE customers.
    IF TG_OP = 'INSERT'
       AND v_customer_status <> 'ACTIVE' THEN

        RAISE EXCEPTION
            'Customer % must be ACTIVE to open financial account',
            NEW.customer_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_financial_account_validation
BEFORE INSERT OR UPDATE OF customer_id, product_id, account_type
ON bmt_db.financial_accounts
FOR EACH ROW
EXECUTE FUNCTION bmt_db.validate_financial_account();


-- ============================================================
-- 11. SAVINGS ACCOUNT TYPE VALIDATION
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.validate_savings_account()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
    v_type bmt_db.financial_account_type;
BEGIN
    SELECT fa.account_type
      INTO v_type
      FROM bmt_db.financial_accounts fa
     WHERE fa.id = NEW.financial_account_id;

    IF v_type <> 'SAVINGS' THEN
        RAISE EXCEPTION
            'Financial account % must have type SAVINGS',
            NEW.financial_account_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_savings_account_validation
BEFORE INSERT OR UPDATE OF financial_account_id
ON bmt_db.savings_accounts
FOR EACH ROW
EXECUTE FUNCTION bmt_db.validate_savings_account();


-- ============================================================
-- 12. DEPOSIT VALIDATION
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.validate_deposit_account()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
    v_deposit_customer      UUID;
    v_deposit_type          bmt_db.financial_account_type;

    v_savings_customer      UUID;
    v_savings_status        bmt_db.account_status;
BEGIN
    SELECT
        fa.customer_id,
        fa.account_type
      INTO
        v_deposit_customer,
        v_deposit_type
      FROM bmt_db.financial_accounts fa
     WHERE fa.id = NEW.financial_account_id;

    IF v_deposit_type <> 'DEPOSIT' THEN
        RAISE EXCEPTION
            'Financial account % must have type DEPOSIT',
            NEW.financial_account_id;
    END IF;

    SELECT
        fa.customer_id,
        fa.status
      INTO
        v_savings_customer,
        v_savings_status
      FROM bmt_db.financial_accounts fa
     WHERE fa.id = NEW.settlement_savings_account_id;

    IF v_savings_customer IS NULL THEN
        RAISE EXCEPTION
            'Settlement savings account % does not exist',
            NEW.settlement_savings_account_id;
    END IF;

    IF v_savings_customer <> v_deposit_customer THEN
        RAISE EXCEPTION
            'Deposit and settlement savings must belong to the same customer';
    END IF;

    IF v_savings_status <> 'ACTIVE' THEN
        RAISE EXCEPTION
            'Settlement savings account must be ACTIVE';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_deposit_account_validation
BEFORE INSERT OR UPDATE OF
    financial_account_id,
    settlement_savings_account_id
ON bmt_db.deposit_accounts
FOR EACH ROW
EXECUTE FUNCTION bmt_db.validate_deposit_account();


-- ============================================================
-- 13. LOAN APPLICATION VALIDATION
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.validate_loan_application()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
    v_savings_customer      UUID;
    v_savings_branch        UUID;
    v_savings_status        bmt_db.account_status;

    v_min_amount            NUMERIC(19,2);
    v_max_amount            NUMERIC(19,2);

    v_min_tenor             INTEGER;
    v_max_tenor             INTEGER;
BEGIN
    SELECT
        fa.customer_id,
        fa.branch_id,
        fa.status
      INTO
        v_savings_customer,
        v_savings_branch,
        v_savings_status
      FROM bmt_db.financial_accounts fa
     WHERE fa.id = NEW.savings_account_id
       AND fa.account_type = 'SAVINGS';

    IF v_savings_customer IS NULL THEN
        RAISE EXCEPTION
            'Savings account % does not exist',
            NEW.savings_account_id;
    END IF;

    IF v_savings_customer <> NEW.customer_id THEN
        RAISE EXCEPTION
            'Loan application customer must own the savings account';
    END IF;

    IF v_savings_status <> 'ACTIVE' THEN
        RAISE EXCEPTION
            'Savings account must be ACTIVE for loan application';
    END IF;

    IF v_savings_branch <> NEW.branch_id THEN
        RAISE EXCEPTION
            'Loan application branch must match savings account branch';
    END IF;

    SELECT
        lp.minimum_principal,
        lp.maximum_principal,
        lp.minimum_tenor_months,
        lp.maximum_tenor_months
      INTO
        v_min_amount,
        v_max_amount,
        v_min_tenor,
        v_max_tenor
      FROM bmt_db.loan_products lp
     WHERE lp.product_id = NEW.loan_product_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Loan product % does not exist',
            NEW.loan_product_id;
    END IF;

    IF NEW.requested_amount < v_min_amount THEN
        RAISE EXCEPTION
            'Requested amount is below product minimum';
    END IF;

    IF v_max_amount IS NOT NULL
       AND NEW.requested_amount > v_max_amount THEN
        RAISE EXCEPTION
            'Requested amount exceeds product maximum';
    END IF;

    IF NEW.requested_tenor_months < v_min_tenor
       OR NEW.requested_tenor_months > v_max_tenor THEN
        RAISE EXCEPTION
            'Requested tenor is outside product limits';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_loan_application_validation
BEFORE INSERT OR UPDATE OF
    customer_id,
    savings_account_id,
    loan_product_id,
    branch_id,
    requested_amount,
    requested_tenor_months
ON bmt_db.loan_applications
FOR EACH ROW
EXECUTE FUNCTION bmt_db.validate_loan_application();


-- ============================================================
-- 14. LOAN ACCOUNT VALIDATION
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.validate_loan_account()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
    v_loan_customer         UUID;
    v_loan_type             bmt_db.financial_account_type;
    v_loan_product          UUID;

    v_app_customer          UUID;
    v_app_savings           UUID;
    v_app_product           UUID;
    v_app_status            bmt_db.loan_application_status;

    v_savings_customer      UUID;
    v_savings_status        bmt_db.account_status;
BEGIN
    SELECT
        fa.customer_id,
        fa.account_type,
        fa.product_id
      INTO
        v_loan_customer,
        v_loan_type,
        v_loan_product
      FROM bmt_db.financial_accounts fa
     WHERE fa.id = NEW.financial_account_id;

    IF v_loan_type <> 'LOAN' THEN
        RAISE EXCEPTION
            'Financial account % must have type LOAN',
            NEW.financial_account_id;
    END IF;

    SELECT
        la.customer_id,
        la.savings_account_id,
        la.loan_product_id,
        la.status
      INTO
        v_app_customer,
        v_app_savings,
        v_app_product,
        v_app_status
      FROM bmt_db.loan_applications la
     WHERE la.id = NEW.application_id;

    IF v_app_customer IS NULL THEN
        RAISE EXCEPTION
            'Loan application % does not exist',
            NEW.application_id;
    END IF;

    IF v_app_status <> 'APPROVED' THEN
        RAISE EXCEPTION
            'Loan application must be APPROVED before loan account creation';
    END IF;

    IF v_loan_customer <> v_app_customer THEN
        RAISE EXCEPTION
            'Loan account customer does not match loan application';
    END IF;

    IF v_loan_product <> v_app_product THEN
        RAISE EXCEPTION
            'Loan account product does not match loan application';
    END IF;

    IF NEW.savings_account_id <> v_app_savings THEN
        RAISE EXCEPTION
            'Loan settlement savings does not match loan application';
    END IF;

    SELECT
        fa.customer_id,
        fa.status
      INTO
        v_savings_customer,
        v_savings_status
      FROM bmt_db.financial_accounts fa
     WHERE fa.id = NEW.savings_account_id;

    IF v_savings_customer <> v_loan_customer THEN
        RAISE EXCEPTION
            'Loan and savings account must belong to same customer';
    END IF;

    IF v_savings_status <> 'ACTIVE' THEN
        RAISE EXCEPTION
            'Loan settlement savings account must be ACTIVE';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_loan_account_validation
BEFORE INSERT OR UPDATE OF
    financial_account_id,
    application_id,
    savings_account_id
ON bmt_db.loan_accounts
FOR EACH ROW
EXECUTE FUNCTION bmt_db.validate_loan_account();


-- ============================================================
-- 15. INDEXES
-- ============================================================

CREATE INDEX idx_financial_accounts_customer
    ON bmt_db.financial_accounts(customer_id);

CREATE INDEX idx_financial_accounts_branch
    ON bmt_db.financial_accounts(branch_id);

CREATE INDEX idx_financial_accounts_product
    ON bmt_db.financial_accounts(product_id);

CREATE INDEX idx_financial_accounts_type_status
    ON bmt_db.financial_accounts(account_type, status);

CREATE INDEX idx_financial_accounts_customer_type
    ON bmt_db.financial_accounts(customer_id, account_type);

CREATE UNIQUE INDEX uq_financial_accounts_sequence
    ON bmt_db.financial_accounts(
        branch_id,
        account_type,
        product_id,
        sequence_no
    );


CREATE INDEX idx_deposit_accounts_settlement
    ON bmt_db.deposit_accounts(settlement_savings_account_id);

CREATE INDEX idx_deposit_accounts_maturity
    ON bmt_db.deposit_accounts(maturity_date, deposit_status);


CREATE INDEX idx_loan_applications_customer
    ON bmt_db.loan_applications(customer_id);

CREATE INDEX idx_loan_applications_savings
    ON bmt_db.loan_applications(savings_account_id);

CREATE INDEX idx_loan_applications_product
    ON bmt_db.loan_applications(loan_product_id);

CREATE INDEX idx_loan_applications_branch_status
    ON bmt_db.loan_applications(branch_id, status);

CREATE INDEX idx_loan_applications_marketing
    ON bmt_db.loan_applications(marketing_user_id);


CREATE INDEX idx_loan_collaterals_application
    ON bmt_db.loan_collaterals(loan_application_id);


CREATE INDEX idx_loan_accounts_savings
    ON bmt_db.loan_accounts(savings_account_id);

CREATE INDEX idx_loan_accounts_status
    ON bmt_db.loan_accounts(loan_status);


CREATE INDEX idx_loan_schedules_account_due
    ON bmt_db.loan_schedules(loan_account_id, due_date);

CREATE INDEX idx_loan_schedules_status_due
    ON bmt_db.loan_schedules(status, due_date);


CREATE INDEX idx_installment_payments_schedule
    ON bmt_db.installment_payments(loan_schedule_id);


-- ============================================================
-- 16. UPDATED_AT TRIGGERS
-- ============================================================

CREATE TRIGGER trg_financial_accounts_updated_at
BEFORE UPDATE ON bmt_db.financial_accounts
FOR EACH ROW
EXECUTE FUNCTION bmt_db.set_updated_at();

CREATE TRIGGER trg_savings_accounts_updated_at
BEFORE UPDATE ON bmt_db.savings_accounts
FOR EACH ROW
EXECUTE FUNCTION bmt_db.set_updated_at();

CREATE TRIGGER trg_deposit_accounts_updated_at
BEFORE UPDATE ON bmt_db.deposit_accounts
FOR EACH ROW
EXECUTE FUNCTION bmt_db.set_updated_at();

CREATE TRIGGER trg_loan_applications_updated_at
BEFORE UPDATE ON bmt_db.loan_applications
FOR EACH ROW
EXECUTE FUNCTION bmt_db.set_updated_at();

CREATE TRIGGER trg_credit_analyses_updated_at
BEFORE UPDATE ON bmt_db.credit_analyses
FOR EACH ROW
EXECUTE FUNCTION bmt_db.set_updated_at();

CREATE TRIGGER trg_loan_collaterals_updated_at
BEFORE UPDATE ON bmt_db.loan_collaterals
FOR EACH ROW
EXECUTE FUNCTION bmt_db.set_updated_at();

CREATE TRIGGER trg_loan_accounts_updated_at
BEFORE UPDATE ON bmt_db.loan_accounts
FOR EACH ROW
EXECUTE FUNCTION bmt_db.set_updated_at();

CREATE TRIGGER trg_loan_schedules_updated_at
BEFORE UPDATE ON bmt_db.loan_schedules
FOR EACH ROW
EXECUTE FUNCTION bmt_db.set_updated_at();


-- ============================================================
-- 17. SECURITY BASELINE
-- ============================================================

REVOKE ALL ON ALL TABLES IN SCHEMA bmt_db FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA bmt_db FROM PUBLIC;


COMMIT;
