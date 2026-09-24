-- ============================================================
-- Migration : 017_bmt_onboarding_child_workflow_field_hardening.sql
-- Purpose   : Protect workflow-controlled fields on onboarding
--             child tables from direct authenticated writes.
-- Depends   : 012..016
--
-- Protected:
--   onboarding_documents
--     status
--     verified_by
--     verified_at
--     verification_notes
--
--   onboarding_product_requests
--     status
--     reviewed_by
--     reviewed_at
--     review_notes
--
-- Design:
--   * Applicant/staff may continue editing business/form fields
--     when current onboarding rules allow it.
--   * Workflow/internal fields cannot be forged through direct
--     INSERT/UPDATE.
--   * Internal SECURITY DEFINER workflow functions may bypass
--     the guard only while bmt.onboarding_workflow = '1'.
--   * Trigger functions themselves are not executable by
--     PUBLIC / anon / authenticated.
-- ============================================================

BEGIN;

-- ============================================================
-- 1. DOCUMENT WORKFLOW FIELD GUARD
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.onboarding_document_workflow_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_workflow BOOLEAN :=
        COALESCE(
            pg_catalog.current_setting(
                'bmt.onboarding_workflow',
                TRUE
            ),
            ''
        ) = '1';
BEGIN
    -- Internal workflow operation.
    IF v_workflow THEN
        RETURN NEW;
    END IF;

    IF TG_OP = 'INSERT' THEN
        -- Direct creation must always start as an uploaded,
        -- unverified document.
        IF NEW.status IS DISTINCT FROM
               'UPLOADED'::bmt_db.onboarding_document_status
           OR NEW.verified_by IS NOT NULL
           OR NEW.verified_at IS NOT NULL
           OR NEW.verification_notes IS NOT NULL
        THEN
            RAISE EXCEPTION
                'Document workflow fields cannot be set directly'
                USING ERRCODE = '42501';
        END IF;

        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        -- Workflow fields are immutable through direct table writes.
        IF NEW.status IS DISTINCT FROM OLD.status
           OR NEW.verified_by IS DISTINCT FROM OLD.verified_by
           OR NEW.verified_at IS DISTINCT FROM OLD.verified_at
           OR NEW.verification_notes IS DISTINCT FROM OLD.verification_notes
        THEN
            RAISE EXCEPTION
                'Document workflow fields cannot be changed directly'
                USING ERRCODE = '42501';
        END IF;

        RETURN NEW;
    END IF;

    RETURN NEW;
END;
$function$;

REVOKE ALL
ON FUNCTION bmt_db.onboarding_document_workflow_guard()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION bmt_db.onboarding_document_workflow_guard()
FROM anon;

REVOKE ALL
ON FUNCTION bmt_db.onboarding_document_workflow_guard()
FROM authenticated;


DROP TRIGGER IF EXISTS
    trg_onboarding_document_workflow_guard
ON bmt_db.onboarding_documents;

CREATE TRIGGER trg_onboarding_document_workflow_guard
BEFORE INSERT OR UPDATE
ON bmt_db.onboarding_documents
FOR EACH ROW
EXECUTE FUNCTION bmt_db.onboarding_document_workflow_guard();


COMMENT ON FUNCTION bmt_db.onboarding_document_workflow_guard() IS
'Guards workflow-controlled document verification fields against direct client writes. Internal onboarding workflow operations may bypass only while bmt.onboarding_workflow=1.';


-- ============================================================
-- 2. PRODUCT REQUEST WORKFLOW FIELD GUARD
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.onboarding_product_workflow_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_workflow BOOLEAN :=
        COALESCE(
            pg_catalog.current_setting(
                'bmt.onboarding_workflow',
                TRUE
            ),
            ''
        ) = '1';
BEGIN
    -- Internal workflow operation.
    IF v_workflow THEN
        RETURN NEW;
    END IF;

    IF TG_OP = 'INSERT' THEN
        -- Direct product request creation must always begin
        -- in REQUESTED state without review metadata.
        IF NEW.status IS DISTINCT FROM
               'REQUESTED'::bmt_db.onboarding_product_status
           OR NEW.reviewed_by IS NOT NULL
           OR NEW.reviewed_at IS NOT NULL
           OR NEW.review_notes IS NOT NULL
        THEN
            RAISE EXCEPTION
                'Product request workflow fields cannot be set directly'
                USING ERRCODE = '42501';
        END IF;

        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        -- Workflow fields are immutable through direct table writes.
        IF NEW.status IS DISTINCT FROM OLD.status
           OR NEW.reviewed_by IS DISTINCT FROM OLD.reviewed_by
           OR NEW.reviewed_at IS DISTINCT FROM OLD.reviewed_at
           OR NEW.review_notes IS DISTINCT FROM OLD.review_notes
        THEN
            RAISE EXCEPTION
                'Product request workflow fields cannot be changed directly'
                USING ERRCODE = '42501';
        END IF;

        RETURN NEW;
    END IF;

    RETURN NEW;
