BEGIN;
DROP POLICY followups_insert ON bmt_db.customer_followups;
CREATE POLICY followups_insert ON bmt_db.customer_followups FOR INSERT TO authenticated
WITH CHECK (owner_id = auth.uid() AND bmt_db.current_user_is_active()
  AND bmt_db.current_user_has_role('MARKETING', NULL)
  AND bmt_db.current_user_can_access_customer(customer_id)
  AND EXISTS (SELECT 1 FROM bmt_db.customer_marketing cm WHERE cm.customer_id = customer_followups.customer_id
    AND cm.marketing_user_id = auth.uid() AND cm.is_active
    AND cm.assigned_from <= now() AND (cm.assigned_until IS NULL OR cm.assigned_until >= now())));
COMMIT;
