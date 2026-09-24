-- ============================================================
-- BMT CORE BANKING SYSTEM
-- Migration : 008_bmt_rls.sql
-- Purpose   : RBAC helpers, branch authorization,
--             Row Level Security and API grants
-- Version   : 1.0.0
-- Requires  : 001 - 007
-- ============================================================

BEGIN;


-- ============================================================
-- 1. HELPER: CURRENT USER ACTIVE
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.current_user_is_active()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM bmt_db.user_profiles up
        WHERE up.id = auth.uid()
          AND up.is_active = TRUE
    );
$$;


-- ============================================================
-- 2. HELPER: CURRENT USER HAS ROLE
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.current_user_has_role(
    p_role_code TEXT,
    p_branch_id UUID DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM bmt_db.user_roles ur

        JOIN bmt_db.roles r
          ON r.id = ur.role_id

        WHERE ur.user_id = auth.uid()

          AND ur.is_active = TRUE
          AND r.is_active = TRUE

          AND r.code = p_role_code

          AND ur.valid_from <= now()

          AND (
              ur.valid_until IS NULL
              OR ur.valid_until > now()
          )

          AND (
              ur.branch_id IS NULL
              OR p_branch_id IS NULL
              OR ur.branch_id = p_branch_id
          )
    );
$$;


-- ============================================================
-- 3. HELPER: SUPERADMIN
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.current_user_is_superadmin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT
        bmt_db.current_user_is_active()
        AND
        bmt_db.current_user_has_role(
            'SUPERADMIN',
            NULL
        );
$$;


