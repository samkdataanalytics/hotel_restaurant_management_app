-- ============================================================
-- Migration 010: Role support + multi-property assignment
--
-- Changes:
--   1. Update create_staff_member() — add p_role parameter
--      (default 'staff'). Managers skip per-section permissions.
--   2. New add_staff_to_property() — assign an existing staff
--      user to an additional property without recreating the
--      auth account.
--
-- Run in Supabase SQL editor after 009_simplify_usernames.sql
-- ============================================================


-- ============================================================
-- PART 1 — Update create_staff_member with p_role
--
-- PostgreSQL cannot change a function signature with
-- CREATE OR REPLACE when the param list changes, so we
-- DROP first (same pattern as migration 009).
-- ============================================================

DROP FUNCTION IF EXISTS create_staff_member(UUID, TEXT, TEXT, UUID, UUID, JSONB);

CREATE FUNCTION create_staff_member(
  p_user_id     UUID,
  p_username    TEXT,
  p_email       TEXT,
  p_property_id UUID,
  p_org_id      UUID,
  p_permissions JSONB DEFAULT '{}',
  p_role        TEXT DEFAULT 'staff'
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_final_username TEXT;
BEGIN
  -- ── Step 1: Resolve globally unique username ────────────────
  v_final_username := resolve_staff_username(p_username);

  -- ── Step 2: Upsert profile ──────────────────────────────────
  INSERT INTO profiles (id, full_name, username, email)
  VALUES (p_user_id, v_final_username, v_final_username, p_email)
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    username  = EXCLUDED.username,
    email     = EXCLUDED.email;

  -- ── Step 3: Organization membership ────────────────────────
  INSERT INTO organization_members (org_id, user_id, role)
  VALUES (p_org_id, p_user_id, 'member')
  ON CONFLICT (org_id, user_id) DO NOTHING;

  -- ── Step 4: Property staff membership (with role) ──────────
  INSERT INTO property_staff (property_id, user_id, role)
  VALUES (p_property_id, p_user_id, p_role)
  ON CONFLICT (property_id, user_id) DO UPDATE SET role = EXCLUDED.role;

  -- ── Step 5: Per-section permissions (staff only) ───────────
  -- Managers have full access — storing granular permissions
  -- for them is unnecessary and would show wrong data in UI.
  IF p_role != 'manager' THEN
    INSERT INTO property_staff_permissions (property_id, user_id, section, privilege)
    SELECT p_property_id, p_user_id, key, value
    FROM   jsonb_each_text(p_permissions)
    ON CONFLICT (property_id, user_id, section)
      DO UPDATE SET privilege = EXCLUDED.privilege;
  END IF;

  RETURN v_final_username;
END;
$$;

GRANT EXECUTE ON FUNCTION create_staff_member(UUID, TEXT, TEXT, UUID, UUID, JSONB, TEXT)
  TO service_role, authenticated;


-- ============================================================
-- PART 2 — add_staff_to_property
--
-- Assigns an EXISTING staff user (already has an auth account)
-- to an additional property. Used by the edge function when
-- the admin selects multiple properties during account creation,
-- and also available for assigning staff to new properties later.
-- ============================================================

CREATE OR REPLACE FUNCTION add_staff_to_property(
  p_user_id     UUID,
  p_property_id UUID,
  p_role        TEXT DEFAULT 'staff',
  p_permissions JSONB DEFAULT '{}'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Add or update property staff membership
  INSERT INTO property_staff (property_id, user_id, role)
  VALUES (p_property_id, p_user_id, p_role)
  ON CONFLICT (property_id, user_id) DO UPDATE SET role = EXCLUDED.role;

  -- Per-section permissions (staff only)
  IF p_role != 'manager' THEN
    INSERT INTO property_staff_permissions (property_id, user_id, section, privilege)
    SELECT p_property_id, p_user_id, key, value
    FROM   jsonb_each_text(p_permissions)
    ON CONFLICT (property_id, user_id, section)
      DO UPDATE SET privilege = EXCLUDED.privilege;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION add_staff_to_property(UUID, UUID, TEXT, JSONB)
  TO service_role, authenticated;


-- ============================================================
-- Done.
--
-- Edge function (create-staff-account) must be updated to:
--   - Accept 'role' (default 'staff')
--   - Accept 'additionalPropertyIds' string array
--   - Pass p_role to create_staff_member RPC
--   - Call add_staff_to_property for each additional property
-- ============================================================
