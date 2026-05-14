-- ============================================================
-- Migration 011: Fix existing staff accounts created before 010
--
-- Migration 010 added the p_role parameter to create_staff_member
-- and the add_staff_to_property function. However, accounts
-- created BEFORE 010 still have role='manager' forced to 'staff'
-- by the old hardcoded INSERT.
--
-- This migration is intentionally non-destructive:
--   - It does NOT change any role automatically (roles are
--     intentional choices — admins must set them explicitly).
--   - It provides a helper function: set_staff_role()
--     that admins can call to fix specific accounts.
--   - It provides a diagnostic view: staff_role_summary
--     so you can see the current state.
--
-- AFTER running this migration, go to Team Members in the app
-- and use the "Change Role" action (added below), or run:
--
--   SELECT set_staff_role('<property_id>', '<user_id>', 'manager');
--
-- ============================================================


-- ============================================================
-- PART 1 — Helper: set_staff_role
-- Allows an admin to update an existing staff member's role
-- for a specific property without recreating the account.
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

  UPDATE property_staff
  SET    role = p_role
  WHERE  property_id = p_property_id
  AND    user_id     = p_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No property_staff row found for property % / user %.', p_property_id, p_user_id;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION set_staff_role(UUID, UUID, TEXT)
  TO service_role, authenticated;


-- ============================================================
-- PART 2 — Diagnostic view: staff_role_summary
-- Run: SELECT * FROM staff_role_summary;
-- to see all staff members and their current roles.
-- ============================================================

CREATE OR REPLACE VIEW staff_role_summary AS
SELECT
  ps.property_id,
  h.name        AS property_name,
  ps.user_id,
  p.username,
  p.full_name,
  ps.role,
  ps.created_at AS assigned_at
FROM property_staff ps
JOIN hotels  h ON h.id = ps.property_id
JOIN profiles p ON p.id = ps.user_id
ORDER BY h.name, p.username;

GRANT SELECT ON staff_role_summary TO authenticated;


-- ============================================================
-- Done.
--
-- Diagnostic SQL to run in Supabase SQL editor:
--
--   -- See all staff and their roles:
--   SELECT * FROM staff_role_summary;
--
--   -- Fix a specific account's role to manager:
--   SELECT set_staff_role('<property_id>', '<user_id>', 'manager');
--
--   -- Verify property_staff rows for a user:
--   SELECT ps.property_id, h.name, ps.role
--   FROM property_staff ps
--   JOIN hotels h ON h.id = ps.property_id
--   WHERE ps.user_id = '<user_id>';
-- ============================================================
