-- ============================================================
-- BMT CORE BANKING SYSTEM
-- Migration : 007_bmt_engine.sql
-- Purpose   : Core transaction safety, immutability,
--             sequence generation, journal posting,
--             teller validation and reversal
-- Version   : 1.0.0
-- Requires  : 001 - 006
-- ============================================================

BEGIN;


-- ============================================================
-- 1. HELPER: CURRENT ACTOR
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.current_actor_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
    SELECT auth.uid();
$$;


-- ============================================================
-- 2. HELPER: REQUIRE ACTIVE USER
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.require_active_user(
    p_user_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
    v_active BOOLEAN;
BEGIN
    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'Authenticated user is required';
    END IF;

    SELECT up.is_active
      INTO v_active
      FROM bmt_db.user_profiles up
     WHERE up.id = p_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'User profile % does not exist',
            p_user_id;
    END IF;

    IF v_active IS NOT TRUE THEN
        RAISE EXCEPTION
            'User % is inactive',
            p_user_id;
    END IF;
END;
$$;


-- ============================================================
-- 3. HELPER: PERIOD KEY
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.sequence_period_key(
    p_reset_policy bmt_db.sequence_reset_policy,
    p_business_date DATE
)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
    IF p_business_date IS NULL THEN
        RAISE EXCEPTION 'Business date is required';
    END IF;

    CASE p_reset_policy
        WHEN 'NEVER' THEN
            RETURN '';

        WHEN 'YEARLY' THEN
            RETURN to_char(p_business_date, 'YYYY');

        WHEN 'MONTHLY' THEN
            RETURN to_char(p_business_date, 'YYYYMM');

        WHEN 'DAILY' THEN
            RETURN to_char(p_business_date, 'YYYYMMDD');

        ELSE
            RAISE EXCEPTION
                'Unsupported reset policy %',
                p_reset_policy;
    END CASE;
END;
$$;


-- ============================================================
-- 4. ATOMIC SEQUENCE GENERATOR
-- ============================================================
-- PostgreSQL INSERT ... ON CONFLICT DO UPDATE gives us an
-- atomic increment. Never SELECT MAX()+1.

CREATE OR REPLACE FUNCTION bmt_db.next_sequence(
    p_branch_id UUID,
    p_sequence_type bmt_db.sequence_type,
    p_product_code TEXT DEFAULT '',
    p_loan_code TEXT DEFAULT '',
    p_business_date DATE DEFAULT CURRENT_DATE,
    p_reset_policy bmt_db.sequence_reset_policy DEFAULT 'NEVER',
    p_padding INTEGER DEFAULT 6
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_period_key TEXT;
    v_next       BIGINT;
BEGIN
    IF p_branch_id IS NULL THEN
        RAISE EXCEPTION 'Branch is required';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM bmt_db.branches b
        WHERE b.id = p_branch_id
          AND b.is_active = TRUE
    ) THEN
        RAISE EXCEPTION
            'Branch % does not exist or is inactive',
            p_branch_id;
    END IF;

    IF p_padding < 1 OR p_padding > 12 THEN
        RAISE EXCEPTION
            'Sequence padding must be between 1 and 12';
    END IF;

    v_period_key :=
        bmt_db.sequence_period_key(
            p_reset_policy,
            p_business_date
        );

    INSERT INTO bmt_db.number_sequences (
        branch_id,
        sequence_type,
        product_code,
        loan_code,
        period_key,
        current_value,
        padding,
        reset_policy,
        updated_at
    )
    VALUES (
        p_branch_id,
        p_sequence_type,
        COALESCE(p_product_code, ''),
        COALESCE(p_loan_code, ''),
        v_period_key,
        1,
        p_padding,
        p_reset_policy,
        now()
    )
    ON CONFLICT (
        branch_id,
        sequence_type,
        product_code,
        loan_code,
        period_key
    )
    DO UPDATE
       SET current_value =
               bmt_db.number_sequences.current_value + 1,
           updated_at = now()
    RETURNING current_value
         INTO v_next;

    RETURN lpad(v_next::TEXT, p_padding, '0');
END;
$$;


-- ============================================================
-- 5. FIND OPEN FISCAL PERIOD
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.require_open_fiscal_period(
    p_business_date DATE
)
RETURNS UUID
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
    v_period_id UUID;
    v_status    bmt_db.fiscal_period_status;
    v_count     INTEGER;
BEGIN
    IF p_business_date IS NULL THEN
        RAISE EXCEPTION 'Business date is required';
    END IF;

    SELECT
        count(*),
        min(fp.id::text)::uuid,
        min(fp.status::text)::bmt_db.fiscal_period_status
    INTO
        v_count,
        v_period_id,
        v_status
    FROM bmt_db.fiscal_periods fp
    WHERE p_business_date
          BETWEEN fp.start_date AND fp.end_date;

    IF v_count = 0 THEN
        RAISE EXCEPTION
            'No fiscal period exists for date %',
            p_business_date;
    END IF;

    IF v_count > 1 THEN
        RAISE EXCEPTION
            'Multiple fiscal periods overlap date %',
            p_business_date;
    END IF;

    IF v_status <> 'OPEN' THEN
        RAISE EXCEPTION
            'Fiscal period for date % is %, posting is not allowed',
            p_business_date,
            v_status;
    END IF;

    RETURN v_period_id;
END;
$$;


-- ============================================================
-- 6. PREVENT OVERLAPPING FISCAL PERIODS
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.prevent_fiscal_period_overlap()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM bmt_db.fiscal_periods fp
        WHERE fp.id <> NEW.id
          AND daterange(
                fp.start_date,
                fp.end_date,
                '[]'
              )
              &&
              daterange(
                NEW.start_date,
                NEW.end_date,
                '[]'
              )
    ) THEN
        RAISE EXCEPTION
            'Fiscal period % - % overlaps an existing fiscal period',
            NEW.start_date,
            NEW.end_date;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_fiscal_period_no_overlap
