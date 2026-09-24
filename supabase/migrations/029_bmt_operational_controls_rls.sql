BEGIN;

-- Operational tables are intentionally closed to ordinary authenticated users
-- until their domain RPCs are introduced.  Superadmin access is explicit;
-- service_role remains available for controlled server-side operations.
CREATE POLICY operational_controls_superadmin_select
ON bmt_db.customer_risk_profiles FOR SELECT TO authenticated
USING (bmt_db.current_user_is_superadmin());
CREATE POLICY operational_controls_superadmin_write
ON bmt_db.customer_risk_profiles FOR ALL TO authenticated
USING (bmt_db.current_user_is_superadmin())
WITH CHECK (bmt_db.current_user_is_superadmin());

CREATE POLICY customer_status_history_superadmin
ON bmt_db.customer_status_history FOR ALL TO authenticated
USING (bmt_db.current_user_is_superadmin())
WITH CHECK (bmt_db.current_user_is_superadmin());
CREATE POLICY account_status_history_superadmin
ON bmt_db.account_status_history FOR ALL TO authenticated
USING (bmt_db.current_user_is_superadmin())
WITH CHECK (bmt_db.current_user_is_superadmin());
CREATE POLICY loan_status_history_superadmin
ON bmt_db.loan_application_status_history FOR ALL TO authenticated
USING (bmt_db.current_user_is_superadmin())
WITH CHECK (bmt_db.current_user_is_superadmin());
CREATE POLICY business_calendar_superadmin
ON bmt_db.business_calendar FOR ALL TO authenticated
USING (bmt_db.current_user_is_superadmin())
WITH CHECK (bmt_db.current_user_is_superadmin());
CREATE POLICY operational_days_superadmin
ON bmt_db.operational_days FOR ALL TO authenticated
USING (bmt_db.current_user_is_superadmin())
WITH CHECK (bmt_db.current_user_is_superadmin());
CREATE POLICY reconciliation_exceptions_superadmin
ON bmt_db.reconciliation_exceptions FOR ALL TO authenticated
USING (bmt_db.current_user_is_superadmin())
WITH CHECK (bmt_db.current_user_is_superadmin());
CREATE POLICY audit_event_changes_superadmin
ON bmt_db.audit_event_changes FOR ALL TO authenticated
USING (bmt_db.current_user_is_superadmin())
WITH CHECK (bmt_db.current_user_is_superadmin());
CREATE POLICY fee_schedules_superadmin
ON bmt_db.fee_schedules FOR ALL TO authenticated
USING (bmt_db.current_user_is_superadmin())
WITH CHECK (bmt_db.current_user_is_superadmin());

CREATE POLICY idempotency_keys_actor_access
ON bmt_db.idempotency_keys FOR ALL TO authenticated
USING (actor_id = auth.uid() OR bmt_db.current_user_is_superadmin())
WITH CHECK (actor_id = auth.uid() OR bmt_db.current_user_is_superadmin());

COMMIT;
