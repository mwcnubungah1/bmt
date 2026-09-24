-- ============================================================
-- BMT CORE BANKING SYSTEM
-- Migration : 005_bmt_accounting.sql
-- Purpose   : Transaction foundation, COA, fiscal periods,
--             sub-ledgers, journals and General Ledger
-- Version   : 1.0.0
-- Requires  : 001 - 004
-- ============================================================

BEGIN;


-- ============================================================
-- 1. CHART OF ACCOUNTS
-- ============================================================

CREATE TABLE bmt_db.chart_of_accounts (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    code                VARCHAR(30) NOT NULL,
    name                VARCHAR(150) NOT NULL,

    account_type        bmt_db.coa_account_type NOT NULL,
    normal_balance      bmt_db.normal_balance_type NOT NULL,

    parent_id           UUID NULL,

    level               INTEGER NOT NULL DEFAULT 1,
    allow_posting       BOOLEAN NOT NULL DEFAULT TRUE,
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,

    description         TEXT NULL,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uq_chart_of_accounts_code
        UNIQUE (code),

    CONSTRAINT fk_chart_of_accounts_parent
        FOREIGN KEY (parent_id)
        REFERENCES bmt_db.chart_of_accounts(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT ck_chart_of_accounts_code
        CHECK (code ~ '^[0-9]+(\.[0-9]+)*$'),

    CONSTRAINT ck_chart_of_accounts_name
        CHECK (btrim(name) <> ''),

    CONSTRAINT ck_chart_of_accounts_level
        CHECK (level > 0),

    CONSTRAINT ck_chart_of_accounts_not_self_parent
        CHECK (
            parent_id IS NULL
            OR parent_id <> id
        )
);

COMMENT ON TABLE bmt_db.chart_of_accounts IS
'Chart of Accounts. Header accounts use allow_posting=false; transaction journals post only to posting accounts.';


-- ============================================================
-- 2. ADD COA MAPPING TO PRODUCTS
-- ============================================================

ALTER TABLE bmt_db.savings_products
    ADD COLUMN liability_coa_id UUID NULL,
    ADD COLUMN admin_income_coa_id UUID NULL,
    ADD COLUMN profit_expense_coa_id UUID NULL;

ALTER TABLE bmt_db.deposit_products
    ADD COLUMN liability_coa_id UUID NULL,
    ADD COLUMN profit_expense_coa_id UUID NULL,
    ADD COLUMN penalty_income_coa_id UUID NULL;

ALTER TABLE bmt_db.loan_products
    ADD COLUMN receivable_coa_id UUID NULL,
    ADD COLUMN margin_income_coa_id UUID NULL,
    ADD COLUMN admin_income_coa_id UUID NULL,
    ADD COLUMN penalty_income_coa_id UUID NULL,
    ADD COLUMN impairment_coa_id UUID NULL;


ALTER TABLE bmt_db.savings_products
    ADD CONSTRAINT fk_savings_products_liability_coa
        FOREIGN KEY (liability_coa_id)
        REFERENCES bmt_db.chart_of_accounts(id)
        ON DELETE RESTRICT,

    ADD CONSTRAINT fk_savings_products_admin_income_coa
        FOREIGN KEY (admin_income_coa_id)
        REFERENCES bmt_db.chart_of_accounts(id)
        ON DELETE RESTRICT,

    ADD CONSTRAINT fk_savings_products_profit_expense_coa
        FOREIGN KEY (profit_expense_coa_id)
        REFERENCES bmt_db.chart_of_accounts(id)
        ON DELETE RESTRICT;


ALTER TABLE bmt_db.deposit_products
    ADD CONSTRAINT fk_deposit_products_liability_coa
        FOREIGN KEY (liability_coa_id)
        REFERENCES bmt_db.chart_of_accounts(id)
        ON DELETE RESTRICT,

    ADD CONSTRAINT fk_deposit_products_profit_expense_coa
        FOREIGN KEY (profit_expense_coa_id)
        REFERENCES bmt_db.chart_of_accounts(id)
        ON DELETE RESTRICT,

    ADD CONSTRAINT fk_deposit_products_penalty_income_coa
        FOREIGN KEY (penalty_income_coa_id)
        REFERENCES bmt_db.chart_of_accounts(id)
        ON DELETE RESTRICT;


ALTER TABLE bmt_db.loan_products
    ADD CONSTRAINT fk_loan_products_receivable_coa
        FOREIGN KEY (receivable_coa_id)
        REFERENCES bmt_db.chart_of_accounts(id)
        ON DELETE RESTRICT,

    ADD CONSTRAINT fk_loan_products_margin_income_coa
        FOREIGN KEY (margin_income_coa_id)
        REFERENCES bmt_db.chart_of_accounts(id)
        ON DELETE RESTRICT,

    ADD CONSTRAINT fk_loan_products_admin_income_coa
        FOREIGN KEY (admin_income_coa_id)
        REFERENCES bmt_db.chart_of_accounts(id)
        ON DELETE RESTRICT,

    ADD CONSTRAINT fk_loan_products_penalty_income_coa
        FOREIGN KEY (penalty_income_coa_id)
        REFERENCES bmt_db.chart_of_accounts(id)
        ON DELETE RESTRICT,

    ADD CONSTRAINT fk_loan_products_impairment_coa
        FOREIGN KEY (impairment_coa_id)
        REFERENCES bmt_db.chart_of_accounts(id)
        ON DELETE RESTRICT;


-- ============================================================
-- 3. FISCAL PERIODS
-- ============================================================

CREATE TABLE bmt_db.fiscal_periods (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    fiscal_year         INTEGER NOT NULL,
    period_no           INTEGER NOT NULL,

    start_date          DATE NOT NULL,
    end_date            DATE NOT NULL,

    status              bmt_db.fiscal_period_status
                        NOT NULL DEFAULT 'OPEN',

    closed_by           UUID NULL,
    closed_at           TIMESTAMPTZ NULL,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uq_fiscal_periods_year_period
        UNIQUE (fiscal_year, period_no),

    CONSTRAINT fk_fiscal_periods_closed_by
        FOREIGN KEY (closed_by)
        REFERENCES bmt_db.user_profiles(id)
        ON DELETE RESTRICT,

    CONSTRAINT ck_fiscal_periods_year
        CHECK (fiscal_year BETWEEN 2000 AND 2200),

    CONSTRAINT ck_fiscal_periods_period
        CHECK (period_no BETWEEN 1 AND 12),

    CONSTRAINT ck_fiscal_periods_dates
        CHECK (end_date >= start_date),

    CONSTRAINT ck_fiscal_periods_closed
        CHECK (
            status <> 'CLOSED'
            OR (closed_by IS NOT NULL AND closed_at IS NOT NULL)
        )
);

COMMENT ON TABLE bmt_db.fiscal_periods IS
'Accounting periods. Financial posting into CLOSED periods is prohibited.';


-- ============================================================
-- 4. TRANSACTIONS
-- ============================================================

CREATE TABLE bmt_db.transactions (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    transaction_number      VARCHAR(50) NOT NULL,

    branch_id               UUID NOT NULL,

    transaction_type        VARCHAR(50) NOT NULL,

    customer_id             UUID NULL,
    financial_account_id    UUID NULL,

    amount                  bmt_db.money_amount NOT NULL,

    currency                bmt_db.currency_code
                            NOT NULL DEFAULT 'IDR',

    transaction_date        DATE NOT NULL DEFAULT CURRENT_DATE,
    value_date              DATE NOT NULL DEFAULT CURRENT_DATE,

    status                  bmt_db.transaction_status
                            NOT NULL DEFAULT 'DRAFT',

    channel                 bmt_db.transaction_channel
                            NOT NULL DEFAULT 'BACKOFFICE',

    description             TEXT NULL,
    reference_number        VARCHAR(100) NULL,

    created_by              UUID NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),

    approved_by             UUID NULL,
    approved_at             TIMESTAMPTZ NULL,

    posted_by               UUID NULL,
    posted_at               TIMESTAMPTZ NULL,

    reversed_transaction_id UUID NULL,

    CONSTRAINT uq_transactions_number
        UNIQUE (transaction_number),

    CONSTRAINT fk_transactions_branch
        FOREIGN KEY (branch_id)
        REFERENCES bmt_db.branches(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_transactions_customer
        FOREIGN KEY (customer_id)
        REFERENCES bmt_db.customers(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_transactions_financial_account
        FOREIGN KEY (financial_account_id)
        REFERENCES bmt_db.financial_accounts(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_transactions_created_by
        FOREIGN KEY (created_by)
        REFERENCES bmt_db.user_profiles(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_transactions_approved_by
        FOREIGN KEY (approved_by)
        REFERENCES bmt_db.user_profiles(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_transactions_posted_by
        FOREIGN KEY (posted_by)
        REFERENCES bmt_db.user_profiles(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_transactions_reversal
        FOREIGN KEY (reversed_transaction_id)
        REFERENCES bmt_db.transactions(id)
        ON DELETE RESTRICT,

    CONSTRAINT ck_transactions_number
        CHECK (btrim(transaction_number) <> ''),

    CONSTRAINT ck_transactions_type
        CHECK (
            transaction_type ~ '^[A-Z][A-Z0-9_]*$'
        ),

    CONSTRAINT ck_transactions_amount
        CHECK (amount > 0),

    CONSTRAINT ck_transactions_approval
        CHECK (
            status <> 'APPROVED'
            OR (approved_by IS NOT NULL AND approved_at IS NOT NULL)
        ),

    CONSTRAINT ck_transactions_posting
        CHECK (
            status NOT IN ('POSTED', 'REVERSED')
            OR (posted_by IS NOT NULL AND posted_at IS NOT NULL)
        ),

    CONSTRAINT ck_transactions_not_self_reversal
        CHECK (
            reversed_transaction_id IS NULL
            OR reversed_transaction_id <> id
        )
);

COMMENT ON TABLE bmt_db.transactions IS
'Universal business transaction header. POSTED financial transactions become immutable.';


-- ============================================================
-- 5. ONLY ONE REVERSAL PER ORIGINAL TRANSACTION
-- ============================================================

CREATE UNIQUE INDEX uq_transactions_single_reversal
    ON bmt_db.transactions(reversed_transaction_id)
    WHERE reversed_transaction_id IS NOT NULL;


-- ============================================================
-- 6. LINK INSTALLMENT PAYMENT TO TRANSACTION
-- ============================================================

ALTER TABLE bmt_db.installment_payments
    ADD COLUMN transaction_id UUID NULL;

ALTER TABLE bmt_db.installment_payments
    ADD CONSTRAINT fk_installment_payments_transaction
        FOREIGN KEY (transaction_id)
        REFERENCES bmt_db.transactions(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT;

CREATE INDEX idx_installment_payments_transaction
    ON bmt_db.installment_payments(transaction_id);


-- ============================================================
-- 7. SAVINGS LEDGER
-- ============================================================

CREATE TABLE bmt_db.savings_ledger (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    account_id          UUID NOT NULL,
    transaction_id      UUID NOT NULL,

    entry_date          DATE NOT NULL,
    value_date          DATE NOT NULL,

    entry_type          bmt_db.ledger_entry_type NOT NULL,

    amount              bmt_db.money_amount NOT NULL,

    balance_after       bmt_db.signed_money_amount NOT NULL,

    description         TEXT NULL,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_savings_ledger_account
        FOREIGN KEY (account_id)
        REFERENCES bmt_db.savings_accounts(financial_account_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_savings_ledger_transaction
        FOREIGN KEY (transaction_id)
        REFERENCES bmt_db.transactions(id)
        ON DELETE RESTRICT,

    CONSTRAINT ck_savings_ledger_amount
        CHECK (amount > 0)
);

COMMENT ON TABLE bmt_db.savings_ledger IS
'Append-only operational ledger for savings accounts.';


-- ============================================================
-- 8. DEPOSIT LEDGER
-- ============================================================

CREATE TABLE bmt_db.deposit_ledger (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    deposit_account_id  UUID NOT NULL,
    transaction_id      UUID NOT NULL,

    entry_date          DATE NOT NULL,
    value_date          DATE NOT NULL,

    entry_type          bmt_db.ledger_entry_type NOT NULL,

    amount              bmt_db.money_amount NOT NULL,

    balance_after       bmt_db.signed_money_amount NOT NULL,

    description         TEXT NULL,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_deposit_ledger_account
        FOREIGN KEY (deposit_account_id)
        REFERENCES bmt_db.deposit_accounts(financial_account_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_deposit_ledger_transaction
        FOREIGN KEY (transaction_id)
        REFERENCES bmt_db.transactions(id)
        ON DELETE RESTRICT,

    CONSTRAINT ck_deposit_ledger_amount
        CHECK (amount > 0)
);

COMMENT ON TABLE bmt_db.deposit_ledger IS
'Append-only operational ledger for deposit accounts.';


-- ============================================================
-- 9. LOAN LEDGER
-- ============================================================

CREATE TABLE bmt_db.loan_ledger (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    loan_account_id     UUID NOT NULL,
    transaction_id      UUID NOT NULL,

    entry_date          DATE NOT NULL,
    value_date          DATE NOT NULL,

    component           bmt_db.loan_ledger_component NOT NULL,
    entry_type          bmt_db.ledger_entry_type NOT NULL,

    amount              bmt_db.money_amount NOT NULL,

    balance_after       bmt_db.signed_money_amount NOT NULL,

    description         TEXT NULL,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_loan_ledger_account
        FOREIGN KEY (loan_account_id)
        REFERENCES bmt_db.loan_accounts(financial_account_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_loan_ledger_transaction
        FOREIGN KEY (transaction_id)
        REFERENCES bmt_db.transactions(id)
        ON DELETE RESTRICT,

    CONSTRAINT ck_loan_ledger_amount
        CHECK (amount > 0)
);

COMMENT ON TABLE bmt_db.loan_ledger IS
'Append-only operational ledger for principal, margin, penalty and fee components.';


-- ============================================================
-- 10. JOURNAL ENTRIES
-- ============================================================

CREATE TABLE bmt_db.journal_entries (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    journal_number      VARCHAR(50) NOT NULL,

    transaction_id      UUID NOT NULL,

    branch_id           UUID NOT NULL,
    fiscal_period_id    UUID NOT NULL,

    journal_date        DATE NOT NULL,

    description         TEXT NOT NULL,

    status              bmt_db.journal_status
                        NOT NULL DEFAULT 'DRAFT',

    created_by          UUID NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    posted_by           UUID NULL,
    posted_at           TIMESTAMPTZ NULL,

    reversal_journal_id UUID NULL,

    CONSTRAINT uq_journal_entries_number
        UNIQUE (journal_number),

    CONSTRAINT uq_journal_entries_transaction
        UNIQUE (transaction_id),

    CONSTRAINT fk_journal_entries_transaction
        FOREIGN KEY (transaction_id)
        REFERENCES bmt_db.transactions(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_journal_entries_branch
        FOREIGN KEY (branch_id)
        REFERENCES bmt_db.branches(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_journal_entries_period
        FOREIGN KEY (fiscal_period_id)
        REFERENCES bmt_db.fiscal_periods(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_journal_entries_created_by
        FOREIGN KEY (created_by)
        REFERENCES bmt_db.user_profiles(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_journal_entries_posted_by
        FOREIGN KEY (posted_by)
        REFERENCES bmt_db.user_profiles(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_journal_entries_reversal
        FOREIGN KEY (reversal_journal_id)
        REFERENCES bmt_db.journal_entries(id)
        ON DELETE RESTRICT,

    CONSTRAINT ck_journal_entries_description
        CHECK (btrim(description) <> ''),

    CONSTRAINT ck_journal_entries_posted
        CHECK (
            status NOT IN ('POSTED', 'REVERSED')
            OR (posted_by IS NOT NULL AND posted_at IS NOT NULL)
        ),

    CONSTRAINT ck_journal_entries_not_self_reversal
        CHECK (
            reversal_journal_id IS NULL
            OR reversal_journal_id <> id
        )
);

COMMENT ON TABLE bmt_db.journal_entries IS
'Double-entry journal header. POSTED journals are immutable.';


-- ============================================================
-- 11. ONLY ONE REVERSAL JOURNAL
-- ============================================================

CREATE UNIQUE INDEX uq_journal_entries_single_reversal
    ON bmt_db.journal_entries(reversal_journal_id)
    WHERE reversal_journal_id IS NOT NULL;


-- ============================================================
-- 12. JOURNAL LINES
-- ============================================================

CREATE TABLE bmt_db.journal_lines (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    journal_entry_id        UUID NOT NULL,
    line_no                 INTEGER NOT NULL,

    coa_id                  UUID NOT NULL,

    customer_id             UUID NULL,
    financial_account_id    UUID NULL,

    debit                   bmt_db.money_amount NOT NULL DEFAULT 0,
    credit                  bmt_db.money_amount NOT NULL DEFAULT 0,

    description             TEXT NULL,

    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_journal_lines_entry
        FOREIGN KEY (journal_entry_id)
        REFERENCES bmt_db.journal_entries(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_journal_lines_coa
        FOREIGN KEY (coa_id)
        REFERENCES bmt_db.chart_of_accounts(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_journal_lines_customer
        FOREIGN KEY (customer_id)
        REFERENCES bmt_db.customers(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_journal_lines_financial_account
        FOREIGN KEY (financial_account_id)
        REFERENCES bmt_db.financial_accounts(id)
        ON DELETE RESTRICT,

    CONSTRAINT uq_journal_lines_number
        UNIQUE (journal_entry_id, line_no),

    CONSTRAINT ck_journal_lines_line_no
        CHECK (line_no > 0),

    CONSTRAINT ck_journal_lines_debit_credit
        CHECK (
            (debit > 0 AND credit = 0)
            OR
            (credit > 0 AND debit = 0)
        )
);

COMMENT ON TABLE bmt_db.journal_lines IS
'Double-entry journal lines. Journal-level debit=credit is enforced by posting engine.';


-- ============================================================
-- 13. VALIDATE COA POSTING ACCOUNT
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.validate_journal_line_coa()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
    v_allow_posting BOOLEAN;
    v_is_active     BOOLEAN;
BEGIN
    SELECT
        c.allow_posting,
        c.is_active
    INTO
        v_allow_posting,
        v_is_active
    FROM bmt_db.chart_of_accounts c
    WHERE c.id = NEW.coa_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'COA % does not exist', NEW.coa_id;
    END IF;

    IF v_allow_posting IS NOT TRUE THEN
        RAISE EXCEPTION
            'Journal cannot post to header/non-posting COA %',
            NEW.coa_id;
    END IF;

    IF v_is_active IS NOT TRUE THEN
        RAISE EXCEPTION
            'Journal cannot post to inactive COA %',
            NEW.coa_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_journal_line_coa_validation
BEFORE INSERT OR UPDATE OF coa_id
ON bmt_db.journal_lines
FOR EACH ROW
EXECUTE FUNCTION bmt_db.validate_journal_line_coa();


-- ============================================================
-- 14. INDEXES
-- ============================================================

CREATE INDEX idx_coa_parent
    ON bmt_db.chart_of_accounts(parent_id);

CREATE INDEX idx_coa_type
    ON bmt_db.chart_of_accounts(account_type);

CREATE INDEX idx_coa_posting
    ON bmt_db.chart_of_accounts(is_active, allow_posting);


CREATE INDEX idx_fiscal_periods_dates
    ON bmt_db.fiscal_periods(start_date, end_date);

CREATE INDEX idx_fiscal_periods_status
    ON bmt_db.fiscal_periods(status);


CREATE INDEX idx_transactions_branch_date
    ON bmt_db.transactions(branch_id, transaction_date);

CREATE INDEX idx_transactions_customer
    ON bmt_db.transactions(customer_id);

CREATE INDEX idx_transactions_financial_account
    ON bmt_db.transactions(financial_account_id);

CREATE INDEX idx_transactions_status
    ON bmt_db.transactions(status);

CREATE INDEX idx_transactions_type_date
    ON bmt_db.transactions(transaction_type, transaction_date);

CREATE INDEX idx_transactions_value_date
    ON bmt_db.transactions(value_date);


CREATE INDEX idx_savings_ledger_account_date
    ON bmt_db.savings_ledger(account_id, entry_date, created_at);

CREATE INDEX idx_savings_ledger_transaction
    ON bmt_db.savings_ledger(transaction_id);


CREATE INDEX idx_deposit_ledger_account_date
    ON bmt_db.deposit_ledger(deposit_account_id, entry_date, created_at);

CREATE INDEX idx_deposit_ledger_transaction
    ON bmt_db.deposit_ledger(transaction_id);


CREATE INDEX idx_loan_ledger_account_date
    ON bmt_db.loan_ledger(loan_account_id, entry_date, created_at);

CREATE INDEX idx_loan_ledger_transaction
    ON bmt_db.loan_ledger(transaction_id);

CREATE INDEX idx_loan_ledger_component
    ON bmt_db.loan_ledger(loan_account_id, component);


CREATE INDEX idx_journal_entries_branch_date
    ON bmt_db.journal_entries(branch_id, journal_date);

CREATE INDEX idx_journal_entries_period
    ON bmt_db.journal_entries(fiscal_period_id);

CREATE INDEX idx_journal_entries_status
    ON bmt_db.journal_entries(status);


CREATE INDEX idx_journal_lines_entry
    ON bmt_db.journal_lines(journal_entry_id);

CREATE INDEX idx_journal_lines_coa
    ON bmt_db.journal_lines(coa_id);

CREATE INDEX idx_journal_lines_customer
    ON bmt_db.journal_lines(customer_id);

CREATE INDEX idx_journal_lines_financial_account
    ON bmt_db.journal_lines(financial_account_id);


-- ============================================================
-- 15. GENERAL LEDGER VIEW
-- ============================================================

CREATE VIEW bmt_db.general_ledger AS
SELECT
    je.id                       AS journal_entry_id,
    je.journal_number,
    je.transaction_id,

    je.branch_id,
    b.code                      AS branch_code,
    b.name                      AS branch_name,

    je.fiscal_period_id,
    fp.fiscal_year,
    fp.period_no,

    je.journal_date,

    jl.line_no,

    jl.coa_id,
    coa.code                    AS coa_code,
    coa.name                    AS coa_name,
    coa.account_type,
    coa.normal_balance,

    jl.customer_id,
    jl.financial_account_id,

    jl.debit,
    jl.credit,

    je.description              AS journal_description,
    jl.description              AS line_description,

    je.posted_at

FROM bmt_db.journal_entries je

JOIN bmt_db.journal_lines jl
    ON jl.journal_entry_id = je.id

JOIN bmt_db.chart_of_accounts coa
    ON coa.id = jl.coa_id

JOIN bmt_db.branches b
    ON b.id = je.branch_id

JOIN bmt_db.fiscal_periods fp
    ON fp.id = je.fiscal_period_id

WHERE je.status = 'POSTED';

COMMENT ON VIEW bmt_db.general_ledger IS
'General Ledger derived exclusively from POSTED journal entries.';


-- ============================================================
-- 16. TRIAL BALANCE VIEW
-- ============================================================

CREATE VIEW bmt_db.trial_balance AS
SELECT
    gl.branch_id,
    gl.branch_code,

    gl.fiscal_year,
    gl.period_no,

    gl.coa_id,
    gl.coa_code,
    gl.coa_name,
    gl.account_type,
    gl.normal_balance,

    SUM(gl.debit)::NUMERIC(19,2)  AS total_debit,
    SUM(gl.credit)::NUMERIC(19,2) AS total_credit,

    (
        SUM(gl.debit) - SUM(gl.credit)
    )::NUMERIC(19,2) AS net_debit_balance

FROM bmt_db.general_ledger gl

GROUP BY
    gl.branch_id,
    gl.branch_code,
    gl.fiscal_year,
    gl.period_no,
    gl.coa_id,
    gl.coa_code,
    gl.coa_name,
    gl.account_type,
    gl.normal_balance;

COMMENT ON VIEW bmt_db.trial_balance IS
'Period/branch trial balance derived from General Ledger.';


-- ============================================================
-- 17. UPDATED_AT
-- ============================================================

CREATE TRIGGER trg_chart_of_accounts_updated_at
BEFORE UPDATE ON bmt_db.chart_of_accounts
FOR EACH ROW
EXECUTE FUNCTION bmt_db.set_updated_at();

CREATE TRIGGER trg_fiscal_periods_updated_at
BEFORE UPDATE ON bmt_db.fiscal_periods
FOR EACH ROW
EXECUTE FUNCTION bmt_db.set_updated_at();


-- ============================================================
-- 18. SECURITY BASELINE
-- ============================================================

REVOKE ALL ON ALL TABLES IN SCHEMA bmt_db FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA bmt_db FROM PUBLIC;


COMMIT;
