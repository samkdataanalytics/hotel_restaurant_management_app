-- ============================================================
-- Migration 002: SaaS Multi-Organization Schema
--
-- Adds:
--   profiles         — user profile + superadmin flag
--   organizations    — company/tenant
--   organization_members — user → org membership
--   Extends hotels table with org_id, type, city, country,
--     email, timezone, logo_url, status columns
--   property_staff   — user → property staff (new sign-ups)
--
-- Run in Supabase SQL editor after 001_multi_tenancy.sql
-- ============================================================


-- ============================================================
-- PART 1 — profiles
-- ============================================================

CREATE TABLE IF NOT EXISTS profiles (
  id           UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name    TEXT        NOT NULL DEFAULT '',
  job_title    TEXT        NOT NULL DEFAULT '',
  phone        TEXT        NOT NULL DEFAULT '',
  avatar_url   TEXT        NOT NULL DEFAULT '',
  is_superadmin BOOLEAN   NOT NULL DEFAULT false,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE profiles IS 'One row per auth user. is_superadmin grants platform-wide access.';

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO profiles (id)
  VALUES (NEW.id)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();


-- ============================================================
-- PART 2 — organizations
-- ============================================================

CREATE TABLE IF NOT EXISTS organizations (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT        NOT NULL,
  slug        TEXT        NOT NULL UNIQUE,
  country     TEXT        NOT NULL DEFAULT '',
  phone       TEXT        NOT NULL DEFAULT '',
  logo_url    TEXT        NOT NULL DEFAULT '',
  plan        TEXT        NOT NULL DEFAULT 'free'
                CHECK (plan IN ('free','pro','enterprise')),
  status      TEXT        NOT NULL DEFAULT 'active'
                CHECK (status IN ('active','suspended')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE organizations IS 'One row per company (SaaS tenant).';


-- ============================================================
-- PART 3 — organization_members
-- ============================================================

CREATE TABLE IF NOT EXISTS organization_members (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id      UUID        NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  user_id     UUID        NOT NULL REFERENCES auth.users(id)    ON DELETE CASCADE,
  role        TEXT        NOT NULL DEFAULT 'member'
                CHECK (role IN ('owner','admin','member')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (org_id, user_id)
);

CREATE INDEX IF NOT EXISTS org_members_user_idx ON organization_members(user_id);
CREATE INDEX IF NOT EXISTS org_members_org_idx  ON organization_members(org_id);


-- ============================================================
-- PART 4 — Extend hotels to be the properties table
-- ============================================================

ALTER TABLE hotels ADD COLUMN IF NOT EXISTS org_id    UUID        REFERENCES organizations(id);
ALTER TABLE hotels ADD COLUMN IF NOT EXISTS type      TEXT        NOT NULL DEFAULT 'hotel';
ALTER TABLE hotels ADD COLUMN IF NOT EXISTS city      TEXT        NOT NULL DEFAULT '';
ALTER TABLE hotels ADD COLUMN IF NOT EXISTS country   TEXT        NOT NULL DEFAULT '';
ALTER TABLE hotels ADD COLUMN IF NOT EXISTS phone     TEXT        NOT NULL DEFAULT '';
ALTER TABLE hotels ADD COLUMN IF NOT EXISTS email     TEXT        NOT NULL DEFAULT '';
ALTER TABLE hotels ADD COLUMN IF NOT EXISTS timezone  TEXT        NOT NULL DEFAULT 'UTC';
ALTER TABLE hotels ADD COLUMN IF NOT EXISTS logo_url  TEXT        NOT NULL DEFAULT '';
ALTER TABLE hotels ADD COLUMN IF NOT EXISTS status    TEXT        NOT NULL DEFAULT 'active';
ALTER TABLE hotels ADD COLUMN IF NOT EXISTS address   TEXT        NOT NULL DEFAULT '';


-- ============================================================
-- PART 5 — property_staff (for new users created via onboarding)
-- ============================================================

CREATE TABLE IF NOT EXISTS property_staff (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID        NOT NULL REFERENCES hotels(id)      ON DELETE CASCADE,
  user_id     UUID        NOT NULL REFERENCES auth.users(id)  ON DELETE CASCADE,
  role        TEXT        NOT NULL DEFAULT 'manager',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (property_id, user_id)
);

CREATE INDEX IF NOT EXISTS property_staff_user_idx     ON property_staff(user_id);
CREATE INDEX IF NOT EXISTS property_staff_property_idx ON property_staff(property_id);


-- ============================================================
-- PART 6 — Superadmin helper
-- ============================================================

-- Call this manually from SQL editor to promote a user:
--   SELECT promote_to_superadmin('admin@example.com');
CREATE OR REPLACE FUNCTION promote_to_superadmin(target_email TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO profiles (id, is_superadmin)
  SELECT id, true
  FROM   auth.users
  WHERE  email = target_email
  ON CONFLICT (id) DO UPDATE SET is_superadmin = true;
END;
$$;

COMMENT ON FUNCTION promote_to_superadmin IS
  'Manually promote a user to platform superadmin by email.';


-- ============================================================
-- PART 7 — Grants
-- ============================================================

GRANT SELECT, INSERT, UPDATE        ON profiles              TO authenticated;
GRANT SELECT, INSERT, UPDATE        ON organizations         TO authenticated;
GRANT SELECT, INSERT, UPDATE        ON organization_members  TO authenticated;
GRANT SELECT, INSERT, UPDATE        ON property_staff        TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON organizations        TO authenticated;


-- ============================================================
-- PART 8 — RLS
-- ============================================================

ALTER TABLE profiles             ENABLE ROW LEVEL SECURITY;
ALTER TABLE organizations        ENABLE ROW LEVEL SECURITY;
ALTER TABLE organization_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE property_staff       ENABLE ROW LEVEL SECURITY;

-- Helper: is this user a superadmin?
CREATE OR REPLACE FUNCTION is_superadmin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT COALESCE(
    (SELECT is_superadmin FROM profiles WHERE id = auth.uid()),
    false
  );
$$;

-- Helper: get the user's org_id
CREATE OR REPLACE FUNCTION current_org_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT org_id
  FROM   organization_members
  WHERE  user_id = auth.uid()
  LIMIT  1;
$$;

-- profiles: user can see/edit own row; superadmins can see all
DROP POLICY IF EXISTS profiles_select ON profiles;
CREATE POLICY profiles_select ON profiles
  FOR SELECT USING (id = auth.uid() OR is_superadmin());

DROP POLICY IF EXISTS profiles_update ON profiles;
CREATE POLICY profiles_update ON profiles
  FOR UPDATE USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS profiles_insert ON profiles;
CREATE POLICY profiles_insert ON profiles
  FOR INSERT WITH CHECK (id = auth.uid());

-- organizations: members can see their org; superadmins see all
DROP POLICY IF EXISTS organizations_select ON organizations;
CREATE POLICY organizations_select ON organizations
  FOR SELECT USING (id = current_org_id() OR is_superadmin());

DROP POLICY IF EXISTS organizations_insert ON organizations;
CREATE POLICY organizations_insert ON organizations
  FOR INSERT WITH CHECK (true);  -- any authenticated user can create an org

DROP POLICY IF EXISTS organizations_update ON organizations;
CREATE POLICY organizations_update ON organizations
  FOR UPDATE USING (id = current_org_id() OR is_superadmin())
  WITH CHECK (id = current_org_id() OR is_superadmin());

-- organization_members: see own row; superadmins see all
DROP POLICY IF EXISTS org_members_select ON organization_members;
CREATE POLICY org_members_select ON organization_members
  FOR SELECT USING (user_id = auth.uid() OR is_superadmin());

DROP POLICY IF EXISTS org_members_insert ON organization_members;
CREATE POLICY org_members_insert ON organization_members
  FOR INSERT WITH CHECK (true);

-- property_staff: see own rows
DROP POLICY IF EXISTS property_staff_select ON property_staff;
CREATE POLICY property_staff_select ON property_staff
  FOR SELECT USING (user_id = auth.uid() OR is_superadmin());

DROP POLICY IF EXISTS property_staff_insert ON property_staff;
CREATE POLICY property_staff_insert ON property_staff
  FOR INSERT WITH CHECK (true);

-- hotels (as properties): org members can see their org's properties; superadmins see all
DROP POLICY IF EXISTS hotels_org_select ON hotels;
CREATE POLICY hotels_org_select ON hotels
  FOR SELECT USING (
    org_id = current_org_id()
    OR id = current_hotel_id()
    OR is_superadmin()
  );

-- ============================================================
-- Done.
-- Helper: is the current user a member of the org that owns this property?
-- Used in RLS policies on property_staff_permissions, staff_invites, etc.
CREATE OR REPLACE FUNCTION is_hotel_member(p_hotel_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM   organization_members om
    WHERE  om.user_id = auth.uid()
      AND  om.org_id  = (SELECT org_id FROM hotels WHERE id = p_hotel_id)
  );
$$;

GRANT EXECUTE ON FUNCTION is_hotel_member(UUID) TO authenticated;

-- Next steps:
--   1. Run promote_to_superadmin('your@email.com') to set up the first superadmin
--   2. New users sign up → auto profile created via trigger
--   3. Onboarding flow creates organization + hotel + organization_members + property_staff
-- ============================================================
