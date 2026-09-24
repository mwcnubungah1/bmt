-- ============================================================
-- BMT CORE BANKING SYSTEM
-- Migration : 001_bmt_schema.sql
-- Purpose   : Schema, domains, enums, base privileges
-- Version   : 1.0.0
-- ============================================================

BEGIN;

-- ============================================================
-- 1. SCHEMA
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bmt_db;

COMMENT ON SCHEMA bmt_db IS
'BMT Core Banking System - SAK-EP accounting and operational schema';


-- ============================================================
-- 2. EXTENSIONS
-- ============================================================
-- gen_random_uuid() requires pgcrypto.
-- Supabase normally already provides this extension.

CREATE EXTENSION IF NOT EXISTS pgcrypto;


-- ============================================================
-- 3. DOMAIN: MONEY
-- ============================================================
-- Never use FLOAT / DOUBLE PRECISION for monetary values.

CREATE DOMAIN bmt_db.money_amount AS NUMERIC(19,2)
    CHECK (VALUE >= 0);

CREATE DOMAIN bmt_db.signed_money_amount AS NUMERIC(19,2);

CREATE DOMAIN bmt_db.percentage_rate AS NUMERIC(12,8)
    CHECK (VALUE >= 0);

CREATE DOMAIN bmt_db.currency_code AS CHAR(3)
    DEFAULT 'IDR'
    CHECK (VALUE ~ '^[A-Z]{3}$');


-- ============================================================
-- 4. ORGANIZATION ENUMS
-- ============================================================

CREATE TYPE bmt_db.branch_type AS ENUM (
    'HQ',
    'BRANCH',
    'CASH_OFFICE'
);


-- ============================================================
-- 5. CUSTOMER ENUMS
-- ============================================================

CREATE TYPE bmt_db.customer_status AS ENUM (
    'PROSPECT',
    'ACTIVE',
    'INACTIVE',
    'BLOCKED',
    'CLOSED'
);

CREATE TYPE bmt_db.gender_type AS ENUM (
    'MALE',
    'FEMALE'
);

CREATE TYPE bmt_db.address_type AS ENUM (
    'ID_CARD',
    'DOMICILE',
    'BUSINESS'
);


-- ============================================================
-- 6. PRODUCT ENUMS
-- ============================================================

CREATE TYPE bmt_db.product_category AS ENUM (
    'SAVINGS',
    'DEPOSIT',
    'LOAN'
);

CREATE TYPE bmt_db.contract_type AS ENUM (
    'CONVENTIONAL',
    'MURABAHAH',
    'MUDHARABAH',
    'MUSYARAKAH',
    'IJARAH',
    'QARDH',
    'OTHER'
);


-- ============================================================
-- 7. FINANCIAL ACCOUNT ENUMS
-- ============================================================

CREATE TYPE bmt_db.financial_account_type AS ENUM (
    'SAVINGS',
    'DEPOSIT',
    'LOAN'
);

CREATE TYPE bmt_db.account_status AS ENUM (
    'PENDING',
    'ACTIVE',
    'DORMANT',
    'BLOCKED',
    'PAST_DUE',
    'RESTRUCTURED',
    'MATURED',
    'PAID_OFF',
    'WRITTEN_OFF',
    'CLOSED'
);


-- ============================================================
-- 8. DEPOSIT ENUMS
-- ============================================================

CREATE TYPE bmt_db.deposit_aro_type AS ENUM (
    'NONE',
    'PRINCIPAL',
    'PRINCIPAL_AND_PROFIT'
);

CREATE TYPE bmt_db.deposit_status AS ENUM (
    'PENDING',
    'ACTIVE',
    'MATURED',
    'CLOSED',
    'EARLY_TERMINATED'
);


-- ============================================================
-- 9. LOAN APPLICATION ENUMS
-- ============================================================

CREATE TYPE bmt_db.loan_application_status AS ENUM (
    'DRAFT',
    'SUBMITTED',
    'SURVEY',
    'ANALYSIS',
    'REVIEW',
    'APPROVED',
    'REJECTED',
    'CANCELLED'
);

CREATE TYPE bmt_db.loan_account_status AS ENUM (
    'READY_FOR_DISBURSEMENT',
    'ACTIVE',
    'PAST_DUE',
    'RESTRUCTURED',
    'PAID_OFF',
    'WRITTEN_OFF',
    'CLOSED'
);

