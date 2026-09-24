-- Authenticated role/branch matrix for seeded local identities.
\set ON_ERROR_STOP on

SELECT plan(6);

SELECT id AS branch_id FROM bmt_db.branches WHERE code = '001' \gset

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'e088ce1d-fb7c-47aa-a15d-7dfa779d7583', false);

SELECT ok(
    bmt_db.current_user_has_branch_access(:'branch_id'::uuid),
    'SUPERADMIN can access branch 001'
);

SELECT ok(
    bmt_db.current_user_is_superadmin(),
    'SUPERADMIN identity is recognized'
);

SELECT set_config('request.jwt.claim.sub', '570893f3-26dd-44d7-9308-34314250e39c', false);
SELECT ok(
    bmt_db.current_user_has_branch_access(:'branch_id'::uuid),
    'MANAGER can access assigned branch 001'
);

SELECT set_config('request.jwt.claim.sub', 'c6f40c04-6914-4494-9390-7526b953e982', false);
SELECT ok(
    bmt_db.current_user_has_branch_access(:'branch_id'::uuid),
    'TELLER can access assigned branch 001'
);

SELECT ok(
    NOT bmt_db.current_user_has_branch_access('00000000-0000-0000-0000-000000000000'::uuid),
    'TELLER cannot access an unassigned branch'
);

RESET ROLE;
SELECT ok(
    (SELECT count(*) > 0 FROM bmt_db.rls_policy_audit WHERE rls_enabled AND policy_count > 0),
    'RLS policy inventory is non-empty'
);

SELECT * FROM finish();
