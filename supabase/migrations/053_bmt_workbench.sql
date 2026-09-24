BEGIN;

CREATE TABLE bmt_db.customer_followups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid NOT NULL REFERENCES bmt_db.customers(id),
  owner_id uuid NOT NULL DEFAULT auth.uid() REFERENCES bmt_db.user_profiles(id),
  note text NOT NULL CHECK (length(btrim(note)) BETWEEN 1 AND 2000),
  due_at timestamptz NOT NULL,
  completed boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX customer_followups_owner_due ON bmt_db.customer_followups(owner_id, completed, due_at);
CREATE INDEX customer_followups_customer ON bmt_db.customer_followups(customer_id);
ALTER TABLE bmt_db.customer_followups ENABLE ROW LEVEL SECURITY;

CREATE POLICY followups_read ON bmt_db.customer_followups FOR SELECT TO authenticated
USING (bmt_db.current_user_is_active() AND bmt_db.current_user_can_access_customer(customer_id)
  AND (owner_id = auth.uid() OR bmt_db.current_user_is_superadmin() OR bmt_db.current_user_has_role('MANAGER', NULL)));
CREATE POLICY followups_insert ON bmt_db.customer_followups FOR INSERT TO authenticated
WITH CHECK (owner_id = auth.uid() AND bmt_db.current_user_is_active()
  AND bmt_db.current_user_can_access_customer(customer_id)
  AND EXISTS (SELECT 1 FROM bmt_db.customer_marketing cm WHERE cm.customer_id = customer_followups.customer_id
    AND cm.marketing_user_id = auth.uid() AND cm.is_active
    AND cm.assigned_from <= now() AND (cm.assigned_until IS NULL OR cm.assigned_until >= now())));
CREATE POLICY followups_update ON bmt_db.customer_followups FOR UPDATE TO authenticated
USING (owner_id = auth.uid() AND bmt_db.current_user_is_active() AND bmt_db.current_user_can_access_customer(customer_id))
WITH CHECK (owner_id = auth.uid() AND bmt_db.current_user_is_active() AND bmt_db.current_user_can_access_customer(customer_id));
REVOKE ALL ON bmt_db.customer_followups FROM PUBLIC, anon;
GRANT SELECT, INSERT ON bmt_db.customer_followups TO authenticated;
GRANT UPDATE(completed) ON bmt_db.customer_followups TO authenticated;

CREATE FUNCTION bmt_db.workbench_summary() RETURNS jsonb
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = '' AS $$
 SELECT jsonb_build_object(
   'customers', (SELECT count(*) FROM bmt_db.customers),
   'onboarding_pending', (SELECT count(*) FROM bmt_db.onboarding_applications WHERE status IN ('TELLER_REVIEW','MANAGER_REVIEW')),
   'loans_pending', (SELECT count(*) FROM bmt_db.loan_applications WHERE status::text IN ('SUBMITTED','REVIEW')),
   'followups_due', (SELECT count(*) FROM bmt_db.customer_followups WHERE NOT completed AND due_at <= now())
 ) WHERE auth.uid() IS NOT NULL AND bmt_db.current_user_is_active();
$$;
REVOKE ALL ON FUNCTION bmt_db.workbench_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bmt_db.workbench_summary() TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
