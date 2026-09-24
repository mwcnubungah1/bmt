-- ============================================================
-- BMT CORE BANKING SYSTEM
-- Migration : 006_bmt_operations.sql
-- Purpose   : Teller cash, approval, receipt,
--             numbering configuration and audit log
-- Version   : 1.0.0
-- Requires  : 001 - 005
-- ============================================================

BEGIN;


-- ============================================================
-- 1. TELLER CASH SESSIONS
-- ============================================================

CREATE TABLE bmt_db.teller_cash_sessions (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    branch_id                   UUID NOT NULL,
    teller_user_id              UUID NOT NULL,

    business_date               DATE NOT NULL DEFAULT CURRENT_DATE,

    opening_balance             bmt_db.money_amount NOT NULL DEFAULT 0,

    system_closing_balance      bmt_db.money_amount NULL,
    physical_closing_balance    bmt_db.money_amount NULL,

    difference                  bmt_db.signed_money_amount NULL,

    status                      bmt_db.cash_session_status
                                NOT NULL DEFAULT 'OPEN',

    opened_at                   TIMESTAMPTZ NOT NULL DEFAULT now(),
    closed_at                   TIMESTAMPTZ NULL,

    closing_notes               TEXT NULL,

    approved_by                 UUID NULL,
    approved_at                 TIMESTAMPTZ NULL,

    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_teller_cash_sessions_branch
        FOREIGN KEY (branch_id)
        REFERENCES bmt_db.branches(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_teller_cash_sessions_teller
        FOREIGN KEY (teller_user_id)
        REFERENCES bmt_db.user_profiles(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_teller_cash_sessions_approved_by
        FOREIGN KEY (approved_by)
        REFERENCES bmt_db.user_profiles(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT ck_teller_cash_sessions_close
        CHECK (
            status <> 'CLOSED'
            OR (
                closed_at IS NOT NULL
                AND system_closing_balance IS NOT NULL
                AND physical_closing_balance IS NOT NULL
                AND difference IS NOT NULL
            )
        ),

    CONSTRAINT ck_teller_cash_sessions_approval_pair
        CHECK (
            (approved_by IS NULL AND approved_at IS NULL)
            OR
            (approved_by IS NOT NULL AND approved_at IS NOT NULL)
        )
);

COMMENT ON TABLE bmt_db.teller_cash_sessions IS
'Daily teller cash drawer/session. Cash transactions require an OPEN session.';


-- ============================================================
-- 2. ONLY ONE OPEN SESSION PER TELLER + BRANCH
-- ============================================================

CREATE UNIQUE INDEX uq_teller_one_open_session
    ON bmt_db.teller_cash_sessions(teller_user_id, branch_id)
    WHERE status = 'OPEN';


-- ============================================================
-- 3. TELLER CASH MOVEMENTS
-- ============================================================

CREATE TABLE bmt_db.teller_cash_movements (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    cash_session_id         UUID NOT NULL,
    transaction_id          UUID NULL,

    movement_type           bmt_db.cash_movement_type NOT NULL,

    amount                  bmt_db.money_amount NOT NULL,

    description             TEXT NULL,

    created_by              UUID NOT NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_teller_cash_movements_session
        FOREIGN KEY (cash_session_id)
        REFERENCES bmt_db.teller_cash_sessions(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_teller_cash_movements_transaction
        FOREIGN KEY (transaction_id)
        REFERENCES bmt_db.transactions(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_teller_cash_movements_created_by
        FOREIGN KEY (created_by)
        REFERENCES bmt_db.user_profiles(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT ck_teller_cash_movements_amount
        CHECK (amount > 0)
);

COMMENT ON TABLE bmt_db.teller_cash_movements IS
'Append-only cash movement detail for teller sessions.';


-- ============================================================
-- 4. ADD TELLER SESSION TO TRANSACTIONS
-- ============================================================

ALTER TABLE bmt_db.transactions
    ADD COLUMN teller_session_id UUID NULL;

ALTER TABLE bmt_db.transactions
    ADD CONSTRAINT fk_transactions_teller_session
        FOREIGN KEY (teller_session_id)
        REFERENCES bmt_db.teller_cash_sessions(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT;


-- ============================================================
-- 5. APPROVAL RULES
-- ============================================================

CREATE TABLE bmt_db.approval_rules (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    transaction_type            VARCHAR(50) NOT NULL,

    branch_id                   UUID NULL,

    minimum_amount              bmt_db.money_amount NOT NULL DEFAULT 0,
    maximum_amount              bmt_db.money_amount NULL,

    required_role               VARCHAR(50) NOT NULL,

    approval_level              INTEGER NOT NULL DEFAULT 1,

    maker_checker_required      BOOLEAN NOT NULL DEFAULT TRUE,

    is_active                   BOOLEAN NOT NULL DEFAULT TRUE,

    effective_from              DATE NOT NULL DEFAULT CURRENT_DATE,
    effective_until             DATE NULL,

    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_approval_rules_branch
        FOREIGN KEY (branch_id)
        REFERENCES bmt_db.branches(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT ck_approval_rules_transaction_type
        CHECK (
            transaction_type ~ '^[A-Z][A-Z0-9_]*$'
        ),

    CONSTRAINT ck_approval_rules_required_role
        CHECK (
            required_role ~ '^[A-Z][A-Z0-9_]*$'
        ),

    CONSTRAINT ck_approval_rules_amount
        CHECK (
            maximum_amount IS NULL
            OR maximum_amount >= minimum_amount
        ),

    CONSTRAINT ck_approval_rules_level
        CHECK (approval_level > 0),

    CONSTRAINT ck_approval_rules_effective
        CHECK (
            effective_until IS NULL
            OR effective_until >= effective_from
        )
);

COMMENT ON TABLE bmt_db.approval_rules IS
'Configurable maker-checker and transaction approval thresholds.';


-- ============================================================
-- 6. APPROVAL REQUESTS
-- ============================================================

CREATE TABLE bmt_db.approval_requests (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    entity_type             VARCHAR(50) NOT NULL,
    entity_id               UUID NOT NULL,

    approval_type           VARCHAR(50) NOT NULL,

    requested_by            UUID NOT NULL,
    requested_at            TIMESTAMPTZ NOT NULL DEFAULT now(),

    status                  bmt_db.approval_status
                            NOT NULL DEFAULT 'PENDING',

    required_role           VARCHAR(50) NOT NULL,
    required_level          INTEGER NOT NULL DEFAULT 1,

    maker_checker_required  BOOLEAN NOT NULL DEFAULT TRUE,

    resolved_by             UUID NULL,
    resolved_at             TIMESTAMPTZ NULL,

    reason                  TEXT NULL,
    notes                   TEXT NULL,

    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_approval_requests_requested_by
        FOREIGN KEY (requested_by)
        REFERENCES bmt_db.user_profiles(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_approval_requests_resolved_by
        FOREIGN KEY (resolved_by)
        REFERENCES bmt_db.user_profiles(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT ck_approval_requests_entity_type
        CHECK (
            entity_type ~ '^[A-Z][A-Z0-9_]*$'
        ),

    CONSTRAINT ck_approval_requests_type
        CHECK (
            approval_type ~ '^[A-Z][A-Z0-9_]*$'
        ),

    CONSTRAINT ck_approval_requests_required_role
        CHECK (
            required_role ~ '^[A-Z][A-Z0-9_]*$'
        ),

    CONSTRAINT ck_approval_requests_level
        CHECK (required_level > 0),

    CONSTRAINT ck_approval_requests_resolution
        CHECK (
            status = 'PENDING'
            OR (
                resolved_by IS NOT NULL
                AND resolved_at IS NOT NULL
            )
        ),

    CONSTRAINT ck_approval_requests_maker_checker
        CHECK (
            maker_checker_required = FALSE
            OR resolved_by IS NULL
            OR resolved_by <> requested_by
        )
);

COMMENT ON TABLE bmt_db.approval_requests IS
'Approval workflow instance. Maker cannot resolve their own request when maker-checker is required.';


-- ============================================================
-- 7. ONE PENDING APPROVAL OF SAME TYPE PER ENTITY
-- ============================================================

CREATE UNIQUE INDEX uq_approval_requests_pending
    ON bmt_db.approval_requests(
        entity_type,
        entity_id,
        approval_type,
        required_level
    )
    WHERE status = 'PENDING';


-- ============================================================
-- 8. TRANSACTION RECEIPTS
-- ============================================================

CREATE TABLE bmt_db.transaction_receipts (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    transaction_id          UUID NOT NULL,
    receipt_number          VARCHAR(50) NOT NULL,

    template_type           VARCHAR(50) NOT NULL DEFAULT 'STANDARD',

    printed_count           INTEGER NOT NULL DEFAULT 0,

    first_printed_at        TIMESTAMPTZ NULL,
    last_printed_at         TIMESTAMPTZ NULL,
    last_printed_by         UUID NULL,

    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uq_transaction_receipts_transaction
        UNIQUE (transaction_id),

    CONSTRAINT uq_transaction_receipts_number
        UNIQUE (receipt_number),

    CONSTRAINT fk_transaction_receipts_transaction
        FOREIGN KEY (transaction_id)
        REFERENCES bmt_db.transactions(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_transaction_receipts_last_printed_by
        FOREIGN KEY (last_printed_by)
        REFERENCES bmt_db.user_profiles(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT ck_transaction_receipts_number
        CHECK (btrim(receipt_number) <> ''),

    CONSTRAINT ck_transaction_receipts_template
        CHECK (
            template_type ~ '^[A-Z][A-Z0-9_]*$'
        ),

    CONSTRAINT ck_transaction_receipts_count
        CHECK (printed_count >= 0),

    CONSTRAINT ck_transaction_receipts_print_state
        CHECK (
            (
                printed_count = 0
                AND first_printed_at IS NULL
                AND last_printed_at IS NULL
                AND last_printed_by IS NULL
            )
            OR
            (
                printed_count > 0
                AND first_printed_at IS NOT NULL
                AND last_printed_at IS NOT NULL
                AND last_printed_by IS NOT NULL
            )
        )
);

COMMENT ON TABLE bmt_db.transaction_receipts IS
'Receipt metadata and print/reprint counters.';


-- ============================================================
-- 9. NUMBER SEQUENCES
-- ============================================================
-- Empty string is intentionally used instead of NULL for
-- optional product/loan codes so uniqueness is deterministic.

CREATE TABLE bmt_db.number_sequences (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    branch_id           UUID NOT NULL,

    sequence_type       bmt_db.sequence_type NOT NULL,

    product_code        VARCHAR(20) NOT NULL DEFAULT '',
    loan_code           VARCHAR(20) NOT NULL DEFAULT '',

    period_key          VARCHAR(20) NOT NULL DEFAULT '',

    current_value       BIGINT NOT NULL DEFAULT 0,

    padding             INTEGER NOT NULL DEFAULT 6,

    reset_policy        bmt_db.sequence_reset_policy
                        NOT NULL DEFAULT 'NEVER',

    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_number_sequences_branch
        FOREIGN KEY (branch_id)
        REFERENCES bmt_db.branches(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT uq_number_sequences_scope
        UNIQUE (
            branch_id,
            sequence_type,
            product_code,
            loan_code,
            period_key
        ),

    CONSTRAINT ck_number_sequences_current
        CHECK (current_value >= 0),

    CONSTRAINT ck_number_sequences_padding
        CHECK (padding BETWEEN 1 AND 12),

    CONSTRAINT ck_number_sequences_product_code
        CHECK (
            product_code = ''
            OR product_code ~ '^[A-Z0-9_-]+$'
            OR product_code ~ '^[0-9]+$'
        ),

    CONSTRAINT ck_number_sequences_loan_code
        CHECK (
            loan_code = ''
            OR loan_code ~ '^[A-Z0-9_-]+$'
            OR loan_code ~ '^[0-9]+$'
        )
);

COMMENT ON TABLE bmt_db.number_sequences IS
'Atomic business-number sequence storage. Never generate financial numbers using SELECT MAX()+1.';


-- ============================================================
-- 10. AUDIT LOGS
-- ============================================================

CREATE TABLE bmt_db.audit_logs (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    occurred_at         TIMESTAMPTZ NOT NULL DEFAULT now(),

    user_id             UUID NULL,
    role_code           VARCHAR(50) NULL,
    branch_id           UUID NULL,

    action              VARCHAR(100) NOT NULL,

    entity_type         VARCHAR(100) NOT NULL,
    entity_id           UUID NULL,

    transaction_id      UUID NULL,

    old_data            JSONB NULL,
    new_data            JSONB NULL,

    reason              TEXT NULL,

    ip_address          INET NULL,
    user_agent          TEXT NULL,

    request_id          UUID NULL,
    session_id          VARCHAR(255) NULL,

    metadata            JSONB NOT NULL DEFAULT '{}'::jsonb,

    CONSTRAINT fk_audit_logs_user
        FOREIGN KEY (user_id)
        REFERENCES bmt_db.user_profiles(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_audit_logs_branch
        FOREIGN KEY (branch_id)
        REFERENCES bmt_db.branches(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_audit_logs_transaction
        FOREIGN KEY (transaction_id)
        REFERENCES bmt_db.transactions(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT ck_audit_logs_action
        CHECK (
            action ~ '^[A-Z][A-Z0-9_]*$'
        ),

    CONSTRAINT ck_audit_logs_entity_type
        CHECK (
            entity_type ~ '^[A-Z][A-Z0-9_]*$'
        ),

    CONSTRAINT ck_audit_logs_metadata_object
        CHECK (
            jsonb_typeof(metadata) = 'object'
        )
);

COMMENT ON TABLE bmt_db.audit_logs IS
'Append-only audit trail for security, operational and financial activity.';


-- ============================================================
-- 11. INDEXES
-- ============================================================

CREATE INDEX idx_teller_cash_sessions_branch_date
    ON bmt_db.teller_cash_sessions(branch_id, business_date);

CREATE INDEX idx_teller_cash_sessions_teller_date
    ON bmt_db.teller_cash_sessions(teller_user_id, business_date);

CREATE INDEX idx_teller_cash_sessions_status
    ON bmt_db.teller_cash_sessions(status);


CREATE INDEX idx_teller_cash_movements_session
    ON bmt_db.teller_cash_movements(cash_session_id, created_at);

CREATE INDEX idx_teller_cash_movements_transaction
    ON bmt_db.teller_cash_movements(transaction_id);


CREATE INDEX idx_transactions_teller_session
    ON bmt_db.transactions(teller_session_id);


CREATE INDEX idx_approval_rules_transaction
    ON bmt_db.approval_rules(transaction_type, is_active);

CREATE INDEX idx_approval_rules_branch
    ON bmt_db.approval_rules(branch_id);


CREATE INDEX idx_approval_requests_entity
    ON bmt_db.approval_requests(entity_type, entity_id);

CREATE INDEX idx_approval_requests_status
    ON bmt_db.approval_requests(status, requested_at);

CREATE INDEX idx_approval_requests_requester
    ON bmt_db.approval_requests(requested_by);

CREATE INDEX idx_approval_requests_resolver
    ON bmt_db.approval_requests(resolved_by);


CREATE INDEX idx_number_sequences_branch
    ON bmt_db.number_sequences(branch_id);


CREATE INDEX idx_audit_logs_occurred
    ON bmt_db.audit_logs(occurred_at);

CREATE INDEX idx_audit_logs_user
    ON bmt_db.audit_logs(user_id, occurred_at);

CREATE INDEX idx_audit_logs_entity
    ON bmt_db.audit_logs(entity_type, entity_id, occurred_at);

CREATE INDEX idx_audit_logs_transaction
    ON bmt_db.audit_logs(transaction_id);

CREATE INDEX idx_audit_logs_request
    ON bmt_db.audit_logs(request_id);


-- ============================================================
-- 12. TELLER CLOSING VALIDATION
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.validate_teller_cash_session()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
    v_expected_difference NUMERIC(19,2);
BEGIN
    IF NEW.status = 'CLOSED' THEN

        v_expected_difference :=
            NEW.physical_closing_balance
            - NEW.system_closing_balance;

        IF NEW.difference <> v_expected_difference THEN
            RAISE EXCEPTION
                'Cash difference must equal physical balance minus system balance';
        END IF;

        IF NEW.difference <> 0
           AND NULLIF(btrim(NEW.closing_notes), '') IS NULL THEN
            RAISE EXCEPTION
                'Closing notes are required when teller cash has a difference';
        END IF;

    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_teller_cash_session_validation
BEFORE INSERT OR UPDATE
ON bmt_db.teller_cash_sessions
FOR EACH ROW
EXECUTE FUNCTION bmt_db.validate_teller_cash_session();


-- ============================================================
-- 13. APPEND-ONLY GUARD
-- ============================================================
-- Internal financial engine will insert these rows.
-- Existing rows cannot be updated/deleted.

CREATE OR REPLACE FUNCTION bmt_db.prevent_append_only_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
    RAISE EXCEPTION
        'Table %.% is append-only; % is not allowed',
        TG_TABLE_SCHEMA,
        TG_TABLE_NAME,
        TG_OP;
END;
$$;


CREATE TRIGGER trg_savings_ledger_append_only
BEFORE UPDATE OR DELETE ON bmt_db.savings_ledger
FOR EACH ROW
EXECUTE FUNCTION bmt_db.prevent_append_only_mutation();

CREATE TRIGGER trg_deposit_ledger_append_only
BEFORE UPDATE OR DELETE ON bmt_db.deposit_ledger
FOR EACH ROW
EXECUTE FUNCTION bmt_db.prevent_append_only_mutation();

CREATE TRIGGER trg_loan_ledger_append_only
BEFORE UPDATE OR DELETE ON bmt_db.loan_ledger
FOR EACH ROW
EXECUTE FUNCTION bmt_db.prevent_append_only_mutation();

CREATE TRIGGER trg_teller_cash_movements_append_only
BEFORE UPDATE OR DELETE ON bmt_db.teller_cash_movements
FOR EACH ROW
EXECUTE FUNCTION bmt_db.prevent_append_only_mutation();

CREATE TRIGGER trg_audit_logs_append_only
BEFORE UPDATE OR DELETE ON bmt_db.audit_logs
FOR EACH ROW
EXECUTE FUNCTION bmt_db.prevent_append_only_mutation();


-- ============================================================
-- 14. UPDATED_AT TRIGGERS
-- ============================================================

CREATE TRIGGER trg_teller_cash_sessions_updated_at
BEFORE UPDATE ON bmt_db.teller_cash_sessions
FOR EACH ROW
EXECUTE FUNCTION bmt_db.set_updated_at();

CREATE TRIGGER trg_approval_rules_updated_at
BEFORE UPDATE ON bmt_db.approval_rules
FOR EACH ROW
EXECUTE FUNCTION bmt_db.set_updated_at();


-- ============================================================
-- 15. SECURITY BASELINE
-- ============================================================

REVOKE ALL ON ALL TABLES IN SCHEMA bmt_db FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA bmt_db FROM PUBLIC;


COMMIT;