BEFORE INSERT OR UPDATE OF start_date, end_date
ON bmt_db.fiscal_periods
FOR EACH ROW
EXECUTE FUNCTION bmt_db.prevent_fiscal_period_overlap();


-- ============================================================
-- 7. REQUIRE OPEN TELLER SESSION
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.require_open_teller_session(
    p_session_id UUID,
    p_teller_user_id UUID,
    p_branch_id UUID,
    p_business_date DATE
)
RETURNS VOID
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
    v_session bmt_db.teller_cash_sessions%ROWTYPE;
BEGIN
    IF p_session_id IS NULL THEN
        RAISE EXCEPTION
            'Open teller cash session is required';
    END IF;

    SELECT *
      INTO v_session
      FROM bmt_db.teller_cash_sessions s
     WHERE s.id = p_session_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Teller cash session % does not exist',
            p_session_id;
    END IF;

    IF v_session.status <> 'OPEN' THEN
        RAISE EXCEPTION
            'Teller cash session % is not OPEN',
            p_session_id;
    END IF;

    IF v_session.teller_user_id <> p_teller_user_id THEN
        RAISE EXCEPTION
            'Teller cash session does not belong to user %',
            p_teller_user_id;
    END IF;

    IF v_session.branch_id <> p_branch_id THEN
        RAISE EXCEPTION
            'Teller cash session branch does not match transaction branch';
    END IF;

    IF v_session.business_date <> p_business_date THEN
        RAISE EXCEPTION
            'Teller cash session business date % does not match transaction date %',
            v_session.business_date,
            p_business_date;
    END IF;
END;
$$;


-- ============================================================
-- 8. TRANSACTION CONSISTENCY VALIDATION
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.validate_transaction_consistency()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
    v_customer UUID;
    v_branch   UUID;