-- ============================================================
-- 4. HELPER: BRANCH ACCESS
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.current_user_has_branch_access(
    p_branch_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT
        bmt_db.current_user_is_active()
        AND
        (
            bmt_db.current_user_is_superadmin()

            OR EXISTS (
                SELECT 1
                FROM bmt_db.user_branches ub
                WHERE ub.user_id = auth.uid()
                  AND ub.branch_id = p_branch_id
            )
        );
$$;


-- ============================================================
-- 5. HELPER: PERMISSION
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.current_user_has_permission(
    p_permission_code TEXT,
    p_branch_id UUID DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT
        bmt_db.current_user_is_active()
        AND
        (
            bmt_db.current_user_is_superadmin()

            OR EXISTS (
                SELECT 1

                FROM bmt_db.user_roles ur

                JOIN bmt_db.roles r
                  ON r.id = ur.role_id
                 AND r.is_active = TRUE

                JOIN bmt_db.role_permissions rp
                  ON rp.role_id = r.id

                JOIN bmt_db.permissions p
                  ON p.id = rp.permission_id
                 AND p.is_active = TRUE

                WHERE ur.user_id = auth.uid()

                  AND ur.is_active = TRUE

                  AND ur.valid_from <= now()

                  AND (
                      ur.valid_until IS NULL
                      OR ur.valid_until > now()
                  )

                  AND p.code = p_permission_code

                  AND (
                      p_branch_id IS NULL
                      OR ur.branch_id IS NULL
                      OR ur.branch_id = p_branch_id
                  )
            )
        );
$$;


-- ============================================================
-- 6. HELPER: FINANCIAL ACCOUNT BRANCH ACCESS
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.current_user_can_access_account(
    p_account_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM bmt_db.financial_accounts fa
        WHERE fa.id = p_account_id
          AND bmt_db.current_user_has_branch_access(
              fa.branch_id
          )
    );
$$;


-- ============================================================
-- 7. HELPER: CUSTOMER BRANCH ACCESS
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.current_user_can_access_customer(
    p_customer_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM bmt_db.customers c
        WHERE c.id = p_customer_id
          AND bmt_db.current_user_has_branch_access(
              c.branch_id
          )
    );
$$;


-- ============================================================
-- 8. ENABLE RLS
-- ============================================================

ALTER TABLE bmt_db.branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.user_branches ENABLE ROW LEVEL SECURITY;

ALTER TABLE bmt_db.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.customer_addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.customer_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.customer_marketing ENABLE ROW LEVEL SECURITY;

ALTER TABLE bmt_db.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.savings_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.deposit_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.loan_products ENABLE ROW LEVEL SECURITY;

ALTER TABLE bmt_db.financial_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.savings_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.deposit_accounts ENABLE ROW LEVEL SECURITY;

ALTER TABLE bmt_db.loan_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.credit_analyses ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.loan_collaterals ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.loan_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.loan_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.installment_payments ENABLE ROW LEVEL SECURITY;

ALTER TABLE bmt_db.chart_of_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.fiscal_periods ENABLE ROW LEVEL SECURITY;

ALTER TABLE bmt_db.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.savings_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.deposit_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.loan_ledger ENABLE ROW LEVEL SECURITY;

ALTER TABLE bmt_db.journal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.journal_lines ENABLE ROW LEVEL SECURITY;

ALTER TABLE bmt_db.teller_cash_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.teller_cash_movements ENABLE ROW LEVEL SECURITY;

ALTER TABLE bmt_db.approval_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.approval_requests ENABLE ROW LEVEL SECURITY;

ALTER TABLE bmt_db.transaction_receipts ENABLE ROW LEVEL SECURITY;

ALTER TABLE bmt_db.number_sequences ENABLE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.audit_logs ENABLE ROW LEVEL SECURITY;


-- ============================================================
-- 9. BRANCHES
-- ============================================================

CREATE POLICY branches_select
ON bmt_db.branches
FOR SELECT
TO authenticated
USING (
    bmt_db.current_user_has_branch_access(id)
);


-- ============================================================
-- 10. USER PROFILE
-- ============================================================

CREATE POLICY user_profiles_select
ON bmt_db.user_profiles
FOR SELECT
TO authenticated
USING (
    id = auth.uid()
    OR bmt_db.current_user_is_superadmin()
);


-- ============================================================
-- 11. AUTHORIZATION MASTER
-- ============================================================

CREATE POLICY roles_select
ON bmt_db.roles
FOR SELECT
TO authenticated
USING (
    bmt_db.current_user_is_active()
);

CREATE POLICY permissions_select
ON bmt_db.permissions
FOR SELECT
TO authenticated
USING (
    bmt_db.current_user_is_active()
);

CREATE POLICY role_permissions_select
ON bmt_db.role_permissions
FOR SELECT
TO authenticated
USING (
    bmt_db.current_user_is_active()
);

CREATE POLICY user_roles_select
ON bmt_db.user_roles
FOR SELECT
TO authenticated
USING (
    user_id = auth.uid()
    OR bmt_db.current_user_is_superadmin()
);

CREATE POLICY user_branches_select
ON bmt_db.user_branches
FOR SELECT
TO authenticated
USING (
    user_id = auth.uid()
    OR bmt_db.current_user_is_superadmin()
);


-- ============================================================
-- 12. CUSTOMERS
-- ============================================================

CREATE POLICY customers_select
ON bmt_db.customers
FOR SELECT
TO authenticated
USING (
    bmt_db.current_user_has_branch_access(branch_id)
    AND (
        bmt_db.current_user_has_permission(
            'customer.view',
            branch_id
        )
        OR
        bmt_db.current_user_has_permission(
            'customer.create',
            branch_id
        )
        OR
        bmt_db.current_user_has_permission(
            'customer.update',
            branch_id
        )
    )
);


CREATE POLICY customers_insert
ON bmt_db.customers
FOR INSERT
TO authenticated
WITH CHECK (
    created_by = auth.uid()
    AND
    bmt_db.current_user_has_branch_access(branch_id)
    AND
    bmt_db.current_user_has_permission(
        'customer.create',
        branch_id
    )
);


CREATE POLICY customers_update
ON bmt_db.customers
FOR UPDATE
TO authenticated
USING (
    bmt_db.current_user_has_branch_access(branch_id)
    AND
    bmt_db.current_user_has_permission(
        'customer.update',
        branch_id
    )
)
WITH CHECK (
    bmt_db.current_user_has_branch_access(branch_id)
    AND
    bmt_db.current_user_has_permission(
        'customer.update',
        branch_id
    )
);


-- ============================================================
-- 13. CUSTOMER CHILD TABLES - READ
-- ============================================================

CREATE POLICY customer_addresses_select
ON bmt_db.customer_addresses
FOR SELECT
TO authenticated
USING (
    bmt_db.current_user_can_access_customer(
        customer_id
    )
);


CREATE POLICY customer_documents_select
ON bmt_db.customer_documents
FOR SELECT
TO authenticated
USING (
    bmt_db.current_user_can_access_customer(
        customer_id
    )
);


CREATE POLICY customer_marketing_select
ON bmt_db.customer_marketing
FOR SELECT
TO authenticated
USING (
    bmt_db.current_user_can_access_customer(
        customer_id
    )
);


-- ============================================================
-- 14. PRODUCT MASTER READ
-- ============================================================

CREATE POLICY products_select
ON bmt_db.products
FOR SELECT
TO authenticated
USING (
    bmt_db.current_user_is_active()
);

CREATE POLICY savings_products_select
ON bmt_db.savings_products
FOR SELECT
TO authenticated
USING (
    bmt_db.current_user_is_active()
);

CREATE POLICY deposit_products_select
ON bmt_db.deposit_products
FOR SELECT
TO authenticated
USING (
    bmt_db.current_user_is_active()
);

CREATE POLICY loan_products_select
ON bmt_db.loan_products
FOR SELECT
TO authenticated
USING (
    bmt_db.current_user_is_active()
);


-- ============================================================
-- 15. FINANCIAL ACCOUNTS READ
-- ============================================================

CREATE POLICY financial_accounts_select
ON bmt_db.financial_accounts
FOR SELECT
TO authenticated
USING (
    bmt_db.current_user_has_branch_access(
        branch_id
    )
);


CREATE POLICY savings_accounts_select
ON bmt_db.savings_accounts
FOR SELECT
TO authenticated
USING (
    bmt_db.current_user_can_access_account(
        financial_account_id
    )
);


CREATE POLICY deposit_accounts_select
ON bmt_db.deposit_accounts
FOR SELECT
TO authenticated
USING (
    bmt_db.current_user_can_access_account(
        financial_account_id
    )
);


-- ============================================================
-- 16. LOAN READ
-- ============================================================

CREATE POLICY loan_applications_select
ON bmt_db.loan_applications
FOR SELECT
TO authenticated
USING (
    bmt_db.current_user_has_branch_access(
        branch_id
    )
);


CREATE POLICY credit_analyses_select
ON bmt_db.credit_analyses
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM bmt_db.loan_applications la
        WHERE la.id = loan_application_id
          AND bmt_db.current_user_has_branch_access(
              la.branch_id
          )
    )
);


