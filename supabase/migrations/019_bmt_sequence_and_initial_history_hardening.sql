BEGIN;

-- ============================================================
-- BMT MIGRATION 019
-- SEQUENCE OVERFLOW + INITIAL ONBOARDING HISTORY HARDENING
--
-- 1. next_sequence() must never return more digits than padding.
-- 2. Every newly-created onboarding application gets an
--    immutable initial history event: NULL -> DRAFT.
-- ============================================================


-- ============================================================
-- 01. HARDEN NUMBER SEQUENCE ENGINE
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.next_sequence(
    p_branch_id UUID,
    p_sequence_type bmt_db.sequence_type,
    p_product_code TEXT DEFAULT '',
    p_loan_code TEXT DEFAULT '',
    p_business_date DATE DEFAULT CURRENT_DATE,
    p_reset_policy bmt_db.sequence_reset_policy
        DEFAULT 'NEVER'::bmt_db.sequence_reset_policy,
    p_padding INTEGER DEFAULT 6
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_period_key TEXT;
    v_next       BIGINT;
    v_max_value  BIGINT;
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

    -- p_padding is restricted to <= 12, therefore this remains
    -- safely inside BIGINT.
    v_max_value :=
        pg_catalog.power(
            10::NUMERIC,
            p_padding
        )::BIGINT - 1;

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
        pg_catalog.now()
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
           updated_at = pg_catalog.now()
    RETURNING current_value
         INTO v_next;

    IF v_next > v_max_value THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '22003',
                MESSAGE = pg_catalog.format(
                    'Sequence overflow: type=%s period=%s padding=%s maximum=%s',
                    p_sequence_type::TEXT,
                    v_period_key,
                    p_padding,
                    v_max_value
                );
    END IF;

    RETURN pg_catalog.lpad(
        v_next::TEXT,
        p_padding,
        '0'
    );
END;
$function$;


-- ============================================================
-- 02. INITIAL ONBOARDING HISTORY TRIGGER FUNCTION
--
-- Runs AFTER INSERT so the application row already exists.
-- History direct-write RLS remains unchanged.
-- ============================================================

CREATE OR REPLACE FUNCTION
bmt_db.record_initial_onboarding_history()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_actor UUID;
BEGIN
    -- INSERT RLS already requires a new application to be DRAFT.
    -- Defense in depth here ensures this trigger never records an
    -- invalid initial workflow state.
    IF NEW.status <> 'DRAFT'::bmt_db.onboarding_status THEN
        RAISE EXCEPTION
            'New onboarding application must start as DRAFT';
    END IF;

    v_actor := auth.uid();

    INSERT INTO bmt_db.onboarding_status_history (
        application_id,
        from_status,
        to_status,
        changed_by,
        metadata
    )
    VALUES (
        NEW.id,
        NULL,
        'DRAFT'::bmt_db.onboarding_status,
        v_actor,
        pg_catalog.jsonb_build_object(
            'event',
            'APPLICATION_CREATED',
            'source',
            'INITIAL_INSERT'
        )
    );

    RETURN NEW;
END;
$function$;


-- Trigger function is internal only.
REVOKE ALL
ON FUNCTION bmt_db.record_initial_onboarding_history()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION bmt_db.record_initial_onboarding_history()
FROM anon;

REVOKE ALL
ON FUNCTION bmt_db.record_initial_onboarding_history()
FROM authenticated;


DROP TRIGGER IF EXISTS
trg_onboarding_initial_history
ON bmt_db.onboarding_applications;

CREATE TRIGGER trg_onboarding_initial_history
AFTER INSERT
ON bmt_db.onboarding_applications
FOR EACH ROW
EXECUTE FUNCTION bmt_db.record_initial_onboarding_history();


-- ============================================================
-- 03. STRUCTURAL ASSERTIONS
-- ============================================================

DO $assert$
DECLARE
    v_next_seq_secdef       BOOLEAN;
    v_next_seq_path         BOOLEAN;

    v_history_secdef        BOOLEAN;
    v_history_path          BOOLEAN;
    v_history_auth_exec     BOOLEAN;
    v_history_anon_exec     BOOLEAN;

    v_trigger_count         INTEGER;
BEGIN
    SELECT
        p.prosecdef,
        COALESCE(
            p.proconfig @> ARRAY['search_path=""']::TEXT[],
            FALSE
        )
    INTO
        v_next_seq_secdef,
        v_next_seq_path
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n
      ON n.oid = p.pronamespace
    WHERE n.nspname = 'bmt_db'
      AND p.proname = 'next_sequence'
      AND pg_catalog.pg_get_function_identity_arguments(p.oid)
          = 'p_branch_id uuid, p_sequence_type bmt_db.sequence_type, p_product_code text, p_loan_code text, p_business_date date, p_reset_policy bmt_db.sequence_reset_policy, p_padding integer';

    IF NOT COALESCE(v_next_seq_secdef, FALSE) THEN
        RAISE EXCEPTION
            '019 ASSERT FAILED: next_sequence not SECURITY DEFINER';
    END IF;

    IF NOT COALESCE(v_next_seq_path, FALSE) THEN
        RAISE EXCEPTION
            '019 ASSERT FAILED: next_sequence search_path unsafe';
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
        v_history_secdef,
        v_history_path,
        v_history_auth_exec,
        v_history_anon_exec
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n
      ON n.oid = p.pronamespace
    WHERE n.nspname = 'bmt_db'
      AND p.proname =
          'record_initial_onboarding_history'
      AND pg_catalog.pg_get_function_identity_arguments(p.oid)
          = '';

    IF NOT COALESCE(v_history_secdef, FALSE) THEN
        RAISE EXCEPTION
            '019 ASSERT FAILED: history trigger function not SECURITY DEFINER';
    END IF;

    IF NOT COALESCE(v_history_path, FALSE) THEN
        RAISE EXCEPTION
            '019 ASSERT FAILED: history trigger function search_path unsafe';
    END IF;

    IF COALESCE(v_history_auth_exec, FALSE) THEN
        RAISE EXCEPTION
            '019 ASSERT FAILED: authenticated can directly execute history trigger function';
    END IF;

    IF COALESCE(v_history_anon_exec, FALSE) THEN
        RAISE EXCEPTION
            '019 ASSERT FAILED: anon can directly execute history trigger function';
    END IF;


    SELECT count(*)
    INTO v_trigger_count
    FROM pg_catalog.pg_trigger t
    JOIN pg_catalog.pg_class c
      ON c.oid = t.tgrelid
    JOIN pg_catalog.pg_namespace n
      ON n.oid = c.relnamespace
    WHERE n.nspname = 'bmt_db'
      AND c.relname = 'onboarding_applications'
      AND t.tgname = 'trg_onboarding_initial_history'
      AND NOT t.tgisinternal
      AND t.tgenabled <> 'D';

    IF v_trigger_count <> 1 THEN
        RAISE EXCEPTION
            '019 ASSERT FAILED: initial history trigger count=%',
            v_trigger_count;
    END IF;

    RAISE NOTICE
        '019 STRUCTURAL PASS - sequence overflow and initial history hardened';
END;
$assert$;

COMMIT;
