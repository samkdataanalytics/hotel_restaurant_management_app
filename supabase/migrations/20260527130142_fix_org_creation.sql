-- ============================================================
-- Migration 058: Fix org creation — broken RLS circular dependency
--                and add idempotent create_or_recover_organization RPC
-- ============================================================
--
-- Root cause (migration 049): org_members_insert policy checks
-- created_by via a subquery on organizations. But the organizations
-- SELECT policy requires membership, so the subquery returns NULL
-- (RLS filters it), and NULL != auth.uid() fails the policy —
-- causing 42501 on every new org creation attempt.
--
-- Fix 1: get_org_created_by() — SECURITY DEFINER helper that reads
--        organizations.created_by bypassing RLS, breaking the cycle.
-- Fix 2: create_or_recover_organization() — SECURITY DEFINER RPC
--        that creates org + membership atomically, and recovers
--        orphaned orgs (org row exists but membership failed).
-- ============================================================

-- ── Fix 1: Helper to read created_by bypassing RLS ───────────────────────────

CREATE OR REPLACE FUNCTION get_org_created_by(p_org_id UUID)
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT created_by FROM organizations WHERE id = p_org_id;
$$;

REVOKE ALL ON FUNCTION get_org_created_by(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_org_created_by(UUID) TO authenticated;

-- ── Fix 2: Replace org_members_insert policy — use helper for created_by ─────

DROP POLICY IF EXISTS org_members_insert ON organization_members;

CREATE POLICY org_members_insert ON organization_members
  FOR INSERT WITH CHECK (
    is_superadmin()
    OR (
        -- Case 1: Org creator self-bootstrapping.
        -- get_org_created_by() bypasses RLS so we're not blocked by the
        -- "must be a member to read org" rule before we've added membership.
        user_id     = auth.uid()
        AND auth.uid() = get_org_created_by(org_id)
        AND NOT EXISTS (
            SELECT 1 FROM organization_members om
            WHERE  om.org_id     = org_id
              AND  om.role       = 'owner'
              AND  (om.is_deleted = FALSE OR om.is_deleted IS NULL)
        )
    )
    OR (
        -- Case 2: Invited by an existing org owner/admin.
        EXISTS (
            SELECT 1 FROM organization_members om
            WHERE  om.org_id     = org_id
              AND  om.user_id    = auth.uid()
              AND  om.role       IN ('owner', 'admin')
              AND  (om.is_deleted = FALSE OR om.is_deleted IS NULL)
        )
    )
  );

-- ── Fix 3: Idempotent org creation + orphaned-org recovery RPC ───────────────

CREATE OR REPLACE FUNCTION create_or_recover_organization(
  p_name     TEXT,
  p_slug     TEXT,
  p_country  TEXT  DEFAULT '',
  p_phone    TEXT  DEFAULT '',
  p_logo_url TEXT  DEFAULT ''
)
RETURNS SETOF organizations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org_id  UUID;
  v_user_id UUID := auth.uid();
BEGIN
  -- 1. User already has active org membership → idempotent full-retry path.
  SELECT om.org_id INTO v_org_id
  FROM   organization_members om
  WHERE  om.user_id    = v_user_id
    AND  (om.is_deleted = FALSE OR om.is_deleted IS NULL)
  LIMIT  1;

  IF v_org_id IS NOT NULL THEN
    RETURN QUERY SELECT * FROM organizations WHERE id = v_org_id;
    RETURN;
  END IF;

  -- 2. Orphaned org: org row with this slug was created by us in a previous
  --    partial attempt, but the membership INSERT failed. Recover it.
  SELECT id INTO v_org_id
  FROM   organizations
  WHERE  slug       = p_slug
    AND  created_by = v_user_id
  LIMIT  1;

  IF v_org_id IS NOT NULL THEN
    INSERT INTO organization_members (org_id, user_id, role)
    VALUES (v_org_id, v_user_id, 'owner')
    ON CONFLICT DO NOTHING;

    RETURN QUERY SELECT * FROM organizations WHERE id = v_org_id;
    RETURN;
  END IF;

  -- 3. Slug taken by a different user's org — surface a clear error.
  IF EXISTS (SELECT 1 FROM organizations WHERE slug = p_slug) THEN
    RAISE EXCEPTION
      'An organization with this URL already exists. Please try a different company name.';
  END IF;

  -- 4. Create new org + membership atomically.
  INSERT INTO organizations (name, slug, country, phone, logo_url)
  VALUES (p_name, p_slug, p_country, p_phone, p_logo_url)
  RETURNING id INTO v_org_id;

  INSERT INTO organization_members (org_id, user_id, role)
  VALUES (v_org_id, v_user_id, 'owner');

  RETURN QUERY SELECT * FROM organizations WHERE id = v_org_id;
END;
$$;

REVOKE ALL ON FUNCTION create_or_recover_organization(TEXT,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION create_or_recover_organization(TEXT,TEXT,TEXT,TEXT,TEXT) TO authenticated;