BEGIN
    IF NEW.financial_account_id IS NOT NULL THEN

        SELECT
            fa.customer_id,
            fa.branch_id
        INTO
            v_customer,
            v_branch
        FROM bmt_db.financial_accounts fa
        WHERE fa.id = NEW.financial_account_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Financial account % does not exist',
                NEW.financial_account_id;
        END IF;

        IF NEW.customer_id IS NOT NULL
           AND NEW.customer_id <> v_customer THEN
            RAISE EXCEPTION
                'Transaction customer does not own financial account';
        END IF;

        IF NEW.branch_id <> v_branch THEN
            RAISE EXCEPTION
                'Transaction branch does not match financial account branch';
        END IF;

    END IF;

    IF NEW.channel = 'TELLER'
       AND NEW.status IN (
           'APPROVED',
           'POSTED',
           'REVERSED'
       ) THEN

        IF NEW.created_by IS NULL THEN
            RAISE EXCEPTION
                'Teller transaction requires created_by';
        END IF;

        PERFORM bmt_db.require_open_teller_session(
            NEW.teller_session_id,
            NEW.created_by,
            NEW.branch_id,
            NEW.transaction_date
        );

    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_transaction_consistency
BEFORE INSERT OR UPDATE
ON bmt_db.transactions
FOR EACH ROW
EXECUTE FUNCTION bmt_db.validate_transaction_consistency();


-- ============================================================
-- 9. MAKER-CHECKER TRANSACTION GUARD
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.validate_transaction_maker_checker()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
    IF NEW.approved_by IS NOT NULL
       AND NEW.created_by IS NOT NULL
       AND NEW.approved_by = NEW.created_by THEN

        IF EXISTS (
            SELECT 1
            FROM bmt_db.approval_rules ar
            WHERE ar.transaction_type = NEW.transaction_type
              AND ar.is_active = TRUE
              AND ar.maker_checker_required = TRUE
              AND (
                    ar.branch_id IS NULL
                    OR ar.branch_id = NEW.branch_id
                  )
              AND NEW.amount >= ar.minimum_amount
              AND (
                    ar.maximum_amount IS NULL
                    OR NEW.amount <= ar.maximum_amount
                  )
              AND NEW.transaction_date >= ar.effective_from
              AND (
                    ar.effective_until IS NULL
                    OR NEW.transaction_date <= ar.effective_until
                  )
        ) THEN
            RAISE EXCEPTION
                'Maker-checker violation: transaction creator cannot approve their own transaction';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_transaction_maker_checker
BEFORE INSERT OR UPDATE
ON bmt_db.transactions
FOR EACH ROW
EXECUTE FUNCTION bmt_db.validate_transaction_maker_checker();


-- ============================================================
-- 10. POSTED TRANSACTION IMMUTABILITY
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.protect_posted_transaction()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        IF OLD.status IN ('POSTED', 'REVERSED') THEN
            RAISE EXCEPTION
                'POSTED/REVERSED transaction % cannot be deleted',
                OLD.transaction_number;
        END IF;

        RETURN OLD;
    END IF;

    IF OLD.status IN ('POSTED', 'REVERSED') THEN

        -- The only allowed mutation is POSTED -> REVERSED.
        -- No financial/business fields may change.

        IF OLD.status = 'POSTED'
           AND NEW.status = 'REVERSED'
           AND NEW.id = OLD.id
           AND NEW.transaction_number = OLD.transaction_number
           AND NEW.branch_id = OLD.branch_id
           AND NEW.transaction_type = OLD.transaction_type
           AND NEW.customer_id IS NOT DISTINCT FROM OLD.customer_id
           AND NEW.financial_account_id IS NOT DISTINCT FROM OLD.financial_account_id
           AND NEW.amount = OLD.amount
           AND NEW.currency = OLD.currency
           AND NEW.transaction_date = OLD.transaction_date
           AND NEW.value_date = OLD.value_date
           AND NEW.channel = OLD.channel
           AND NEW.teller_session_id IS NOT DISTINCT FROM OLD.teller_session_id
           AND NEW.description IS NOT DISTINCT FROM OLD.description
           AND NEW.reference_number IS NOT DISTINCT FROM OLD.reference_number
           AND NEW.created_by IS NOT DISTINCT FROM OLD.created_by
           AND NEW.created_at = OLD.created_at
           AND NEW.approved_by IS NOT DISTINCT FROM OLD.approved_by
           AND NEW.approved_at IS NOT DISTINCT FROM OLD.approved_at
           AND NEW.posted_by IS NOT DISTINCT FROM OLD.posted_by
           AND NEW.posted_at IS NOT DISTINCT FROM OLD.posted_at
           AND NEW.reversed_transaction_id IS NOT DISTINCT FROM OLD.reversed_transaction_id
        THEN
            RETURN NEW;
        END IF;

        RAISE EXCEPTION
            'POSTED/REVERSED transaction % is immutable; use reversal',
            OLD.transaction_number;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_transactions_immutable