CREATE TYPE bmt_db.installment_status AS ENUM (
    'UPCOMING',
    'DUE',
    'PARTIAL',
    'PAID',
    'OVERDUE'
);


-- ============================================================
-- 10. TRANSACTION ENUMS
-- ============================================================

CREATE TYPE bmt_db.transaction_status AS ENUM (
    'DRAFT',
    'PENDING_APPROVAL',
    'APPROVED',
    'POSTED',
    'REVERSED',
    'REJECTED',
    'CANCELLED'
);

CREATE TYPE bmt_db.transaction_channel AS ENUM (
    'TELLER',
    'BACKOFFICE',
    'SYSTEM',
    'ONLINE'
);

CREATE TYPE bmt_db.ledger_entry_type AS ENUM (
    'DEBIT',
    'CREDIT'
);

CREATE TYPE bmt_db.loan_ledger_component AS ENUM (
    'PRINCIPAL',
    'MARGIN',
    'PENALTY',
    'FEE'
);


-- ============================================================
-- 11. TELLER ENUMS
-- ============================================================

CREATE TYPE bmt_db.cash_session_status AS ENUM (
    'OPEN',
    'CLOSING',
    'CLOSED'
);

CREATE TYPE bmt_db.cash_movement_type AS ENUM (
    'OPENING',
    'CASH_IN',
    'CASH_OUT',
    'TRANSFER_IN',
    'TRANSFER_OUT',
    'ADJUSTMENT',
    'CLOSING'
);


-- ============================================================
-- 12. ACCOUNTING ENUMS
-- ============================================================

CREATE TYPE bmt_db.coa_account_type AS ENUM (
    'ASSET',
    'LIABILITY',
    'EQUITY',
    'INCOME',
    'EXPENSE'
);

CREATE TYPE bmt_db.normal_balance_type AS ENUM (
    'DEBIT',
    'CREDIT'
);

CREATE TYPE bmt_db.fiscal_period_status AS ENUM (
    'OPEN',
    'SOFT_CLOSED',
    'CLOSED'
);

CREATE TYPE bmt_db.journal_status AS ENUM (
    'DRAFT',
    'POSTED',
    'REVERSED'
);


-- ============================================================
-- 13. APPROVAL ENUMS
-- ============================================================

CREATE TYPE bmt_db.approval_status AS ENUM (
    'PENDING',
    'APPROVED',
    'REJECTED',
    'CANCELLED'
);


-- ============================================================
-- 14. NUMBERING ENUMS
-- ============================================================

CREATE TYPE bmt_db.sequence_type AS ENUM (
    'CIF',
    'SAVINGS_ACCOUNT',
    'DEPOSIT_ACCOUNT',
    'LOAN_ACCOUNT',
    'LOAN_APPLICATION',
    'TRANSACTION',
    'JOURNAL',
    'RECEIPT',
    'REVERSAL'
);

CREATE TYPE bmt_db.sequence_reset_policy AS ENUM (
    'NEVER',
    'YEARLY',
    'MONTHLY',
    'DAILY'
);


-- ============================================================
-- 15. GENERIC RECORD STATUS
-- ============================================================

CREATE TYPE bmt_db.record_status AS ENUM (
    'ACTIVE',
    'INACTIVE'
);


-- ============================================================
-- 16. COMMENTS
-- ============================================================

COMMENT ON DOMAIN bmt_db.money_amount IS
'Unsigned monetary amount using NUMERIC(19,2).';

COMMENT ON DOMAIN bmt_db.signed_money_amount IS
'Signed monetary amount used for balances/differences where negative values are valid.';

COMMENT ON DOMAIN bmt_db.percentage_rate IS
'Percentage/rate value stored as NUMERIC(12,8). Interpretation is defined by product configuration.';

COMMENT ON DOMAIN bmt_db.currency_code IS
'ISO-style three-character uppercase currency code. Default IDR.';


-- ============================================================
-- 17. DEFAULT PRIVILEGE BASELINE
-- ============================================================
-- IMPORTANT:
-- Creating schema does not mean anonymous users should have
-- unrestricted access.
--
-- We intentionally do not grant table access here.
-- RLS and explicit privileges will be configured in migration 008.

REVOKE ALL ON SCHEMA bmt_db FROM PUBLIC;


COMMIT;
