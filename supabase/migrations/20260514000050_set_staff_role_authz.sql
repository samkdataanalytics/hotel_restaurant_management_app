-- ============================================================
-- Migration 050: M-9 — Add authorization check to set_staff_role
-- ============================================================
--
-- set_staff_role is SECURITY DEFINER and was callable by any
-- authenticated user with no ownership check, allowing privilege
-- escalation: any user could promote themselves or others to
-- manager on any property.
--
-- Fix: add an explicit caller authorization guard before the UPDATE.
-- ============================================================

CREATE OR REPLACE FUNCTION set_staff_role(
  p_property_id UUID,
  p_user_id     UUID,
  p_role        TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_role NOT IN ('staff', 'manager') THEN
    RAISE EXCEPTION 'Invalid role "%" — must be ''staff'' or ''manager''.', p_role;
  END IF;

  -- Verify caller is an owner/manager of this property or a superadmin
  IF NOT (
    is_superadmin()
    OR EXISTS (
      SELECT 1 FROM property_staff ps
      WHERE  ps.property_id = p_property_id
        AND  ps.user_id     = auth.uid()
        AND  ps.role        IN ('owner', 'manager')
        AND  (ps.is_deleted = FALSE OR ps.is_deleted IS NULL)
    )
    OR EXISTS (
      SELECT 1 FROM hotels h
      JOIN   organization_members om ON om.org_id = h.org_id
      WHERE  h.id       = p_property_id
        AND  om.user_id = auth.uid()
        AND  om.role    IN ('owner', 'admin')
        AND  (om.is_deleted = FALSE OR om.is_deleted IS NULL)
    )
  ) THEN
    RAISE EXCEPTION 'Not authorized to change staff roles for this property.';
  END IF;

  UPDATE property_staff
  SET    role = p_role
  WHERE  property_id = p_property_id
  AND    user_id     = p_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No property_staff row found for property % / user %.', p_property_id, p_user_id;
  END IF;
END;
$$;