BEFORE UPDATE OR DELETE
ON bmt_db.transactions
FOR EACH ROW
EXECUTE FUNCTION bmt_db.protect_posted_transaction();


-- ============================================================
-- 11. POSTED JOURNAL IMMUTABILITY
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.protect_posted_journal()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        IF OLD.status IN ('POSTED', 'REVERSED') THEN
            RAISE EXCEPTION
                'POSTED/REVERSED journal % cannot be deleted',
                OLD.journal_number;
        END IF;

        RETURN OLD;
    END IF;

    IF OLD.status IN ('POSTED', 'REVERSED') THEN

        IF OLD.status = 'POSTED'
           AND NEW.status = 'REVERSED'
           AND NEW.id = OLD.id
           AND NEW.journal_number = OLD.journal_number
           AND NEW.transaction_id = OLD.transaction_id
           AND NEW.branch_id = OLD.branch_id
           AND NEW.fiscal_period_id = OLD.fiscal_period_id
           AND NEW.journal_date = OLD.journal_date
           AND NEW.description = OLD.description
           AND NEW.created_by IS NOT DISTINCT FROM OLD.created_by
           AND NEW.created_at = OLD.created_at
           AND NEW.posted_by IS NOT DISTINCT FROM OLD.posted_by
           AND NEW.posted_at IS NOT DISTINCT FROM OLD.posted_at
           AND NEW.reversal_journal_id IS NOT DISTINCT FROM OLD.reversal_journal_id
        THEN
            RETURN NEW;
        END IF;

        RAISE EXCEPTION
            'POSTED/REVERSED journal % is immutable; use reversal',
            OLD.journal_number;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_journal_entries_immutable
BEFORE UPDATE OR DELETE
ON bmt_db.journal_entries
FOR EACH ROW
EXECUTE FUNCTION bmt_db.protect_posted_journal();


-- ============================================================
-- 12. PROTECT LINES OF POSTED JOURNAL
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.protect_posted_journal_lines()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
    v_journal_id UUID;
    v_status     bmt_db.journal_status;
BEGIN
    v_journal_id :=
        CASE
            WHEN TG_OP = 'DELETE'
                THEN OLD.journal_entry_id
            ELSE NEW.journal_entry_id
        END;

    SELECT je.status
      INTO v_status
      FROM bmt_db.journal_entries je
     WHERE je.id = v_journal_id;

    IF v_status IN ('POSTED', 'REVERSED') THEN
        RAISE EXCEPTION
            'Lines of POSTED/REVERSED journal cannot be modified';
    END IF;

    RETURN CASE
        WHEN TG_OP = 'DELETE' THEN OLD
        ELSE NEW
    END;
END;
$$;

CREATE TRIGGER trg_journal_lines_immutable
BEFORE INSERT OR UPDATE OR DELETE
ON bmt_db.journal_lines
FOR EACH ROW
EXECUTE FUNCTION bmt_db.protect_posted_journal_lines();


