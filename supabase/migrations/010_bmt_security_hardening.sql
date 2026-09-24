-- ============================================================
-- BMT CORE BANKING SYSTEM
-- Migration : 010_bmt_security_hardening.sql
-- Purpose   : Harden RBAC, branch isolation, approvals,
--             accounting views and RLS enforcement
-- Requires  : 001 - 009
-- ============================================================

BEGIN;


-- ============================================================
-- 1. HARDEN ROLE CHECK
--
-- Rules:
-- - p_branch_id NULL means "check whether user owns this role
--   somewhere", NOT global branch access.
-- - branch_id NULL on user_roles is NOT a wildcard.
-- - SUPERADMIN global behaviour is handled explicitly by
--   current_user_is_superadmin().
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
              p_branch_id IS NULL
              OR ur.branch_id = p_branch_id
          )
    );
$$;


-- ============================================================
-- 2. SUPERADMIN
--
-- Global access comes ONLY from an active SUPERADMIN role.
-- It does not depend on branch_id being NULL.
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
-- 3. HARDEN BRANCH ACCESS
--
-- Non-superadmin:
--   must have explicit user_branches assignment.
--
-- SUPERADMIN:
--   explicit global access.
--
-- NULL branch never means global access.
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
        p_branch_id IS NOT NULL
        AND bmt_db.current_user_is_active()
        AND (
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
-- 4. HARDEN PERMISSION CHECK
--
-- For branch-specific checks:
-- role must belong to requested branch.
--
-- For non-branch checks:
-- user only needs an active role carrying the permission.
--
-- NULL user_roles.branch_id never becomes a wildcard.
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
        AND (
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
                      OR (
                          ur.branch_id = p_branch_id
                          AND bmt_db.current_user_has_branch_access(
                              p_branch_id
                          )
                      )
                  )
            )
        );
$$;


-- ============================================================
-- 5. INITIAL USER_BRANCH ASSIGNMENTS
--
-- Synchronize existing operational staff with Branch 001.
-- Idempotent via NOT EXISTS.
-- ============================================================

INSERT INTO bmt_db.user_branches (
    user_id,
    branch_id,
    is_primary,
    assigned_by
)
SELECT
    v.user_id,
    v.branch_id,
    TRUE,
    NULL
FROM (
    VALUES
        (
            'e088ce1d-fb7c-47aa-a15d-7dfa779d7583'::uuid,
            '6bffdf69-9f87-4432-9f66-8f82c4c65775'::uuid
        ),
        (
            '570893f3-26dd-44d7-9308-34314250e39c'::uuid,
            '6bffdf69-9f87-4432-9f66-8f82c4c65775'::uuid
        ),
        (
            '8c3c600e-6865-4c4b-b15a-fb8001960704'::uuid,
            '6bffdf69-9f87-4432-9f66-8f82c4c65775'::uuid
        ),
        (
            'c6f40c04-6914-4494-9390-7526b953e982'::uuid,
            '6bffdf69-9f87-4432-9f66-8f82c4c65775'::uuid
        )
) AS v(user_id, branch_id)
JOIN bmt_db.user_profiles up
  ON up.id = v.user_id
 AND up.is_active = TRUE
JOIN bmt_db.branches b
  ON b.id = v.branch_id
 AND b.is_active = TRUE
WHERE NOT EXISTS (
    SELECT 1
    FROM bmt_db.user_branches ub
    WHERE ub.user_id = v.user_id
      AND ub.branch_id = v.branch_id
);


-- ============================================================
-- 6. APPROVAL REQUEST BRANCH
--
-- Approval must have explicit branch context.
--
-- Approval requests are branch-scoped.
-- Table is currently empty, therefore branch_id can safely
-- be enforced NOT NULL from the beginning.
-- historical approval records that cannot safely be inferred.
-- New application logic must populate branch_id.
-- ============================================================

ALTER TABLE bmt_db.approval_requests
ADD COLUMN IF NOT EXISTS branch_id UUID;