CREATE POLICY loan_collaterals_select
ON bmt_db.loan_collaterals
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM bmt_db.loan_applications la
        WHERE la.id = loan_application_id
          AND bmt_db.current_user_has_branch_access(
              la.branch_id
          )
    )
);


CREATE POLICY loan_accounts_select
ON bmt_db.loan_accounts
FOR SELECT
TO authenticated
USING (
    bmt_db.current_user_can_access_account(
        financial_account_id
    )
);


CREATE POLICY loan_schedules_select
ON bmt_db.loan_schedules
FOR SELECT
TO authenticated
USING (
    bmt_db.current_user_can_access_account(
        loan_account_id
    )
);


CREATE POLICY installment_payments_select
ON bmt_db.installment_payments
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM bmt_db.loan_schedules ls
        WHERE ls.id = loan_schedule_id
          AND bmt_db.current_user_can_access_account(
              ls.loan_account_id
          )
    )
);


-- ============================================================
-- 17. ACCOUNTING MASTER READ
-- ============================================================

CREATE POLICY chart_of_accounts_select
ON bmt_db.chart_of_accounts
FOR SELECT
TO authenticated
USING (
    bmt_db.current_user_has_permission(
        'report.financial.view',
        NULL
    )
    OR
    bmt_db.current_user_has_permission(
        'system.coa.manage',
        NULL
    )
);


CREATE POLICY fiscal_periods_select
ON bmt_db.fiscal_periods
FOR SELECT
TO authenticated
USING (
    bmt_db.current_user_is_active()
);


