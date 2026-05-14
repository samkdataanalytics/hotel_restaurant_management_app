-- ============================================================
-- Migration 056: Org owners/admins can see all org members
-- ============================================================
--
-- Root cause: org_members_select policy only allows a user to
-- see their OWN row (user_id = auth.uid()). Owners cannot see
-- the other members in their org, so the Billing Access section
-- in Account Settings always shows an empty list.
--
-- Fix: extend the policy to allow any org owner or admin to
-- read all rows belonging to their org.
--
-- To avoid infinite RLS recursion (policy → sub-SELECT on the
-- same table → policy again), the membership check is wrapped
-- in a SECURITY DEFINER function that bypasses RLS.
-- ============================================================

-- ── 1. SECURITY DEFINER helper ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION is_org_owner_or_admin(p_org_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM   organization_members om
    WHERE  om.org_id    = p_org_id
      AND  om.user_id   = auth.uid()
      AND  om.role      IN ('owner', 'admin')
      AND  (om.is_deleted = FALSE OR om.is_deleted IS NULL)
  );
$$;

GRANT EXECUTE ON FUNCTION is_org_owner_or_admin(UUID) TO authenticated;

-- ── 2. Replace SELECT policy ──────────────────────────────────────────────────
DROP POLICY IF EXISTS org_members_select ON organization_members;

CREATE POLICY org_members_select ON organization_members
  FOR SELECT USING (
    -- Own row — any member can always see themselves
    user_id = auth.uid()
    -- Superadmin sees everything
    OR is_superadmin()
    -- Org owners and admins can see all members in their org
    OR is_org_owner_or_admin(org_id)
  );
