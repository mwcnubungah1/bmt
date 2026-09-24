-- ============================================================
-- BMT CORE BANKING
-- Migration 011
-- RLS Authorization Helper Permissions
--
-- RLS policies execute authorization helper functions as the
-- authenticated database role. PostgreSQL therefore requires
-- EXECUTE privilege on helpers referenced by those policies.
--
-- These grants DO NOT grant table access by themselves.
-- Table privileges and RLS policies remain authoritative.
-- ============================================================

BEGIN;

GRANT EXECUTE
ON FUNCTION bmt_db.current_user_is_active()
TO authenticated;

GRANT EXECUTE
ON FUNCTION bmt_db.current_user_has_role(TEXT, UUID)
TO authenticated;

GRANT EXECUTE
ON FUNCTION bmt_db.current_user_is_superadmin()
TO authenticated;

GRANT EXECUTE
ON FUNCTION bmt_db.current_user_has_branch_access(UUID)
TO authenticated;

GRANT EXECUTE
ON FUNCTION bmt_db.current_user_has_permission(TEXT, UUID)
TO authenticated;

GRANT EXECUTE
ON FUNCTION bmt_db.current_user_can_access_customer(UUID)
TO authenticated;

GRANT EXECUTE
ON FUNCTION bmt_db.current_user_can_access_account(UUID)
TO authenticated;

COMMIT;
