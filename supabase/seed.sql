-- Local-only fixtures for SQL regression tests.
-- These users are synthetic and must never be used as production identities.
BEGIN;

INSERT INTO auth.users (id)
VALUES
    ('e088ce1d-fb7c-47aa-a15d-7dfa779d7583'),
    ('570893f3-26dd-44d7-9308-34314250e39c'),
    ('8c3c600e-6865-4c4b-b15a-fb8001960704'),
    ('c6f40c04-6914-4494-9390-7526b953e982')
ON CONFLICT (id) DO NOTHING;

INSERT INTO bmt_db.user_profiles (id, employee_no, full_name, email, is_active)
VALUES
    ('e088ce1d-fb7c-47aa-a15d-7dfa779d7583', 'DEMO-SA', 'Demo Superadmin', 'demo.superadmin@example.test', TRUE),
    ('570893f3-26dd-44d7-9308-34314250e39c', 'DEMO-MGR', 'Demo Manager', 'demo.manager@example.test', TRUE),
    ('8c3c600e-6865-4c4b-b15a-fb8001960704', 'DEMO-MKT', 'Demo Marketing', 'demo.marketing@example.test', TRUE),
    ('c6f40c04-6914-4494-9390-7526b953e982', 'DEMO-TLR', 'Demo Teller', 'demo.teller@example.test', TRUE)
ON CONFLICT (id) DO UPDATE
SET full_name = EXCLUDED.full_name,
    email = EXCLUDED.email,
    is_active = EXCLUDED.is_active;

INSERT INTO bmt_db.user_branches (user_id, branch_id, is_primary, assigned_by)
SELECT v.user_id, b.id, TRUE, NULL
FROM (VALUES
    ('e088ce1d-fb7c-47aa-a15d-7dfa779d7583'::uuid),
    ('570893f3-26dd-44d7-9308-34314250e39c'::uuid),
    ('8c3c600e-6865-4c4b-b15a-fb8001960704'::uuid),
    ('c6f40c04-6914-4494-9390-7526b953e982'::uuid)
) AS v(user_id)
JOIN bmt_db.branches b ON b.code = '001'
ON CONFLICT (user_id, branch_id) DO UPDATE
SET is_primary = EXCLUDED.is_primary;

INSERT INTO bmt_db.user_roles (user_id, role_id, branch_id, is_active, assigned_by)
SELECT v.user_id, r.id, b.id, TRUE, NULL
FROM (VALUES
    ('e088ce1d-fb7c-47aa-a15d-7dfa779d7583'::uuid, 'SUPERADMIN'::text),
    ('570893f3-26dd-44d7-9308-34314250e39c'::uuid, 'MANAGER'::text),
    ('8c3c600e-6865-4c4b-b15a-fb8001960704'::uuid, 'MARKETING'::text),
    ('c6f40c04-6914-4494-9390-7526b953e982'::uuid, 'TELLER'::text)
) AS v(user_id, role_code)
JOIN bmt_db.roles r ON r.code = v.role_code
JOIN bmt_db.branches b ON b.code = '001'
ON CONFLICT (user_id, role_id, branch_id)
    WHERE branch_id IS NOT NULL AND is_active = TRUE
DO UPDATE
SET is_active = EXCLUDED.is_active;

COMMIT;
