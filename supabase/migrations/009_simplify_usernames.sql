-- ============================================================
-- Migration 009: Simplify Username Uniqueness
--
-- Migration 008 introduced per-property username scoping which
-- required admins to share a UUID with staff for login.
-- This was too complex for small hotels.
--
-- New approach: usernames are GLOBALLY unique across the platform.
-- Auto-suffix format: test → test_01 → test_02 (zero-padded).
-- Staff log in with just username + password — no property ID.
--
-- Changes:
--   1. Drop property_staff_usernames table (no longer needed).
--   2. Drop two-argument overloads added in migration 008.
--   3. Restore global unique index on profiles(lower(username)).
--   4. New resolve_staff_username(TEXT) — global, _01 format.
--   5. Restore get_email_by_username(TEXT) — single-arg global lookup.
--   6. Update create_staff_member() — uses global resolution.
--      Synthetic email reverts to: {final_username}@staff.internal
--
-- Run in Supabase SQL editor after 008_property_usernames.sql
-- ============================================================


-- ============================================================
-- PART 1 — Drop property_staff_usernames and related objects
-- ============================================================

-- CASCADE drops the trigger and functional indexes automatically
DROP TABLE IF EXISTS property_staff_usernames CASCADE;

-- Drop the trigger function (no longer attached to any table)
DROP FUNCTION IF EXISTS generate_unique_staff_username();


-- ============================================================
-- PART 2 — Drop two-argument overloads from migration 008
-- ============================================================

DROP FUNCTION IF EXISTS resolve_staff_username(TEXT, UUID);
DROP FUNCTION IF EXISTS get_email_by_username(TEXT, UUID);


-- ============================================================
-- PART 3 — Restore global unique index on profiles.username
--
-- Migration 008 Part 4 dropped this. Now that uniqueness is
-- global again, restore it.
-- ============================================================

CREATE UNIQUE INDEX IF NOT EXISTS profiles_username_idx
  ON profiles (lower(username))
  WHERE username IS NOT NULL;


-- ============================================================
-- PART 4 — resolve_staff_username(TEXT)
--
-- Global version. Checks profiles.username across all properties.
-- Suffix format:
--   "test"      (first — no suffix)
--   "test_01"   (second)
--   "test_02"   (third)
--   ...
--   "test_09"   (tenth)
--   "test_10"   (eleventh)
--   etc.
--
-- lpad(n, 2, '0') gives 01-09, then 10-99 naturally.
-- For n >= 100 lpad does not truncate, so 100+ work as-is.
-- ============================================================

CREATE OR REPLACE FUNCTION resolve_staff_username(p_username TEXT)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_base    TEXT;
  v_final   TEXT;
  v_counter INT := 0;
BEGIN
  -- Normalize
  v_base := lower(trim(p_username));
  v_base := regexp_replace(v_base, '[^a-z0-9_]', '_', 'g');
  v_base := regexp_replace(v_base, '_+',          '_', 'g');
  v_base := trim(BOTH '_' FROM v_base);
  IF v_base = '' THEN v_base := 'user'; END IF;

  LOOP
    -- counter = 0 → try bare name; counter >= 1 → append _01, _02 …
    v_final := CASE
      WHEN v_counter = 0 THEN v_base
      ELSE v_base || '_' || lpad(v_counter::TEXT, 2, '0')
    END;

    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM profiles WHERE lower(username) = v_final
    );

    v_counter := v_counter + 1;

    IF v_counter > 9999 THEN
      RAISE EXCEPTION
        'resolve_staff_username: too many variants for "%". '
        'Clean up unused accounts first.', v_base;
    END IF;
  END LOOP;

  RETURN v_final;
END;
$$;

GRANT EXECUTE ON FUNCTION resolve_staff_username(TEXT) TO anon, authenticated;


-- ============================================================
-- PART 5 — get_email_by_username(TEXT)
--
-- Single-argument global lookup. Restored from migration 005
-- with SET search_path added for security best practice.
-- ============================================================

CREATE OR REPLACE FUNCTION get_email_by_username(p_username TEXT)
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT email
  FROM   profiles
  WHERE  lower(username) = lower(p_username)
  LIMIT  1;
$$;

GRANT EXECUTE ON FUNCTION get_email_by_username(TEXT) TO anon, authenticated;


-- ============================================================
-- PART 6 — Update create_staff_member()
--
-- Now calls resolve_staff_username(TEXT) — global resolution.
-- Synthetic email reverts to: {final_username}@staff.internal
-- (safe because final_username is globally unique).
-- Still returns TEXT (the final username) so the edge function
-- can confirm what was actually assigned.
-- ============================================================

DROP FUNCTION IF EXISTS create_staff_member(UUID, TEXT, TEXT, UUID, UUID, JSONB);

CREATE FUNCTION create_staff_member(
  p_user_id     UUID,
  p_username    TEXT,
  p_email       TEXT,
  p_property_id UUID,
  p_org_id      UUID,
  p_permissions JSONB DEFAULT '{}'
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

  -- ── Step 4: Property staff membership ──────────────────────
  INSERT INTO property_staff (property_id, user_id, role)
  VALUES (p_property_id, p_user_id, 'staff')
  ON CONFLICT (property_id, user_id) DO NOTHING;

  -- ── Step 5: Per-section permissions ────────────────────────
  INSERT INTO property_staff_permissions (property_id, user_id, section, privilege)
  SELECT p_property_id, p_user_id, key, value
  FROM   jsonb_each_text(p_permissions)
  ON CONFLICT (property_id, user_id, section)
    DO UPDATE SET privilege = EXCLUDED.privilege;

  RETURN v_final_username;
END;
$$;

GRANT EXECUTE ON FUNCTION create_staff_member(UUID, TEXT, TEXT, UUID, UUID, JSONB)
  TO service_role, authenticated;


-- ============================================================
-- Done.
--
-- Edge function must be updated to use simple email format:
--   email = `${finalUsername}@staff.internal`
-- (No more property-encoded email domain.)
--
-- Login screen reverts to: username + password only.
-- No property ID field needed.
-- ============================================================
