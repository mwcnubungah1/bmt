-- ============================================================
-- BMT CORE BANKING SYSTEM
-- Migration : 002_bmt_identity.sql
-- Purpose   : Branch, user profile, role and authorization
-- Version   : 1.0.0
-- Requires  : 001_bmt_schema.sql
-- ============================================================

BEGIN;

-- ============================================================
-- 1. BRANCHES
-- ============================================================

CREATE TABLE bmt_db.branches (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    code                VARCHAR(3) NOT NULL,
    name                VARCHAR(150) NOT NULL,

    branch_type         bmt_db.branch_type NOT NULL DEFAULT 'BRANCH',

    parent_branch_id    UUID NULL,

    address             TEXT NULL,
    phone               VARCHAR(30) NULL,
    email               VARCHAR(255) NULL,

    is_active           BOOLEAN NOT NULL DEFAULT TRUE,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uq_branches_code
        UNIQUE (code),

    CONSTRAINT ck_branches_code
        CHECK (code ~ '^[0-9]{3}$'),

    CONSTRAINT ck_branches_name_not_blank
        CHECK (btrim(name) <> ''),

    CONSTRAINT fk_branches_parent
        FOREIGN KEY (parent_branch_id)
        REFERENCES bmt_db.branches(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT ck_branches_not_self_parent
        CHECK (
            parent_branch_id IS NULL
            OR parent_branch_id <> id
        )
);

COMMENT ON TABLE bmt_db.branches IS
'Master kantor pusat, cabang, dan kantor kas BMT.';

COMMENT ON COLUMN bmt_db.branches.code IS
'Kode kantor 3 digit yang dapat menjadi bagian nomor rekening.';


-- ============================================================
-- 2. USER PROFILES
-- ============================================================
-- Authentication identity remains owned by Supabase auth.users.
-- This table stores BMT-specific employee/user information.

CREATE TABLE bmt_db.user_profiles (
    id                  UUID PRIMARY KEY,

    employee_no         VARCHAR(30) NULL,
    full_name           VARCHAR(150) NOT NULL,

    phone               VARCHAR(30) NULL,
    email               VARCHAR(255) NULL,

    is_active           BOOLEAN NOT NULL DEFAULT TRUE,

    last_login_at       TIMESTAMPTZ NULL,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_user_profiles_auth_user
        FOREIGN KEY (id)
        REFERENCES auth.users(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT uq_user_profiles_employee_no
        UNIQUE (employee_no),

    CONSTRAINT ck_user_profiles_name_not_blank
        CHECK (btrim(full_name) <> ''),

    CONSTRAINT ck_user_profiles_employee_no_not_blank
        CHECK (
            employee_no IS NULL
            OR btrim(employee_no) <> ''
        )
);

COMMENT ON TABLE bmt_db.user_profiles IS
'Profil user BMT yang terhubung 1:1 dengan Supabase auth.users.';


-- ============================================================
-- 3. ROLES
-- ============================================================

CREATE TABLE bmt_db.roles (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    code                VARCHAR(50) NOT NULL,
    name                VARCHAR(100) NOT NULL,
    description         TEXT NULL,

    is_system           BOOLEAN NOT NULL DEFAULT FALSE,
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uq_roles_code
        UNIQUE (code),

    CONSTRAINT ck_roles_code
        CHECK (code ~ '^[A-Z][A-Z0-9_]*$'),

    CONSTRAINT ck_roles_name_not_blank
        CHECK (btrim(name) <> '')
);

COMMENT ON TABLE bmt_db.roles IS
'Role bisnis dan sistem BMT.';


-- ============================================================
-- 4. PERMISSIONS
-- ============================================================

CREATE TABLE bmt_db.permissions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    code                VARCHAR(100) NOT NULL,
    module              VARCHAR(50) NOT NULL,
    description         TEXT NULL,

    is_active           BOOLEAN NOT NULL DEFAULT TRUE,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uq_permissions_code
        UNIQUE (code),

    CONSTRAINT ck_permissions_code
        CHECK (
            code ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'
        ),

    CONSTRAINT ck_permissions_module
        CHECK (
            module ~ '^[a-z][a-z0-9_]*$'
        )
);

COMMENT ON TABLE bmt_db.permissions IS
'Atomic authorization permissions used by RBAC.';


-- ============================================================
-- 5. ROLE PERMISSIONS
-- ============================================================

CREATE TABLE bmt_db.role_permissions (
    role_id             UUID NOT NULL,
    permission_id       UUID NOT NULL,

    granted_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    granted_by          UUID NULL,

    PRIMARY KEY (role_id, permission_id),

    CONSTRAINT fk_role_permissions_role
        FOREIGN KEY (role_id)
        REFERENCES bmt_db.roles(id)
        ON UPDATE RESTRICT
        ON DELETE CASCADE,

    CONSTRAINT fk_role_permissions_permission
        FOREIGN KEY (permission_id)
        REFERENCES bmt_db.permissions(id)
        ON UPDATE RESTRICT
        ON DELETE CASCADE,

    CONSTRAINT fk_role_permissions_granted_by
        FOREIGN KEY (granted_by)
        REFERENCES bmt_db.user_profiles(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT
);

COMMENT ON TABLE bmt_db.role_permissions IS
'Mapping many-to-many role terhadap permission.';


-- ============================================================
-- 6. USER BRANCHES
-- ============================================================

CREATE TABLE bmt_db.user_branches (
    user_id             UUID NOT NULL,
    branch_id           UUID NOT NULL,

    is_primary          BOOLEAN NOT NULL DEFAULT FALSE,

    assigned_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    assigned_by         UUID NULL,

    PRIMARY KEY (user_id, branch_id),

    CONSTRAINT fk_user_branches_user
        FOREIGN KEY (user_id)
        REFERENCES bmt_db.user_profiles(id)
        ON UPDATE RESTRICT
        ON DELETE CASCADE,

    CONSTRAINT fk_user_branches_branch
        FOREIGN KEY (branch_id)
        REFERENCES bmt_db.branches(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_user_branches_assigned_by
        FOREIGN KEY (assigned_by)
        REFERENCES bmt_db.user_profiles(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT
);

COMMENT ON TABLE bmt_db.user_branches IS
'Cabang yang boleh diakses seorang user.';


-- ============================================================
-- 7. USER ROLES
-- ============================================================

CREATE TABLE bmt_db.user_roles (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id             UUID NOT NULL,
    role_id             UUID NOT NULL,

    -- NULL means global/system scope.
    -- Branch-scoped roles normally contain branch_id.
    branch_id           UUID NULL,

    is_active           BOOLEAN NOT NULL DEFAULT TRUE,

    valid_from          TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until         TIMESTAMPTZ NULL,

    assigned_by         UUID NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_user_roles_user
        FOREIGN KEY (user_id)
        REFERENCES bmt_db.user_profiles(id)
        ON UPDATE RESTRICT
        ON DELETE CASCADE,

    CONSTRAINT fk_user_roles_role
        FOREIGN KEY (role_id)
        REFERENCES bmt_db.roles(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_user_roles_branch
        FOREIGN KEY (branch_id)
        REFERENCES bmt_db.branches(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_user_roles_assigned_by
        FOREIGN KEY (assigned_by)
        REFERENCES bmt_db.user_profiles(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT ck_user_roles_validity
        CHECK (
            valid_until IS NULL
            OR valid_until > valid_from
        )
);

COMMENT ON TABLE bmt_db.user_roles IS
'Assignment role kepada user, optionally scoped per branch.';


-- ============================================================
-- 8. INDEXES
-- ============================================================

CREATE INDEX idx_branches_parent
    ON bmt_db.branches(parent_branch_id);

CREATE INDEX idx_branches_active
    ON bmt_db.branches(is_active);

CREATE INDEX idx_user_profiles_active
    ON bmt_db.user_profiles(is_active);

CREATE INDEX idx_roles_active
    ON bmt_db.roles(is_active);

CREATE INDEX idx_permissions_module
    ON bmt_db.permissions(module);

CREATE INDEX idx_role_permissions_permission
    ON bmt_db.role_permissions(permission_id);

CREATE INDEX idx_user_branches_branch
    ON bmt_db.user_branches(branch_id);

CREATE INDEX idx_user_roles_user
    ON bmt_db.user_roles(user_id);

CREATE INDEX idx_user_roles_role
    ON bmt_db.user_roles(role_id);

CREATE INDEX idx_user_roles_branch
    ON bmt_db.user_roles(branch_id);

CREATE INDEX idx_user_roles_active
    ON bmt_db.user_roles(user_id, is_active);


-- ============================================================
-- 9. ONLY ONE PRIMARY BRANCH PER USER
-- ============================================================

CREATE UNIQUE INDEX uq_user_branches_one_primary
    ON bmt_db.user_branches(user_id)
    WHERE is_primary = TRUE;


-- ============================================================
-- 10. PREVENT DUPLICATE ACTIVE ROLE ASSIGNMENT
-- ============================================================
-- PostgreSQL UNIQUE treats NULL values as distinct.
-- We therefore use two partial unique indexes.

CREATE UNIQUE INDEX uq_user_roles_global
    ON bmt_db.user_roles(user_id, role_id)
    WHERE branch_id IS NULL
      AND is_active = TRUE;

CREATE UNIQUE INDEX uq_user_roles_branch
    ON bmt_db.user_roles(user_id, role_id, branch_id)
    WHERE branch_id IS NOT NULL
      AND is_active = TRUE;


-- ============================================================
-- 11. UPDATED_AT FUNCTION
-- ============================================================

CREATE OR REPLACE FUNCTION bmt_db.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;


-- ============================================================
-- 12. UPDATED_AT TRIGGERS
-- ============================================================

CREATE TRIGGER trg_branches_updated_at
BEFORE UPDATE ON bmt_db.branches
FOR EACH ROW
EXECUTE FUNCTION bmt_db.set_updated_at();

CREATE TRIGGER trg_user_profiles_updated_at
BEFORE UPDATE ON bmt_db.user_profiles
FOR EACH ROW
EXECUTE FUNCTION bmt_db.set_updated_at();

CREATE TRIGGER trg_roles_updated_at
BEFORE UPDATE ON bmt_db.roles
FOR EACH ROW
EXECUTE FUNCTION bmt_db.set_updated_at();

CREATE TRIGGER trg_permissions_updated_at
BEFORE UPDATE ON bmt_db.permissions
FOR EACH ROW
EXECUTE FUNCTION bmt_db.set_updated_at();


-- ============================================================
-- 13. BASE SECURITY
-- ============================================================
-- No table privileges are granted to anon/authenticated yet.
-- Explicit grants + RLS come later.

REVOKE ALL ON ALL TABLES IN SCHEMA bmt_db FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA bmt_db FROM PUBLIC;


COMMIT;