END;
$function$;

REVOKE ALL
ON FUNCTION bmt_db.onboarding_product_workflow_guard()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION bmt_db.onboarding_product_workflow_guard()
FROM anon;

REVOKE ALL
ON FUNCTION bmt_db.onboarding_product_workflow_guard()
FROM authenticated;


DROP TRIGGER IF EXISTS
    trg_onboarding_product_workflow_guard
ON bmt_db.onboarding_product_requests;

CREATE TRIGGER trg_onboarding_product_workflow_guard
BEFORE INSERT OR UPDATE
ON bmt_db.onboarding_product_requests
FOR EACH ROW
EXECUTE FUNCTION bmt_db.onboarding_product_workflow_guard();


COMMENT ON FUNCTION bmt_db.onboarding_product_workflow_guard() IS
'Guards workflow-controlled product review fields against direct client writes. Internal onboarding workflow operations may bypass only while bmt.onboarding_workflow=1.';


-- ============================================================
-- 3. STRUCTURAL ASSERTIONS
-- ============================================================

DO $check$
DECLARE
    v_count INTEGER;
BEGIN
    -- Both guard functions must exist and be SECURITY DEFINER.
    SELECT count(*)
      INTO v_count
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n
      ON n.oid = p.pronamespace
    WHERE n.nspname = 'bmt_db'
      AND p.proname IN (
          'onboarding_document_workflow_guard',
          'onboarding_product_workflow_guard'
      )
      AND p.prosecdef = TRUE
      AND p.proconfig @> ARRAY['search_path=""']::TEXT[];

    IF v_count <> 2 THEN
        RAISE EXCEPTION
            '017 assertion failed: expected 2 hardened SECURITY DEFINER guard functions, found %',
            v_count;
    END IF;


    -- Guard functions must not be executable by authenticated.
    SELECT count(*)
      INTO v_count
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n
      ON n.oid = p.pronamespace
    WHERE n.nspname = 'bmt_db'
      AND p.proname IN (
          'onboarding_document_workflow_guard',
          'onboarding_product_workflow_guard'
      )
      AND pg_catalog.has_function_privilege(
          'authenticated',
          p.oid,
          'EXECUTE'
      );

    IF v_count <> 0 THEN
        RAISE EXCEPTION
            '017 assertion failed: authenticated can execute % guard function(s)',
            v_count;
    END IF;


    -- Guard functions must not be executable by anon.
    SELECT count(*)
      INTO v_count
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n
      ON n.oid = p.pronamespace
    WHERE n.nspname = 'bmt_db'
      AND p.proname IN (
          'onboarding_document_workflow_guard',
          'onboarding_product_workflow_guard'
      )
      AND pg_catalog.has_function_privilege(
          'anon',
          p.oid,
          'EXECUTE'
      );

    IF v_count <> 0 THEN
        RAISE EXCEPTION
            '017 assertion failed: anon can execute % guard function(s)',
            v_count;
    END IF;


    -- Both triggers must exist and be enabled.
    SELECT count(*)
      INTO v_count
    FROM pg_catalog.pg_trigger t
    JOIN pg_catalog.pg_class c
      ON c.oid = t.tgrelid
    JOIN pg_catalog.pg_namespace n
      ON n.oid = c.relnamespace
    WHERE n.nspname = 'bmt_db'
      AND (
          (
              c.relname = 'onboarding_documents'
              AND t.tgname =
                  'trg_onboarding_document_workflow_guard'
          )
          OR
          (
              c.relname = 'onboarding_product_requests'
              AND t.tgname =
                  'trg_onboarding_product_workflow_guard'
          )
      )
      AND NOT t.tgisinternal
      AND t.tgenabled <> 'D';

    IF v_count <> 2 THEN
        RAISE EXCEPTION
            '017 assertion failed: expected 2 enabled workflow guard triggers, found %',
            v_count;
    END IF;

    RAISE NOTICE
        '017 STRUCTURAL PASS - onboarding child workflow fields hardened';
END;
$check$;


COMMIT;
