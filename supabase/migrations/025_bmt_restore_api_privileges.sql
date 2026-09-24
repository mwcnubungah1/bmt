BEGIN;
-- Restore explicit API grants from 008, 011 and 012 after local import.
-- Existing RLS and workflow triggers remain authoritative.
GRANT USAGE ON SCHEMA bmt_db TO authenticated;
GRANT SELECT ON bmt_db.customers, bmt_db.customer_addresses,
 bmt_db.customer_documents, bmt_db.customer_marketing, bmt_db.products,
 bmt_db.savings_products, bmt_db.deposit_products, bmt_db.loan_products,
 bmt_db.financial_accounts, bmt_db.savings_accounts, bmt_db.deposit_accounts,
 bmt_db.loan_applications, bmt_db.credit_analyses, bmt_db.loan_collaterals,
 bmt_db.loan_accounts, bmt_db.loan_schedules, bmt_db.installment_payments,
 bmt_db.transactions, bmt_db.teller_cash_sessions, bmt_db.teller_cash_movements,
 bmt_db.approval_requests, bmt_db.approval_rules,
 bmt_db.onboarding_signatures, bmt_db.onboarding_status_history
TO authenticated;
GRANT SELECT, INSERT, UPDATE ON bmt_db.onboarding_applications TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON bmt_db.onboarding_addresses,
 bmt_db.onboarding_employment, bmt_db.onboarding_financial_profiles,
 bmt_db.onboarding_bank_accounts, bmt_db.onboarding_product_requests,
 bmt_db.onboarding_documents TO authenticated;
GRANT EXECUTE ON FUNCTION bmt_db.current_user_is_active(),
 bmt_db.current_user_is_superadmin(),
 bmt_db.current_user_has_role(text,uuid),
 bmt_db.current_user_has_branch_access(uuid),
 bmt_db.current_user_has_permission(text,uuid),
 bmt_db.current_user_can_access_customer(uuid),
 bmt_db.current_user_can_access_account(uuid),
 bmt_db.current_user_can_access_onboarding(uuid),
 bmt_db.current_user_can_edit_onboarding(uuid)
TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
