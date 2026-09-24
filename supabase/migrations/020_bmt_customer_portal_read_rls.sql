BEGIN;

-- ============================================================
-- 020 - CUSTOMER PORTAL READ API
-- RPC-ONLY SECURITY BOUNDARY
--
-- Principles:
--   1. Existing staff RLS/helpers from migrations 001-019
--      remain unchanged.
--   2. No customer-own SELECT policies are added to base tables.
--   3. No portal views are created.
--   4. Portal reads are exposed only through SECURITY DEFINER
--      functions.
--   5. Every function derives ownership exclusively from
--      auth.uid().
--   6. Return contracts expose only portal-safe columns.
--   7. PUBLIC and anon cannot execute portal RPCs.
-- ============================================================


-- ============================================================
-- 01. CUSTOMER PROFILE
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.portal_get_profile()
RETURNS TABLE (
    id UUID,
    cif_number VARCHAR,
    full_name VARCHAR,
    birth_place VARCHAR,
    birth_date DATE,
    gender TEXT,
    marital_status VARCHAR,
    occupation VARCHAR,
    phone VARCHAR,
    email VARCHAR,
    status TEXT,
    registered_at TIMESTAMPTZ,
    branch_code VARCHAR,
    branch_name VARCHAR
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
    SELECT
        c.id,
        c.cif_number,
        c.full_name,
        c.birth_place,
        c.birth_date,
        c.gender::TEXT,
        c.marital_status,
        c.occupation,
        c.phone,
        c.email,
        c.status::TEXT,
        c.registered_at,
        b.code,
        b.name
    FROM bmt_db.customers c
    JOIN bmt_db.branches b
      ON b.id = c.branch_id
    WHERE auth.uid() IS NOT NULL
      AND c.auth_user_id = auth.uid();
$function$;


-- ============================================================
-- 02. FINANCIAL ACCOUNTS
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.portal_get_financial_accounts()
RETURNS TABLE (
    id UUID,
    account_number VARCHAR,
    account_type TEXT,
    status TEXT,
    opened_at TIMESTAMPTZ,
    closed_at TIMESTAMPTZ,
    product_code VARCHAR,
    product_name VARCHAR,
    product_category TEXT,
    currency CHAR(3),
    branch_code VARCHAR,
    branch_name VARCHAR
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
    SELECT
        fa.id,
        fa.account_number,
        fa.account_type::TEXT,
        fa.status::TEXT,
        fa.opened_at,
        fa.closed_at,
        p.code,
        p.name,
        p.category::TEXT,
        p.currency,
        b.code,
        b.name
    FROM bmt_db.financial_accounts fa
    JOIN bmt_db.customers c
      ON c.id = fa.customer_id
    JOIN bmt_db.products p
      ON p.id = fa.product_id
    JOIN bmt_db.branches b
      ON b.id = fa.branch_id
    WHERE auth.uid() IS NOT NULL
      AND c.auth_user_id = auth.uid()
    ORDER BY fa.created_at DESC, fa.account_number;
$function$;


-- ============================================================
-- 03. SAVINGS ACCOUNTS
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.portal_get_savings_accounts()
RETURNS TABLE (
    financial_account_id UUID,
    account_number VARCHAR,
    status TEXT,
    product_code VARCHAR,
    product_name VARCHAR,
    current_balance NUMERIC,
    available_balance NUMERIC,
    blocked_balance NUMERIC,
    last_transaction_at TIMESTAMPTZ,
    dormant_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
    SELECT
        sa.financial_account_id,
        fa.account_number,
        fa.status::TEXT,
        p.code,
        p.name,
        sa.current_balance,
        sa.available_balance,
        sa.blocked_balance,
        sa.last_transaction_at,
        sa.dormant_at
    FROM bmt_db.savings_accounts sa
    JOIN bmt_db.financial_accounts fa
      ON fa.id = sa.financial_account_id
    JOIN bmt_db.customers c
      ON c.id = fa.customer_id
    JOIN bmt_db.products p
      ON p.id = fa.product_id
    WHERE auth.uid() IS NOT NULL
      AND c.auth_user_id = auth.uid()
    ORDER BY fa.created_at DESC, fa.account_number;
$function$;


-- ============================================================
-- 04. DEPOSIT ACCOUNTS
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.portal_get_deposit_accounts()
RETURNS TABLE (
    financial_account_id UUID,
    account_number VARCHAR,
    status TEXT,
    product_code VARCHAR,
    product_name VARCHAR,
    settlement_savings_account_id UUID,
    principal_amount NUMERIC,
    start_date DATE,
    maturity_date DATE,
    profit_rate NUMERIC,
    aro_type TEXT,
    deposit_status TEXT,
    terminated_at TIMESTAMPTZ,
    termination_reason TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
    SELECT
        da.financial_account_id,
        fa.account_number,
        fa.status::TEXT,
        p.code,
        p.name,
        da.settlement_savings_account_id,
        da.principal_amount,
        da.start_date,
        da.maturity_date,
        da.profit_rate,
        da.aro_type::TEXT,
        da.deposit_status::TEXT,
        da.terminated_at,
        da.termination_reason
    FROM bmt_db.deposit_accounts da
    JOIN bmt_db.financial_accounts fa
      ON fa.id = da.financial_account_id
    JOIN bmt_db.customers c
      ON c.id = fa.customer_id
    JOIN bmt_db.products p
      ON p.id = fa.product_id
    WHERE auth.uid() IS NOT NULL
      AND c.auth_user_id = auth.uid()
    ORDER BY da.start_date DESC, fa.account_number;
$function$;


-- ============================================================
-- 05. LOAN ACCOUNTS
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.portal_get_loan_accounts()
RETURNS TABLE (
    financial_account_id UUID,
    account_number VARCHAR,
    status TEXT,
    product_code VARCHAR,
    product_name VARCHAR,
    application_id UUID,
    savings_account_id UUID,
    principal_amount NUMERIC,
    tenor_months INTEGER,
    rate NUMERIC,
    margin_amount NUMERIC,
    disbursement_amount NUMERIC,
    outstanding_principal NUMERIC,
    outstanding_margin NUMERIC,
    outstanding_penalty NUMERIC,
    disbursement_date DATE,
    maturity_date DATE,
    loan_status TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
    SELECT
        la.financial_account_id,
        fa.account_number,
        fa.status::TEXT,
        p.code,
        p.name,
        la.application_id,
        la.savings_account_id,
        la.principal_amount,
        la.tenor_months,
        la.rate,
        la.margin_amount,
        la.disbursement_amount,
        la.outstanding_principal,
        la.outstanding_margin,
        la.outstanding_penalty,
        la.disbursement_date,
        la.maturity_date,
        la.loan_status::TEXT
    FROM bmt_db.loan_accounts la
    JOIN bmt_db.financial_accounts fa
      ON fa.id = la.financial_account_id
    JOIN bmt_db.customers c
      ON c.id = fa.customer_id
    JOIN bmt_db.products p
      ON p.id = fa.product_id
    WHERE auth.uid() IS NOT NULL
      AND c.auth_user_id = auth.uid()
    ORDER BY fa.created_at DESC, fa.account_number;
$function$;


-- ============================================================
-- 06. LOAN APPLICATIONS
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.portal_get_loan_applications()
RETURNS TABLE (
    id UUID,
    application_number VARCHAR,
    savings_account_id UUID,
    loan_product_id UUID,
    product_code VARCHAR,
    product_name VARCHAR,
    requested_amount NUMERIC,
    requested_tenor_months INTEGER,
    purpose TEXT,
    status TEXT,
    submitted_at TIMESTAMPTZ,
    decided_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
    SELECT
        la.id,
        la.application_number,
        la.savings_account_id,
        la.loan_product_id,
        p.code,
        p.name,
        la.requested_amount,
        la.requested_tenor_months,
        la.purpose,
        la.status::TEXT,
        la.submitted_at,
        la.decided_at,
        la.created_at
    FROM bmt_db.loan_applications la
    JOIN bmt_db.customers c
      ON c.id = la.customer_id
    JOIN bmt_db.products p
      ON p.id = la.loan_product_id
    WHERE auth.uid() IS NOT NULL
      AND c.auth_user_id = auth.uid()
    ORDER BY la.created_at DESC, la.application_number;
$function$;


-- ============================================================
-- 07. LOAN SCHEDULES
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.portal_get_loan_schedules()
RETURNS TABLE (
    id UUID,
    loan_account_id UUID,
    account_number VARCHAR,
    installment_no INTEGER,
    due_date DATE,
    opening_principal NUMERIC,
    principal_due NUMERIC,
    margin_due NUMERIC,
    other_due NUMERIC,
    total_due NUMERIC,
    principal_paid NUMERIC,
    margin_paid NUMERIC,
    penalty_paid NUMERIC,
    other_paid NUMERIC,
    paid_at TIMESTAMPTZ,
    status TEXT,
    days_overdue INTEGER
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
    SELECT
        ls.id,
        ls.loan_account_id,
        fa.account_number,
        ls.installment_no,
        ls.due_date,
        ls.opening_principal,
        ls.principal_due,
        ls.margin_due,
        ls.other_due,
        ls.total_due,
        ls.principal_paid,
        ls.margin_paid,
        ls.penalty_paid,
        ls.other_paid,
        ls.paid_at,
        ls.status::TEXT,
        ls.days_overdue
    FROM bmt_db.loan_schedules ls
    JOIN bmt_db.loan_accounts la
      ON la.financial_account_id = ls.loan_account_id
    JOIN bmt_db.financial_accounts fa
      ON fa.id = la.financial_account_id
    JOIN bmt_db.customers c
      ON c.id = fa.customer_id
    WHERE auth.uid() IS NOT NULL
      AND c.auth_user_id = auth.uid()
    ORDER BY
        fa.account_number,
        ls.installment_no;
$function$;


-- ============================================================
-- 08. INSTALLMENT PAYMENTS
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.portal_get_installment_payments()
RETURNS TABLE (
    id UUID,
    loan_schedule_id UUID,
    loan_account_id UUID,
    account_number VARCHAR,
    installment_no INTEGER,
    principal_amount NUMERIC,
    margin_amount NUMERIC,
    penalty_amount NUMERIC,
    other_amount NUMERIC,
    paid_at TIMESTAMPTZ,
    transaction_id UUID
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
    SELECT
        ip.id,
        ip.loan_schedule_id,
        ls.loan_account_id,
        fa.account_number,
        ls.installment_no,
        ip.principal_amount,
        ip.margin_amount,
        ip.penalty_amount,
        ip.other_amount,
        ip.paid_at,
        ip.transaction_id
    FROM bmt_db.installment_payments ip
    JOIN bmt_db.loan_schedules ls
      ON ls.id = ip.loan_schedule_id
    JOIN bmt_db.loan_accounts la
      ON la.financial_account_id = ls.loan_account_id
    JOIN bmt_db.financial_accounts fa
      ON fa.id = la.financial_account_id
    JOIN bmt_db.customers c
      ON c.id = fa.customer_id
    WHERE auth.uid() IS NOT NULL
      AND c.auth_user_id = auth.uid()
    ORDER BY ip.paid_at DESC, ip.id;
$function$;


-- ============================================================
-- 09. TRANSACTIONS
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.portal_get_transactions()
RETURNS TABLE (
    id UUID,
    transaction_number VARCHAR,
    transaction_type VARCHAR,
    financial_account_id UUID,
    account_number VARCHAR,
    amount NUMERIC,
    currency CHAR(3),
    transaction_date DATE,
    value_date DATE,
    status TEXT,
    channel TEXT,
    description TEXT,
    reference_number VARCHAR,
    posted_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
    SELECT
        t.id,
        t.transaction_number,
        t.transaction_type,
        t.financial_account_id,
        fa.account_number,
        t.amount,
        t.currency,
        t.transaction_date,
        t.value_date,
        t.status::TEXT,
        t.channel::TEXT,
        t.description,
        t.reference_number,
        t.posted_at
    FROM bmt_db.transactions t
    JOIN bmt_db.customers c
      ON c.id = t.customer_id
    LEFT JOIN bmt_db.financial_accounts fa
      ON fa.id = t.financial_account_id
     AND fa.customer_id = c.id
    WHERE auth.uid() IS NOT NULL
      AND c.auth_user_id = auth.uid()
    ORDER BY
        t.transaction_date DESC,
        t.created_at DESC,
        t.transaction_number;
$function$;


-- ============================================================
-- 10. RPC ACL
-- ============================================================

REVOKE EXECUTE ON FUNCTION
    bmt_db.portal_get_profile()
FROM PUBLIC;

REVOKE EXECUTE ON FUNCTION
    bmt_db.portal_get_profile()
FROM anon;

GRANT EXECUTE ON FUNCTION
    bmt_db.portal_get_profile()
TO authenticated;


REVOKE EXECUTE ON FUNCTION
    bmt_db.portal_get_financial_accounts()
FROM PUBLIC;

REVOKE EXECUTE ON FUNCTION
    bmt_db.portal_get_financial_accounts()
FROM anon;

GRANT EXECUTE ON FUNCTION
    bmt_db.portal_get_financial_accounts()
TO authenticated;


REVOKE EXECUTE ON FUNCTION
    bmt_db.portal_get_savings_accounts()
FROM PUBLIC;

REVOKE EXECUTE ON FUNCTION
    bmt_db.portal_get_savings_accounts()
FROM anon;

GRANT EXECUTE ON FUNCTION
    bmt_db.portal_get_savings_accounts()
TO authenticated;


REVOKE EXECUTE ON FUNCTION
    bmt_db.portal_get_deposit_accounts()
FROM PUBLIC;

REVOKE EXECUTE ON FUNCTION
    bmt_db.portal_get_deposit_accounts()
FROM anon;

GRANT EXECUTE ON FUNCTION
    bmt_db.portal_get_deposit_accounts()
TO authenticated;


REVOKE EXECUTE ON FUNCTION
    bmt_db.portal_get_loan_accounts()
FROM PUBLIC;

REVOKE EXECUTE ON FUNCTION
    bmt_db.portal_get_loan_accounts()
FROM anon;

GRANT EXECUTE ON FUNCTION
    bmt_db.portal_get_loan_accounts()
TO authenticated;


REVOKE EXECUTE ON FUNCTION
    bmt_db.portal_get_loan_applications()
FROM PUBLIC;

REVOKE EXECUTE ON FUNCTION
    bmt_db.portal_get_loan_applications()
FROM anon;

GRANT EXECUTE ON FUNCTION
    bmt_db.portal_get_loan_applications()
TO authenticated;


REVOKE EXECUTE ON FUNCTION
    bmt_db.portal_get_loan_schedules()
FROM PUBLIC;

REVOKE EXECUTE ON FUNCTION
    bmt_db.portal_get_loan_schedules()
FROM anon;

GRANT EXECUTE ON FUNCTION
    bmt_db.portal_get_loan_schedules()
TO authenticated;


REVOKE EXECUTE ON FUNCTION
    bmt_db.portal_get_installment_payments()
FROM PUBLIC;

REVOKE EXECUTE ON FUNCTION
    bmt_db.portal_get_installment_payments()
FROM anon;

GRANT EXECUTE ON FUNCTION
    bmt_db.portal_get_installment_payments()
TO authenticated;


REVOKE EXECUTE ON FUNCTION
    bmt_db.portal_get_transactions()
FROM PUBLIC;

REVOKE EXECUTE ON FUNCTION
    bmt_db.portal_get_transactions()
FROM anon;

GRANT EXECUTE ON FUNCTION
    bmt_db.portal_get_transactions()
TO authenticated;


-- ============================================================
-- 11. STRUCTURAL SECURITY ASSERTIONS
-- ============================================================

DO $assert$
DECLARE
    v_count INTEGER;
BEGIN
    -- Exactly nine portal functions must exist.
    SELECT count(*)
    INTO v_count
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n
      ON n.oid = p.pronamespace
    WHERE n.nspname = 'bmt_db'
      AND p.proname IN (
          'portal_get_profile',
          'portal_get_financial_accounts',
          'portal_get_savings_accounts',
          'portal_get_deposit_accounts',
          'portal_get_loan_accounts',
          'portal_get_loan_applications',
          'portal_get_loan_schedules',
          'portal_get_installment_payments',
          'portal_get_transactions'
      );

    IF v_count <> 9 THEN
        RAISE EXCEPTION
            '020 assertion failed: portal functions %, expected 9',
            v_count;
    END IF;


    -- All portal functions must be SECURITY DEFINER,
    -- STABLE and search_path hardened.
    SELECT count(*)
    INTO v_count
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n
      ON n.oid = p.pronamespace
    WHERE n.nspname = 'bmt_db'
      AND p.proname IN (
          'portal_get_profile',
          'portal_get_financial_accounts',
          'portal_get_savings_accounts',
          'portal_get_deposit_accounts',
          'portal_get_loan_accounts',
          'portal_get_loan_applications',
          'portal_get_loan_schedules',
          'portal_get_installment_payments',
          'portal_get_transactions'
      )
      AND p.prosecdef
      AND p.provolatile = 's'
      AND p.proconfig @> ARRAY['search_path=""'];

    IF v_count <> 9 THEN
        RAISE EXCEPTION
            '020 assertion failed: hardened portal functions %, expected 9',
            v_count;
    END IF;


    -- authenticated may execute all nine.
    SELECT count(*)
    INTO v_count
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n
      ON n.oid = p.pronamespace
    WHERE n.nspname = 'bmt_db'
      AND p.proname IN (
          'portal_get_profile',
          'portal_get_financial_accounts',
          'portal_get_savings_accounts',
          'portal_get_deposit_accounts',
          'portal_get_loan_accounts',
          'portal_get_loan_applications',
          'portal_get_loan_schedules',
          'portal_get_installment_payments',
          'portal_get_transactions'
      )
      AND pg_catalog.has_function_privilege(
          'authenticated',
          p.oid,
          'EXECUTE'
      );

    IF v_count <> 9 THEN
        RAISE EXCEPTION
            '020 assertion failed: authenticated RPC ACL %, expected 9',
            v_count;
    END IF;


    -- anon may execute none.
    SELECT count(*)
    INTO v_count
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n
      ON n.oid = p.pronamespace
    WHERE n.nspname = 'bmt_db'
      AND p.proname IN (
          'portal_get_profile',
          'portal_get_financial_accounts',
          'portal_get_savings_accounts',
          'portal_get_deposit_accounts',
          'portal_get_loan_accounts',
          'portal_get_loan_applications',
          'portal_get_loan_schedules',
          'portal_get_installment_payments',
          'portal_get_transactions'
      )
      AND pg_catalog.has_function_privilege(
          'anon',
          p.oid,
          'EXECUTE'
      );

    IF v_count <> 0 THEN
        RAISE EXCEPTION
            '020 assertion failed: anon can execute % portal RPC(s)',
            v_count;
    END IF;


    -- No view-based portal API may exist.
    SELECT count(*)
    INTO v_count
    FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n
      ON n.oid = c.relnamespace
    WHERE n.nspname = 'bmt_db'
      AND c.relkind = 'v'
      AND c.relname LIKE 'portal_%';

    IF v_count <> 0 THEN
        RAISE EXCEPTION
            '020 assertion failed: portal views exist: %',
            v_count;
    END IF;


    -- No customer-own base-table policies from abandoned
    -- view architecture may exist.
    SELECT count(*)
    INTO v_count
    FROM pg_catalog.pg_policies
    WHERE schemaname = 'bmt_db'
      AND policyname IN (
          'customers_select_own',
          'financial_accounts_select_own',
          'loan_applications_select_own',
          'transactions_select_own',
          'branches_select_customer_own',
          'products_select_customer_own'
      );

    IF v_count <> 0 THEN
        RAISE EXCEPTION
            '020 assertion failed: customer raw-read policies exist: %',
            v_count;
    END IF;


    -- Existing staff helpers must retain branch-only semantics.
    IF pg_catalog.pg_get_functiondef(
        'bmt_db.current_user_can_access_customer(uuid)'::regprocedure
    ) NOT LIKE '%current_user_has_branch_access%' THEN
        RAISE EXCEPTION
            '020 assertion failed: customer access helper semantics changed';
    END IF;

    IF pg_catalog.pg_get_functiondef(
        'bmt_db.current_user_can_access_account(uuid)'::regprocedure
    ) NOT LIKE '%current_user_has_branch_access%' THEN
        RAISE EXCEPTION
            '020 assertion failed: account access helper semantics changed';
    END IF;


    RAISE NOTICE
        '020 STRUCTURAL PASS - RPC-only customer portal hardened';
END;
$assert$;


COMMIT;
