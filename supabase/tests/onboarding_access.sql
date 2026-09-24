\set ON_ERROR_STOP on
BEGIN;
\o /dev/null
INSERT INTO auth.users(id) VALUES ('ed3a92d0-69ea-4de9-934f-000000000001'),('ed3a92d0-69ea-4de9-934f-000000000002');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','ed3a92d0-69ea-4de9-934f-000000000001',true) IS NOT NULL;
SELECT bmt_db.save_onboarding_draft('{"fullName":"UJI ROLLBACK","nik":"0000000000000026","phone":"0800000000","address":"Alamat sintetis pengujian","purpose":"Menabung"}') IS NOT NULL AS draft_saved;
SELECT bmt_db.save_onboarding_draft('{"fullName":"UJI ROLLBACK","nik":"0000000000000026","phone":"0800000000","address":"Alamat diperbarui","purpose":"Menabung"}') IS NOT NULL AS draft_updated;
DO $$ BEGIN
 IF (SELECT count(*) FROM bmt_db.onboarding_applications WHERE applicant_user_id=auth.uid()) <> 1 THEN RAISE EXCEPTION 'Duplicate/missing draft'; END IF;
 IF (SELECT count(*) FROM bmt_db.onboarding_addresses WHERE address='Alamat diperbarui') <> 1 THEN RAISE EXCEPTION 'Address update failed'; END IF;
END $$;
SELECT set_config('request.jwt.claim.sub','ed3a92d0-69ea-4de9-934f-000000000002',true) IS NOT NULL;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM bmt_db.onboarding_applications WHERE applicant_user_id='ed3a92d0-69ea-4de9-934f-000000000001') THEN RAISE EXCEPTION 'Cross-customer read allowed'; END IF;
END $$;
ROLLBACK;
\o
SELECT plan(1);
SELECT ok(TRUE, 'onboarding access checks completed');
SELECT * FROM finish();
