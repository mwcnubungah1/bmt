BEGIN;

-- Operational controls foundation.  Sensitive tables are protected by RLS;
-- role-specific policies are added in the UI/workflow integration phase.

CREATE TABLE IF NOT EXISTS bmt_db.customer_risk_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES bmt_db.customers(id),
    risk_level VARCHAR(20) NOT NULL DEFAULT 'LOW'
        CHECK (risk_level IN ('LOW', 'MEDIUM', 'HIGH')),
    risk_score NUMERIC(8,2),
    pep_status BOOLEAN NOT NULL DEFAULT FALSE,
    sanctions_status VARCHAR(20) NOT NULL DEFAULT 'NOT_CHECKED'
        CHECK (sanctions_status IN ('NOT_CHECKED', 'CLEAR', 'REVIEW', 'MATCH')),
    source_of_funds TEXT,
    screening_checked_at TIMESTAMPTZ,
    screening_checked_by UUID REFERENCES auth.users(id),
    review_due_at DATE,
    review_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (customer_id)
);

CREATE TABLE IF NOT EXISTS bmt_db.customer_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES bmt_db.customers(id),
    old_status bmt_db.customer_status,
    new_status bmt_db.customer_status NOT NULL,
    changed_by UUID REFERENCES auth.users(id),
    changed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    reason TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS bmt_db.account_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    financial_account_id UUID NOT NULL REFERENCES bmt_db.financial_accounts(id),
    old_status bmt_db.account_status,
    new_status bmt_db.account_status NOT NULL,
    changed_by UUID REFERENCES auth.users(id),
    changed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    reason TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS bmt_db.loan_application_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    loan_application_id UUID NOT NULL REFERENCES bmt_db.loan_applications(id),
    old_status bmt_db.loan_application_status,
    new_status bmt_db.loan_application_status NOT NULL,
    changed_by UUID REFERENCES auth.users(id),
    changed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    reason TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS bmt_db.business_calendar (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id UUID REFERENCES bmt_db.branches(id),
    calendar_date DATE NOT NULL,
    is_business_day BOOLEAN NOT NULL DEFAULT TRUE,
    cut_off_at TIME,
    holiday_name VARCHAR(160),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (branch_id, calendar_date)
);

CREATE TABLE IF NOT EXISTS bmt_db.operational_days (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id UUID NOT NULL REFERENCES bmt_db.branches(id),
    business_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'OPEN'
        CHECK (status IN ('OPEN', 'CLOSING', 'CLOSED')),
    opened_at TIMESTAMPTZ,
    opened_by UUID REFERENCES auth.users(id),
    closed_at TIMESTAMPTZ,
    closed_by UUID REFERENCES auth.users(id),
    closing_summary JSONB NOT NULL DEFAULT '{}'::jsonb,
    UNIQUE (branch_id, business_date)
);

CREATE TABLE IF NOT EXISTS bmt_db.reconciliation_exceptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id UUID REFERENCES bmt_db.branches(id),
    source_system VARCHAR(40) NOT NULL,
    external_reference VARCHAR(160),
    transaction_id UUID REFERENCES bmt_db.transactions(id),
    exception_type VARCHAR(40) NOT NULL,
    amount NUMERIC(19,2),
    status VARCHAR(20) NOT NULL DEFAULT 'OPEN'
        CHECK (status IN ('OPEN', 'INVESTIGATING', 'RESOLVED', 'WRITTEN_OFF')),
    assigned_to UUID REFERENCES auth.users(id),
    resolved_by UUID REFERENCES auth.users(id),
    resolved_at TIMESTAMPTZ,
    resolution TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bmt_db.idempotency_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID REFERENCES auth.users(id),
    channel VARCHAR(30) NOT NULL,
    idempotency_key VARCHAR(160) NOT NULL,
    request_hash VARCHAR(128),
    operation VARCHAR(80) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PROCESSING'
        CHECK (status IN ('PROCESSING', 'SUCCEEDED', 'FAILED')),
    response_payload JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ,
    UNIQUE (channel, idempotency_key)
);

CREATE TABLE IF NOT EXISTS bmt_db.audit_event_changes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    audit_log_id UUID NOT NULL REFERENCES bmt_db.audit_logs(id),
    field_name VARCHAR(120) NOT NULL,
    old_value JSONB,
    new_value JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bmt_db.fee_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID REFERENCES bmt_db.products(id),
    branch_id UUID REFERENCES bmt_db.branches(id),
    fee_code VARCHAR(50) NOT NULL,
    fee_name VARCHAR(160) NOT NULL,
    calculation_type VARCHAR(20) NOT NULL
        CHECK (calculation_type IN ('FIXED', 'PERCENTAGE', 'FORMULA')),
    amount NUMERIC(19,2),
    rate NUMERIC(12,8),
    effective_from DATE NOT NULL,
    effective_until DATE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (effective_until IS NULL OR effective_until >= effective_from),
    CHECK ((calculation_type = 'FIXED' AND amount IS NOT NULL)
        OR (calculation_type = 'PERCENTAGE' AND rate IS NOT NULL)
        OR (calculation_type = 'FORMULA'))
);

CREATE INDEX IF NOT EXISTS idx_customer_risk_customer
    ON bmt_db.customer_risk_profiles(customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_status_history_customer
    ON bmt_db.customer_status_history(customer_id, changed_at DESC);
CREATE INDEX IF NOT EXISTS idx_account_status_history_account
    ON bmt_db.account_status_history(financial_account_id, changed_at DESC);
CREATE INDEX IF NOT EXISTS idx_loan_status_history_application
    ON bmt_db.loan_application_status_history(loan_application_id, changed_at DESC);
CREATE INDEX IF NOT EXISTS idx_operational_days_branch_date
    ON bmt_db.operational_days(branch_id, business_date DESC);
CREATE INDEX IF NOT EXISTS idx_reconciliation_exceptions_status
    ON bmt_db.reconciliation_exceptions(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_idempotency_actor_operation
    ON bmt_db.idempotency_keys(actor_id, operation, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_event_changes_log
    ON bmt_db.audit_event_changes(audit_log_id);
CREATE INDEX IF NOT EXISTS idx_fee_schedules_lookup
    ON bmt_db.fee_schedules(product_id, branch_id, fee_code, effective_from DESC);

GRANT USAGE ON SCHEMA bmt_db TO authenticated;
GRANT SELECT, INSERT, UPDATE ON
    bmt_db.customer_risk_profiles,
    bmt_db.customer_status_history,
    bmt_db.account_status_history,
    bmt_db.loan_application_status_history,
    bmt_db.business_calendar,
    bmt_db.operational_days,
    bmt_db.reconciliation_exceptions,
    bmt_db.idempotency_keys,
    bmt_db.audit_event_changes,
    bmt_db.fee_schedules
TO authenticated;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA bmt_db TO service_role;

ALTER TABLE bmt_db.customer_risk_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.customer_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.account_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.loan_application_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.business_calendar ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.operational_days ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.reconciliation_exceptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.idempotency_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.audit_event_changes ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.fee_schedules ENABLE ROW LEVEL SECURITY;

COMMIT;