-- ============================================================
-- 18. TRANSACTIONS READ
-- ============================================================

CREATE POLICY transactions_select
ON bmt_db.transactions
FOR SELECT
TO authenticated
USING (
    bmt_db.current_user_has_branch_access(
        branch_id
    )
);


-- ============================================================
-- 19. SUBLEDGER READ
-- ============================================================

CREATE POLICY savings_ledger_select
ON bmt_db.savings_ledger
FOR SELECT
TO authenticated
USING (
    bmt_db.current_user_can_access_account(
        account_id
    )
);


CREATE POLICY deposit_ledger_select
ON bmt_db.deposit_ledger
FOR SELECT
TO authenticated
USING (
    bmt_db.current_user_can_access_account(
        deposit_account_id
    )
);


CREATE POLICY loan_ledger_select
ON bmt_db.loan_ledger
FOR SELECT
TO authenticated
USING (
    bmt_db.current_user_can_access_account(
        loan_account_id
    )
);


-- ============================================================
-- 20. JOURNAL READ
-- ============================================================

CREATE POLICY journal_entries_select
ON bmt_db.journal_entries
FOR SELECT
TO authenticated
USING (
    bmt_db.current_user_has_branch_access(
        branch_id
    )
    AND
    bmt_db.current_user_has_permission(
        'report.financial.view',
        branch_id
    )
);


CREATE POLICY journal_lines_select
ON bmt_db.journal_lines
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM bmt_db.journal_entries je
        WHERE je.id = journal_entry_id
          AND
          bmt_db.current_user_has_branch_access(
              je.branch_id
          )
          AND
          bmt_db.current_user_has_permission(
              'report.financial.view',
              je.branch_id
          )
    )
);


-- ============================================================
-- 21. TELLER READ
-- ============================================================

CREATE POLICY teller_cash_sessions_select
ON bmt_db.teller_cash_sessions
FOR SELECT
TO authenticated
USING (
    teller_user_id = auth.uid()
    OR
    (
        bmt_db.current_user_has_branch_access(
            branch_id
        )
        AND
        bmt_db.current_user_has_role(
            'MANAGER',
            branch_id
        )
    )
    OR
    bmt_db.current_user_is_superadmin()
);


CREATE POLICY teller_cash_movements_select
ON bmt_db.teller_cash_movements
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM bmt_db.teller_cash_sessions tcs
        WHERE tcs.id = cash_session_id
          AND (
              tcs.teller_user_id = auth.uid()

              OR (
                  bmt_db.current_user_has_branch_access(
                      tcs.branch_id
                  )
                  AND
                  bmt_db.current_user_has_role(
                      'MANAGER',
                      tcs.branch_id
                  )
              )

              OR bmt_db.current_user_is_superadmin()
          )
    )
);


-- ============================================================
-- 22. APPROVAL READ
-- ============================================================

CREATE POLICY approval_rules_select
ON bmt_db.approval_rules
FOR SELECT
TO authenticated
USING (
    bmt_db.current_user_is_active()
    AND (
        branch_id IS NULL
        OR bmt_db.current_user_has_branch_access(
            branch_id
        )
    )
);


CREATE POLICY approval_requests_select
ON bmt_db.approval_requests
FOR SELECT
TO authenticated
USING (
    requested_by = auth.uid()
    OR resolved_by = auth.uid()
    OR bmt_db.current_user_is_superadmin()
    OR bmt_db.current_user_has_role(
        required_role,
        NULL
    )
);


-- ============================================================
-- 23. RECEIPTS READ
-- ============================================================

CREATE POLICY transaction_receipts_select
ON bmt_db.transaction_receipts
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM bmt_db.transactions t
        WHERE t.id = transaction_id
          AND bmt_db.current_user_has_branch_access(
              t.branch_id
          )
    )
);


-- ============================================================
-- 24. NUMBER SEQUENCES
-- ============================================================
-- No authenticated policies.
-- Frontend must never manipulate sequence counters directly.


-- ============================================================
-- 25. AUDIT LOG READ
-- ============================================================

