BEGIN;

-- Restore the API privileges required by the staff frontend.
-- RLS remains the row-level security boundary.
GRANT USAGE ON SCHEMA bmt_db TO authenticated;

GRANT SELECT ON
    bmt_db.user_profiles,
    bmt_db.user_roles,
    bmt_db.roles,
    bmt_db.user_branches,
    bmt_db.branches
TO authenticated;

COMMIT;
