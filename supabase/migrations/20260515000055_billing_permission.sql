-- ============================================================
-- Migration 055: Billing permission on org members
-- ============================================================
--
-- Previously payhere-hash allowed any org owner OR admin to
-- initiate a plan upgrade. Owners now have full control:
--   - Only owners can upgrade by default
--   - Owners can explicitly grant can_manage_billing to specific
--     members (any role), giving them upgrade access
--   - The permission is revokable at any time
-- ============================================================

-- ── 1. Add the column ─────────────────────────────────────────────────────────
ALTER TABLE organization_members
  ADD COLUMN IF NOT EXISTS can_manage_billing BOOLEAN NOT NULL DEFAULT false;

-- ── 2. Guard: only org owners may grant/revoke billing permission ─────────────
CREATE OR REPLACE FUNCTION guard_billing_permission()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Bypass for service_role, postgres, migrations
  IF current_user IN ('postgres', 'supabase_admin', 'service_role') THEN
    RETURN NEW;
  END IF;

  -- Superadmins may always change it
  IF is_superadmin() THEN
    RETURN NEW;
  END IF;

  -- Only check when can_manage_billing is actually being changed
  IF NEW.can_manage_billing IS DISTINCT FROM OLD.can_manage_billing THEN
    IF NOT EXISTS (
      SELECT 1 FROM organization_members om
      WHERE  om.org_id     = NEW.org_id
        AND  om.user_id    = auth.uid()
        AND  om.role       = 'owner'
        AND  (om.is_deleted = FALSE OR om.is_deleted IS NULL)
    ) THEN
      RAISE EXCEPTION 'Only org owners can grant or revoke billing permission.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_billing_permission ON organization_members;
CREATE TRIGGER trg_guard_billing_permission
  BEFORE UPDATE ON organization_members
  FOR EACH ROW EXECUTE FUNCTION guard_billing_permission();