-- ============================================================
-- 13. POST JOURNAL
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.post_journal(
    p_journal_id UUID,
    p_posted_by UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_journal      bmt_db.journal_entries%ROWTYPE;
    v_period_id    UUID;

    v_total_debit  NUMERIC(19,2);
    v_total_credit NUMERIC(19,2);

    v_line_count   INTEGER;
BEGIN
    PERFORM bmt_db.require_active_user(p_posted_by);

    SELECT *
      INTO v_journal
      FROM bmt_db.journal_entries je
     WHERE je.id = p_journal_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Journal % does not exist',
            p_journal_id;
    END IF;

    IF v_journal.status <> 'DRAFT' THEN
        RAISE EXCEPTION
            'Only DRAFT journal can be posted. Current status: %',
            v_journal.status;
    END IF;

    v_period_id :=
        bmt_db.require_open_fiscal_period(
            v_journal.journal_date
        );

    IF v_journal.fiscal_period_id <> v_period_id THEN
        RAISE EXCEPTION
            'Journal fiscal period does not match journal date';
    END IF;

    SELECT
        count(*),
        COALESCE(sum(jl.debit), 0),
        COALESCE(sum(jl.credit), 0)
    INTO
        v_line_count,
        v_total_debit,
        v_total_credit
    FROM bmt_db.journal_lines jl
    WHERE jl.journal_entry_id = p_journal_id;

    IF v_line_count < 2 THEN
        RAISE EXCEPTION
            'Journal requires at least two lines';
    END IF;

    IF v_total_debit <= 0
       OR v_total_credit <= 0 THEN
        RAISE EXCEPTION
            'Journal debit and credit totals must be greater than zero';
    END IF;

    IF v_total_debit <> v_total_credit THEN
        RAISE EXCEPTION
            'Journal is not balanced. Debit %, Credit %',
            v_total_debit,
            v_total_credit;
    END IF;

    UPDATE bmt_db.journal_entries
       SET status = 'POSTED',
           posted_by = p_posted_by,
           posted_at = now()
     WHERE id = p_journal_id;
END;
$$;


-- ============================================================
-- 14. VALIDATE TRANSACTION BEFORE POSTING
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.validate_transaction_for_posting(
    p_transaction_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
    v_tx bmt_db.transactions%ROWTYPE;
    v_account_status bmt_db.account_status;
BEGIN
    SELECT *
      INTO v_tx
      FROM bmt_db.transactions t
     WHERE t.id = p_transaction_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Transaction % does not exist',
            p_transaction_id;
    END IF;

    IF v_tx.status NOT IN ('DRAFT', 'APPROVED') THEN
        RAISE EXCEPTION
            'Transaction status % cannot be posted',
            v_tx.status;
    END IF;

    PERFORM bmt_db.require_open_fiscal_period(
        v_tx.transaction_date
    );

    IF v_tx.financial_account_id IS NOT NULL THEN

        SELECT fa.status
          INTO v_account_status
          FROM bmt_db.financial_accounts fa
         WHERE fa.id = v_tx.financial_account_id;

        IF v_account_status IN (
            'BLOCKED',
            'CLOSED',
            'WRITTEN_OFF'
        ) THEN
            RAISE EXCEPTION
                'Financial account status % does not allow transaction posting',
                v_account_status;
        END IF;
    END IF;

    IF v_tx.channel = 'TELLER' THEN
        PERFORM bmt_db.require_open_teller_session(
            v_tx.teller_session_id,
            v_tx.created_by,
            v_tx.branch_id,
            v_tx.transaction_date
        );
    END IF;
END;
$$;


-- ============================================================
-- 15. MARK TRANSACTION POSTED
-- ============================================================
-- Used by business posting functions after ledger and journal
-- creation has completed successfully.

CREATE OR REPLACE FUNCTION bmt_db.mark_transaction_posted(
    p_transaction_id UUID,
    p_posted_by UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_status bmt_db.transaction_status;
BEGIN
    PERFORM bmt_db.require_active_user(p_posted_by);

    PERFORM bmt_db.validate_transaction_for_posting(
        p_transaction_id
    );

    SELECT t.status
      INTO v_status
      FROM bmt_db.transactions t
     WHERE t.id = p_transaction_id
     FOR UPDATE;

    UPDATE bmt_db.transactions
       SET status = 'POSTED',
           posted_by = p_posted_by,
           posted_at = now()
     WHERE id = p_transaction_id;
END;
$$;


-- ============================================================
-- 16. REVERSAL FOUNDATION
-- ============================================================
-- Reversal creates a NEW transaction and a NEW journal.
-- Original financial rows are never deleted.

CREATE OR REPLACE FUNCTION bmt_db.reverse_transaction(
    p_original_transaction_id UUID,
    p_reversed_by UUID,
    p_reason TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_original          bmt_db.transactions%ROWTYPE;
    v_original_journal  bmt_db.journal_entries%ROWTYPE;

    v_new_transaction_id UUID;
    v_new_journal_id     UUID;

    v_tx_seq             TEXT;
    v_jv_seq             TEXT;

    v_branch_code        TEXT;
    v_period_id          UUID;

    v_existing_reversal  UUID;
BEGIN
    PERFORM bmt_db.require_active_user(p_reversed_by);

    IF NULLIF(btrim(p_reason), '') IS NULL THEN
        RAISE EXCEPTION
            'Reversal reason is required';
    END IF;

    SELECT *
      INTO v_original
      FROM bmt_db.transactions t
     WHERE t.id = p_original_transaction_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Original transaction % does not exist',
            p_original_transaction_id;
    END IF;

    IF v_original.status <> 'POSTED' THEN
        RAISE EXCEPTION
            'Only POSTED transactions can be reversed';
    END IF;

    SELECT t.id
      INTO v_existing_reversal
      FROM bmt_db.transactions t
     WHERE t.reversed_transaction_id =
           p_original_transaction_id
     LIMIT 1;

    IF v_existing_reversal IS NOT NULL THEN
        RAISE EXCEPTION
            'Transaction has already been reversed';
    END IF;

    SELECT *
      INTO v_original_journal
      FROM bmt_db.journal_entries je
     WHERE je.transaction_id =
           p_original_transaction_id
       AND je.status = 'POSTED';

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'POSTED journal for original transaction does not exist';
    END IF;

    v_period_id :=
        bmt_db.require_open_fiscal_period(CURRENT_DATE);

    SELECT b.code
      INTO v_branch_code
      FROM bmt_db.branches b
     WHERE b.id = v_original.branch_id;

    v_tx_seq := bmt_db.next_sequence(
        v_original.branch_id,
        'REVERSAL',
        '',
        '',
        CURRENT_DATE,
        'DAILY',
        6
    );

    v_jv_seq := bmt_db.next_sequence(
        v_original.branch_id,
        'JOURNAL',
        '',
        '',
        CURRENT_DATE,
        'DAILY',
        6
    );

    INSERT INTO bmt_db.transactions (
        transaction_number,
        branch_id,
        transaction_type,
        customer_id,
        financial_account_id,
        amount,
        currency,
        transaction_date,
        value_date,
        status,
        channel,
        description,
        reference_number,
        created_by,
        created_at,
        approved_by,
        approved_at,
        teller_session_id,
        reversed_transaction_id
    )
    VALUES (
        'RV-' || v_branch_code || '-' ||
        to_char(CURRENT_DATE, 'YYYYMMDD') || '-' ||
        v_tx_seq,

        v_original.branch_id,
        'REVERSAL',
        v_original.customer_id,
        v_original.financial_account_id,
        v_original.amount,
        v_original.currency,
        CURRENT_DATE,
        CURRENT_DATE,
        'APPROVED',
        'BACKOFFICE',
        'Reversal: ' || p_reason,
        v_original.transaction_number,
        p_reversed_by,
        now(),
        p_reversed_by,
        now(),
        NULL,
        p_original_transaction_id
    )
    RETURNING id INTO v_new_transaction_id;


    INSERT INTO bmt_db.journal_entries (
        journal_number,
        transaction_id,
        branch_id,
        fiscal_period_id,
        journal_date,
        description,
        status,
        created_by
    )
    VALUES (
        'JV-' || v_branch_code || '-' ||
        to_char(CURRENT_DATE, 'YYYYMMDD') || '-' ||
        v_jv_seq,

        v_new_transaction_id,
        v_original.branch_id,
        v_period_id,
        CURRENT_DATE,
        'Reversal of ' ||
            v_original_journal.journal_number ||
            ': ' || p_reason,
        'DRAFT',
        p_reversed_by
    )
    RETURNING id INTO v_new_journal_id;


    -- Reverse every accounting line.
    INSERT INTO bmt_db.journal_lines (
        journal_entry_id,
        line_no,
        coa_id,
        customer_id,
        financial_account_id,
        debit,
        credit,
        description
    )
    SELECT
        v_new_journal_id,
        jl.line_no,
        jl.coa_id,
        jl.customer_id,
        jl.financial_account_id,
        jl.credit,
        jl.debit,
        'Reversal: ' ||
        COALESCE(jl.description, '')
    FROM bmt_db.journal_lines jl
    WHERE jl.journal_entry_id =
          v_original_journal.id
    ORDER BY jl.line_no;


    PERFORM bmt_db.post_journal(
        v_new_journal_id,
        p_reversed_by
    );

    PERFORM bmt_db.mark_transaction_posted(
        v_new_transaction_id,
        p_reversed_by
    );


    UPDATE bmt_db.journal_entries
       SET status = 'REVERSED'
     WHERE id = v_original_journal.id;


    UPDATE bmt_db.transactions
       SET status = 'REVERSED'
     WHERE id = p_original_transaction_id;


    INSERT INTO bmt_db.audit_logs (
        user_id,
        branch_id,
        action,
        entity_type,
        entity_id,
        transaction_id,
        reason,
        metadata
    )
    VALUES (
        p_reversed_by,
        v_original.branch_id,
        'TRANSACTION_REVERSED',
        'TRANSACTION',
        p_original_transaction_id,
        v_new_transaction_id,
        p_reason,
        jsonb_build_object(
            'original_transaction_id',
                p_original_transaction_id,
            'reversal_transaction_id',
                v_new_transaction_id,
            'original_journal_id',
                v_original_journal.id,
            'reversal_journal_id',
                v_new_journal_id
        )
    );

    RETURN v_new_transaction_id;
END;
$$;


-- ============================================================
-- 17. PREVENT DIRECT POSTED JOURNAL CREATION
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.prevent_direct_posted_journal()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
    IF TG_OP = 'INSERT'
       AND NEW.status <> 'DRAFT' THEN
        RAISE EXCEPTION
            'Journal must be created as DRAFT and posted through posting engine';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_journal_require_draft
BEFORE INSERT
ON bmt_db.journal_entries
FOR EACH ROW
EXECUTE FUNCTION bmt_db.prevent_direct_posted_journal();


-- ============================================================
-- 18. PREVENT DIRECT POSTED TRANSACTION CREATION
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.prevent_direct_posted_transaction()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
    IF TG_OP = 'INSERT'
       AND NEW.status IN ('POSTED', 'REVERSED') THEN
        RAISE EXCEPTION
            'Transaction cannot be inserted directly as POSTED/REVERSED';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_transaction_no_direct_post
BEFORE INSERT
ON bmt_db.transactions
FOR EACH ROW
EXECUTE FUNCTION bmt_db.prevent_direct_posted_transaction();


-- ============================================================
-- 19. INDEX FOR POSTING / REVERSAL LOOKUPS
-- ============================================================

CREATE INDEX idx_transactions_reversed_transaction
    ON bmt_db.transactions(reversed_transaction_id)
    WHERE reversed_transaction_id IS NOT NULL;

CREATE INDEX idx_journal_entries_reversal
    ON bmt_db.journal_entries(reversal_journal_id)
    WHERE reversal_journal_id IS NOT NULL;


-- ============================================================
-- 20. SECURITY
-- ============================================================
-- RLS and controlled EXECUTE grants are deliberately handled
-- in Migration 008. Keep these functions private for now.

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA bmt_db FROM PUBLIC;


COMMIT;
