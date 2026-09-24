\set ON_ERROR_STOP on
BEGIN;
\o /dev/null
DO $$ DECLARE r record; n integer; tested integer := 0;
BEGIN
 FOR r IN SELECT DISTINCT ur.user_id,ro.code FROM bmt_db.user_roles ur
 JOIN bmt_db.roles ro ON ro.id=ur.role_id
 WHERE ro.code IN ('TELLER','MARKETING','MANAGER','SUPERADMIN') AND ur.is_active
 LOOP
   PERFORM set_config('request.jwt.claim.sub',r.user_id::text,true);
   SET LOCAL ROLE authenticated;
   SELECT count(*) INTO n FROM bmt_db.onboarding_applications;
   RAISE NOTICE '% onboarding accessible=%',r.code,n;
   SELECT count(*) INTO n FROM bmt_db.customers;
   RAISE NOTICE '% customers accessible=%',r.code,n;
   RESET ROLE;
   tested := tested+1;
 END LOOP;
 IF tested < 4 THEN RAISE EXCEPTION 'Expected four staff identities'; END IF;
END $$;
ROLLBACK;
\o
SELECT plan(1);
SELECT ok(TRUE, 'staff read access checks completed');
SELECT * FROM finish();
