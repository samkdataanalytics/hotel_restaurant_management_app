-- ─────────────────────────────────────────────────────────────────────────────
-- 028_soft_delete.sql
-- Adds soft-delete support across all user-facing entities.
-- Records are never physically deleted — instead is_deleted=true + deleted_at
-- are set, and RLS policies exclude them from normal queries.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── profiles ─────────────────────────────────────────────────────────────────
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS is_deleted  BOOLEAN      NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS deleted_at  TIMESTAMPTZ;

-- ── organizations ─────────────────────────────────────────────────────────────
ALTER TABLE organizations
  ADD COLUMN IF NOT EXISTS is_deleted  BOOLEAN      NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS deleted_at  TIMESTAMPTZ;

-- ── hotels (properties) ───────────────────────────────────────────────────────
ALTER TABLE hotels
  ADD COLUMN IF NOT EXISTS is_deleted  BOOLEAN      NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS deleted_at  TIMESTAMPTZ;

-- ── organization_members ──────────────────────────────────────────────────────
ALTER TABLE organization_members
  ADD COLUMN IF NOT EXISTS is_deleted  BOOLEAN      NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS deleted_at  TIMESTAMPTZ;

-- ── property_staff ────────────────────────────────────────────────────────────
ALTER TABLE property_staff
  ADD COLUMN IF NOT EXISTS is_deleted  BOOLEAN      NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS deleted_at  TIMESTAMPTZ;

-- ─────────────────────────────────────────────────────────────────────────────
-- RPC: soft_delete_profile
-- Marks the calling user's profile (and their org + properties if they are the
-- sole owner) as deleted. Auth account is NOT removed — that requires an admin
-- action via the Supabase dashboard or a separate edge function.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION soft_delete_profile()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_org_id  UUID;
  v_members INT;
BEGIN
  -- Mark profile deleted
  UPDATE profiles
  SET is_deleted = TRUE, deleted_at = NOW()
  WHERE id = v_user_id;

  -- If user is the sole owner of an org, soft-delete that org + its properties
  SELECT org_id INTO v_org_id
  FROM organization_members
  WHERE user_id = v_user_id AND role = 'owner' AND is_deleted = FALSE
  LIMIT 1;

  IF v_org_id IS NOT NULL THEN
    -- Count other active owners
    SELECT COUNT(*) INTO v_members
    FROM organization_members
    WHERE org_id = v_org_id
      AND role = 'owner'
      AND user_id <> v_user_id
      AND is_deleted = FALSE;

    IF v_members = 0 THEN
      -- Sole owner — soft-delete org and all its hotels
      UPDATE organizations
      SET is_deleted = TRUE, deleted_at = NOW()
      WHERE id = v_org_id;

      UPDATE hotels
      SET is_deleted = TRUE, deleted_at = NOW()
      WHERE org_id = v_org_id;
    END IF;
  END IF;

  -- Soft-delete all membership rows for this user
  UPDATE organization_members
  SET is_deleted = TRUE, deleted_at = NOW()
  WHERE user_id = v_user_id;

  -- Soft-delete all property_staff rows for this user
  UPDATE property_staff
  SET is_deleted = TRUE, deleted_at = NOW()
  WHERE user_id = v_user_id;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- RPC: soft_delete_property
-- Replaces the old hard-delete RPC.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION soft_delete_property(p_property_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE hotels
  SET is_deleted = TRUE, deleted_at = NOW()
  WHERE id = p_property_id;

  UPDATE property_staff
  SET is_deleted = TRUE, deleted_at = NOW()
  WHERE property_id = p_property_id;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Update key queries to exclude deleted rows
-- (RLS policies)
-- ─────────────────────────────────────────────────────────────────────────────

-- Profiles: only see non-deleted profiles
DROP POLICY IF EXISTS "profiles_select" ON profiles;
CREATE POLICY "profiles_select" ON profiles
  FOR SELECT USING (is_deleted = FALSE);

-- Hotels: only see non-deleted hotels
DROP POLICY IF EXISTS "hotels_select_member" ON hotels;
CREATE POLICY "hotels_select_member" ON hotels
  FOR SELECT USING (
    is_deleted = FALSE
    AND (
      id IN (
        SELECT property_id FROM property_staff
        WHERE user_id = auth.uid() AND is_deleted = FALSE
      )
      OR id IN (
        SELECT h.id FROM hotels h
        JOIN organization_members om ON om.org_id = h.org_id
        WHERE om.user_id = auth.uid() AND om.is_deleted = FALSE
      )
    )
  );

-- Organizations: only see non-deleted orgs
DROP POLICY IF EXISTS "organizations_select_member" ON organizations;
CREATE POLICY "organizations_select_member" ON organizations
  FOR SELECT USING (
    is_deleted = FALSE
    AND id IN (
      SELECT org_id FROM organization_members
      WHERE user_id = auth.uid() AND is_deleted = FALSE
    )
  );