CREATE POLICY audit_logs_select
ON bmt_db.audit_logs
FOR SELECT
TO authenticated
USING (
    bmt_db.current_user_is_superadmin()
);


-- ============================================================
-- 26. API SCHEMA USAGE
-- ============================================================

GRANT USAGE ON SCHEMA bmt_db TO authenticated;
GRANT USAGE ON SCHEMA bmt_db TO service_role;

REVOKE ALL ON SCHEMA bmt_db FROM anon;


-- ============================================================
-- 27. TABLE PRIVILEGES
-- ============================================================
-- RLS controls rows, while GRANT controls whether an operation
-- can be attempted at all.

GRANT SELECT ON
    bmt_db.branches,
    bmt_db.user_profiles,
    bmt_db.roles,
    bmt_db.permissions,
    bmt_db.role_permissions,
    bmt_db.user_roles,
    bmt_db.user_branches,

    bmt_db.customers,
    bmt_db.customer_addresses,
    bmt_db.customer_documents,
    bmt_db.customer_marketing,

    bmt_db.products,
    bmt_db.savings_products,
    bmt_db.deposit_products,
    bmt_db.loan_products,

    bmt_db.financial_accounts,
    bmt_db.savings_accounts,
    bmt_db.deposit_accounts,

    bmt_db.loan_applications,
    bmt_db.credit_analyses,
    bmt_db.loan_collaterals,
    bmt_db.loan_accounts,
    bmt_db.loan_schedules,
    bmt_db.installment_payments,

    bmt_db.chart_of_accounts,
    bmt_db.fiscal_periods,

    bmt_db.transactions,
    bmt_db.savings_ledger,
    bmt_db.deposit_ledger,
    bmt_db.loan_ledger,

    bmt_db.journal_entries,
    bmt_db.journal_lines,

    bmt_db.teller_cash_sessions,
    bmt_db.teller_cash_movements,

    bmt_db.approval_rules,
    bmt_db.approval_requests,

    bmt_db.transaction_receipts,
    bmt_db.audit_logs

TO authenticated;


-- Customer creation/edit is one of the few controlled direct
-- CRUD operations allowed in v1.

GRANT INSERT, UPDATE
ON bmt_db.customers
TO authenticated;


-- ============================================================
-- 28. VIEW PRIVILEGES
-- ============================================================

GRANT SELECT
ON bmt_db.general_ledger,
   bmt_db.trial_balance
TO authenticated;


-- ============================================================
-- 29. HELPER FUNCTION EXECUTION
-- ============================================================

REVOKE ALL ON FUNCTION
    bmt_db.current_user_is_active()
FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION
    bmt_db.current_user_has_role(TEXT, UUID)
FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION
    bmt_db.current_user_is_superadmin()
FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION
    bmt_db.current_user_has_branch_access(UUID)
FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION
    bmt_db.current_user_has_permission(TEXT, UUID)
FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION
    bmt_db.current_user_can_access_account(UUID)
FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION
    bmt_db.current_user_can_access_customer(UUID)
FROM PUBLIC, anon, authenticated;


-- Policies execute these functions internally. Direct RPC
-- exposure is intentionally unnecessary.


-- ============================================================
-- 30. INTERNAL ENGINE REMAINS PRIVATE
-- ============================================================

REVOKE ALL ON FUNCTION
    bmt_db.next_sequence(
        UUID,
        bmt_db.sequence_type,
        TEXT,
        TEXT,
        DATE,
        bmt_db.sequence_reset_policy,
        INTEGER
    )
FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION
    bmt_db.post_journal(UUID, UUID)
FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION
    bmt_db.mark_transaction_posted(UUID, UUID)
FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION
    bmt_db.reverse_transaction(UUID, UUID, TEXT)
FROM PUBLIC, anon, authenticated;


-- ============================================================
-- 31. SERVICE ROLE
-- ============================================================

GRANT ALL PRIVILEGES
ON ALL TABLES IN SCHEMA bmt_db
TO service_role;

GRANT EXECUTE
ON ALL FUNCTIONS IN SCHEMA bmt_db
TO service_role;


COMMIT;
