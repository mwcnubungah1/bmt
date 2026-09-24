-- Regression tests for P0 maintenance RPC authorization and P1 loan document RLS.
-- This file intentionally uses plain PostgreSQL so it can run in Supabase SQL
-- Editor, which does not provide psql meta-commands or pgTAP by default.
SELECT * FROM (VALUES
  ('authenticated cannot execute global loan maintenance', NOT has_function_privilege('authenticated', 'bmt_db.refresh_loan_quality()', 'EXECUTE')),
  ('anon cannot execute global loan maintenance', NOT has_function_privilege('anon', 'bmt_db.refresh_loan_quality()', 'EXECUTE')),
  ('service_role can execute global loan maintenance', has_function_privilege('service_role', 'bmt_db.refresh_loan_quality()', 'EXECUTE')),
  ('authenticated cannot execute global savings maintenance', NOT has_function_privilege('authenticated', 'bmt_db.refresh_savings_account_status()', 'EXECUTE')),
  ('service_role can execute global savings maintenance', has_function_privilege('service_role', 'bmt_db.refresh_savings_account_status()', 'EXECUTE')),
  ('loan document metadata has RLS enabled', (SELECT relrowsecurity FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'bmt_db' AND c.relname = 'loan_application_documents')),
  ('loan document metadata has authenticated SELECT policy', EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'bmt_db' AND tablename = 'loan_application_documents' AND policyname = 'loan_application_documents_select' AND cmd = 'SELECT' AND roles @> ARRAY['authenticated']::name[])),
  ('authenticated cannot directly insert loan document metadata', NOT has_table_privilege('authenticated', 'bmt_db.loan_application_documents', 'INSERT')),
  ('authenticated cannot directly update loan document metadata', NOT has_table_privilege('authenticated', 'bmt_db.loan_application_documents', 'UPDATE')),
  ('customer document upload is exposed through controlled RPC', has_function_privilege('authenticated', 'bmt_db.customer_upload_loan_document(uuid,text,text,text,text,text,bigint)', 'EXECUTE'))
) AS security_check(test_name, passed);
