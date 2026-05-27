-- ============================================================
-- Migration 049: H-3 — Fix TOCTOU race in org membership bootstrap
-- ============================================================
--
-- The org_members_insert policy in migration 034 allows the first member
-- to bootstrap an org by checking NOT EXISTS (org has no members). Under
-- PostgreSQL READ COMMITTED isolation two concurrent transactions can both
-- pass that check and both commit, creating two simultaneous "founders".
--
-- Fix: add created_by to organizations and anchor the bootstrap check to
-- the org's declared creator instead of the unstable empty-members test.
-- ============================================================

-- ── 1. Add created_by column ──────────────────────────────────────────────────
ALTER TABLE organizations
  ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id);

-- ── 2. Backfill from earliest owner member ────────────────────────────────────
UPDATE organizations o
SET    created_by = (
  SELECT om.user_id
  FROM   organization_members om
  WHERE  om.org_id     = o.id
    AND  om.role       = 'owner'
    AND  (om.is_deleted = FALSE OR om.is_deleted IS NULL)
  ORDER  BY om.created_at
  LIMIT  1
)
WHERE  created_by IS NULL;

-- ── 3. Auto-set created_by on new org inserts ─────────────────────────────────
CREATE OR REPLACE FUNCTION set_org_created_by()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.created_by IS NULL THEN
    NEW.created_by := auth.uid();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_org_created_by ON organizations;
CREATE TRIGGER trg_org_created_by
  BEFORE INSERT ON organizations
  FOR EACH ROW EXECUTE FUNCTION set_org_created_by();

-- ── 4. Replace org_members_insert policy ─────────────────────────────────────
-- The new Case 1 anchors the bootstrap to created_by (set atomically at org
-- creation time) instead of a NOT EXISTS check that can race.
DROP POLICY IF EXISTS org_members_insert ON organization_members;

CREATE POLICY org_members_insert ON organization_members
  FOR INSERT WITH CHECK (
    is_superadmin()
    OR (
        -- Case 1: Org creator self-bootstrapping (no race — created_by is immutable)
        user_id     = auth.uid()
        AND auth.uid() = (SELECT created_by FROM organizations WHERE id = org_id)
        AND NOT EXISTS (
            SELECT 1 FROM organization_members om
            WHERE  om.org_id     = org_id
              AND  om.role       = 'owner'
              AND  (om.is_deleted = FALSE OR om.is_deleted IS NULL)
        )
    )
    OR (
        -- Case 2: Invited by an existing org owner/admin
        EXISTS (
            SELECT 1 FROM organization_members om
            WHERE  om.org_id     = org_id
              AND  om.user_id    = auth.uid()
              AND  om.role       IN ('owner', 'admin')
              AND  (om.is_deleted = FALSE OR om.is_deleted IS NULL)
        )
    )
  );
