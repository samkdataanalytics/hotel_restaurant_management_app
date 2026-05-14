-- ============================================================
-- 003_staff_permissions.sql
-- Per-section privilege system for property staff
-- Run this in the Supabase SQL editor.
-- ============================================================


-- ─── 1. property_staff_permissions table ─────────────────────────────────────

CREATE TABLE IF NOT EXISTS property_staff_permissions (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID        NOT NULL REFERENCES hotels(id)     ON DELETE CASCADE,
  user_id     UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  section     TEXT        NOT NULL,
  privilege   TEXT        NOT NULL DEFAULT 'none'
              CHECK (privilege IN ('none', 'view', 'edit')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (property_id, user_id, section)
);

CREATE INDEX IF NOT EXISTS psp_property_idx ON property_staff_permissions(property_id);
CREATE INDEX IF NOT EXISTS psp_user_idx     ON property_staff_permissions(user_id);


-- ─── 2. Grants ────────────────────────────────────────────────────────────────

GRANT SELECT, INSERT, UPDATE, DELETE ON property_staff_permissions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON property_staff             TO authenticated;


-- ─── 3. RLS on property_staff_permissions ────────────────────────────────────

ALTER TABLE property_staff_permissions ENABLE ROW LEVEL SECURITY;

-- Any member of the property can read all permissions for that property
-- (needed so managers can load the full staff list with permissions)
DROP POLICY IF EXISTS psp_select ON property_staff_permissions;
CREATE POLICY psp_select ON property_staff_permissions
  FOR SELECT USING (
    user_id = auth.uid()
    OR is_hotel_member(property_id)
    OR is_superadmin()
  );

-- Only property members can insert / update / delete permissions
DROP POLICY IF EXISTS psp_insert ON property_staff_permissions;
CREATE POLICY psp_insert ON property_staff_permissions
  FOR INSERT WITH CHECK (is_hotel_member(property_id) OR is_superadmin());

DROP POLICY IF EXISTS psp_update ON property_staff_permissions;
CREATE POLICY psp_update ON property_staff_permissions
  FOR UPDATE USING (is_hotel_member(property_id) OR is_superadmin());

DROP POLICY IF EXISTS psp_delete ON property_staff_permissions;
CREATE POLICY psp_delete ON property_staff_permissions
  FOR DELETE USING (is_hotel_member(property_id) OR is_superadmin());


-- ─── 4. Expand property_staff SELECT policy ───────────────────────────────────
-- The existing policy only allows users to see their own row.
-- Managers need to see ALL staff for their property.

DROP POLICY IF EXISTS property_staff_select ON property_staff;
CREATE POLICY property_staff_select ON property_staff
  FOR SELECT USING (
    user_id = auth.uid()
    OR is_hotel_member(property_id)
    OR is_superadmin()
  );


-- ─── 5. Add DELETE policy on property_staff ───────────────────────────────────
-- Required so managers can remove staff members.

DROP POLICY IF EXISTS property_staff_delete ON property_staff;
CREATE POLICY property_staff_delete ON property_staff
  FOR DELETE USING (
    is_hotel_member(property_id) OR is_superadmin()
  );


-- ─── 6. Add UPDATE policy on property_staff ───────────────────────────────────

DROP POLICY IF EXISTS property_staff_update ON property_staff;
CREATE POLICY property_staff_update ON property_staff
  FOR UPDATE USING (
    is_hotel_member(property_id) OR is_superadmin()
  );


-- ─── 7. Add email column to profiles + keep it synced ────────────────────────
-- profiles.email is needed so managers can display staff email addresses.

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS email TEXT NOT NULL DEFAULT '';

-- Backfill email from auth.users for existing rows
UPDATE profiles p
SET    email = u.email
FROM   auth.users u
WHERE  p.id = u.id
  AND  p.email = '';

-- Update the signup trigger to also store email
CREATE OR REPLACE FUNCTION create_profile_on_signup()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO profiles (id, email)
  VALUES (NEW.id, NEW.email)
  ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email;
  RETURN NEW;
END;
$$;


-- ─── 8. SECURITY DEFINER function: look up a user's UUID by email ─────────────
-- Clients cannot query auth.users directly; this function bridges the gap.

CREATE OR REPLACE FUNCTION find_user_id_by_email(p_email TEXT)
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT id FROM auth.users WHERE email = p_email LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION find_user_id_by_email TO authenticated;


-- ─── 9. Allow reading profiles within the same property ──────────────────────
-- The existing policy only lets users read their OWN profile.
-- Managers need to see names/emails of their property's staff.

DROP POLICY IF EXISTS profiles_select ON profiles;
CREATE POLICY profiles_select ON profiles
  FOR SELECT USING (
    id = auth.uid()
    OR is_superadmin()
    OR EXISTS (
      SELECT 1
      FROM property_staff ps1
      JOIN property_staff ps2 ON ps2.property_id = ps1.property_id
      WHERE ps1.user_id = auth.uid()
        AND ps2.user_id = profiles.id
    )
  );


-- ─── Done ─────────────────────────────────────────────────────────────────────
-- After running this migration:
--   • Hotel admins can open "Team Members" in the sidebar
--   • They can invite users by email and set per-section privileges
--   • Staff members will only see nav sections they have access to
-- ─────────────────────────────────────────────────────────────────────────────
