\set ON_ERROR_STOP on
BEGIN;
DO $$
DECLARE customer uuid; actor uuid := '8c3c600e-6865-4c4b-b15a-fb8001960704'; task uuid;
BEGIN
 SELECT id INTO customer FROM bmt_db.customers LIMIT 1;
 IF customer IS NULL THEN RAISE EXCEPTION 'Local customer fixture required'; END IF;
 PERFORM set_config('request.jwt.claim.sub', actor::text, true);
 SET LOCAL ROLE authenticated;
 BEGIN
   INSERT INTO bmt_db.customer_followups(customer_id,note,due_at) VALUES(customer,'Unauthorized test',now());
   RAISE EXCEPTION 'Unassigned insert unexpectedly allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 RESET ROLE;
 INSERT INTO bmt_db.customer_marketing(customer_id,marketing_user_id,assigned_from) VALUES(customer,actor,now() - interval '1 day');
 SET LOCAL ROLE authenticated;
 INSERT INTO bmt_db.customer_followups(customer_id,note,due_at) VALUES(customer,'Rollback fixture',now()) RETURNING id INTO task;
 UPDATE bmt_db.customer_followups SET completed=true WHERE id=task;
 IF NOT EXISTS(SELECT 1 FROM bmt_db.customer_followups WHERE id=task AND completed) THEN RAISE EXCEPTION 'Owner completion failed'; END IF;
 BEGIN
   UPDATE bmt_db.customer_followups SET owner_id='570893f3-26dd-44d7-9308-34314250e39c' WHERE id=task;
   RAISE EXCEPTION 'Owner reassignment unexpectedly allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000099',true);
 IF EXISTS(SELECT 1 FROM bmt_db.customer_followups WHERE id=task) THEN RAISE EXCEPTION 'Cross-user leak'; END IF;
 RESET ROLE;
 IF has_table_privilege('anon','bmt_db.customer_followups','SELECT') THEN RAISE EXCEPTION 'Anon access'; END IF;
END $$;
ROLLBACK;
SELECT 'PASS: unassigned denied, assigned insert, owner completion, immutable owner, cross-user isolation, anon denied';