ALTER TABLE bmt_db.approval_requests
ALTER COLUMN branch_id SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'approval_requests_branch_id_fkey'
          AND conrelid = 'bmt_db.approval_requests'::regclass
    ) THEN
        ALTER TABLE bmt_db.approval_requests
        ADD CONSTRAINT approval_requests_branch_id_fkey
        FOREIGN KEY (branch_id)
        REFERENCES bmt_db.branches(id);
    END IF;
END
$$;

CREATE INDEX IF NOT EXISTS idx_approval_requests_branch_id
ON bmt_db.approval_requests(branch_id);


-- ============================================================
-- 7. HARDEN APPROVAL REQUEST READ POLICY
--
-- Requester/resolver can see their own workflow.
-- SUPERADMIN can see all.
-- Approver must:
--   - have required role in the request branch
--   - have access to that branch
--
-- Legacy NULL-branch requests are NOT exposed to ordinary
-- branch approvers.
-- ============================================================

DROP POLICY IF EXISTS approval_requests_select
ON bmt_db.approval_requests;

CREATE POLICY approval_requests_select
ON bmt_db.approval_requests
FOR SELECT
TO authenticated
USING (
    requested_by = auth.uid()

    OR resolved_by = auth.uid()

    OR bmt_db.current_user_is_superadmin()

    OR (
        branch_id IS NOT NULL

        AND bmt_db.current_user_has_branch_access(
            branch_id
        )

        AND bmt_db.current_user_has_role(
            required_role,
            branch_id
        )
    )
);


-- ============================================================
-- 8. ACCOUNTING VIEW SECURITY
--
-- security_invoker makes underlying table privileges/RLS apply
-- using the querying user's context.
-- ============================================================

ALTER VIEW bmt_db.general_ledger
SET (security_invoker = true);

ALTER VIEW bmt_db.trial_balance
SET (security_invoker = true);


-- ============================================================
-- 9. HELPER FUNCTIONS REMAIN INTERNAL
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


-- ============================================================
-- 10. FORCE RLS
--
-- FORCE ensures table owners are also subject to RLS during
-- ordinary access. SECURITY DEFINER/service administration must
-- remain deliberate.
-- ============================================================

ALTER TABLE bmt_db.branches FORCE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.user_profiles FORCE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.roles FORCE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.permissions FORCE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.role_permissions FORCE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.user_roles FORCE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.user_branches FORCE ROW LEVEL SECURITY;

ALTER TABLE bmt_db.customers FORCE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.customer_addresses FORCE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.customer_documents FORCE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.customer_marketing FORCE ROW LEVEL SECURITY;

ALTER TABLE bmt_db.products FORCE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.savings_products FORCE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.deposit_products FORCE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.loan_products FORCE ROW LEVEL SECURITY;

ALTER TABLE bmt_db.financial_accounts FORCE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.savings_accounts FORCE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.deposit_accounts FORCE ROW LEVEL SECURITY;

ALTER TABLE bmt_db.loan_applications FORCE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.credit_analyses FORCE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.loan_collaterals FORCE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.loan_accounts FORCE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.loan_schedules FORCE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.installment_payments FORCE ROW LEVEL SECURITY;

ALTER TABLE bmt_db.chart_of_accounts FORCE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.fiscal_periods FORCE ROW LEVEL SECURITY;

ALTER TABLE bmt_db.transactions FORCE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.savings_ledger FORCE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.deposit_ledger FORCE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.loan_ledger FORCE ROW LEVEL SECURITY;

ALTER TABLE bmt_db.journal_entries FORCE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.journal_lines FORCE ROW LEVEL SECURITY;

ALTER TABLE bmt_db.teller_cash_sessions FORCE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.teller_cash_movements FORCE ROW LEVEL SECURITY;

ALTER TABLE bmt_db.approval_rules FORCE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.approval_requests FORCE ROW LEVEL SECURITY;

ALTER TABLE bmt_db.transaction_receipts FORCE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.number_sequences FORCE ROW LEVEL SECURITY;
ALTER TABLE bmt_db.audit_logs FORCE ROW LEVEL SECURITY;


COMMIT;
