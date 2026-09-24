BEGIN;

-- Maintenance routines are database-job operations, not end-user API calls.
-- Keep EXECUTE available to service_role for scheduled/internal execution only.
REVOKE EXECUTE ON FUNCTION bmt_db.refresh_loan_quality() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION bmt_db.refresh_loan_quality() TO service_role;

REVOKE EXECUTE ON FUNCTION bmt_db.refresh_savings_account_status() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION bmt_db.refresh_savings_account_status() TO service_role;

-- The document metadata table is accessed through the controlled customer upload
-- RPC and future staff review RPCs. Do not expose direct writes to the browser.
REVOKE INSERT, UPDATE, DELETE ON bmt_db.loan_application_documents FROM authenticated;
GRANT SELECT ON bmt_db.loan_application_documents TO authenticated;

DROP POLICY IF EXISTS loan_application_documents_select ON bmt_db.loan_application_documents;
CREATE POLICY loan_application_documents_select
ON bmt_db.loan_application_documents
FOR SELECT
TO authenticated
USING (
  (
    EXISTS (
      SELECT 1
      FROM bmt_db.customers customer_row
      WHERE customer_row.id = loan_application_documents.customer_id
        AND customer_row.auth_user_id = auth.uid()
    )
    OR bmt_db.current_user_can_access_customer(customer_id)
  )
);

DROP POLICY IF EXISTS loan_application_documents_service_all ON bmt_db.loan_application_documents;
CREATE POLICY loan_application_documents_service_all
ON bmt_db.loan_application_documents
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

COMMENT ON TABLE bmt_db.loan_application_documents IS
'Private financing documents. Browser writes go through customer_upload_loan_document; reads are RLS-scoped to the customer or authorized staff.';

NOTIFY pgrst, 'reload schema';
COMMIT;
