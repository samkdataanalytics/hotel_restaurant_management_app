-- ============================================================
-- 007_create_staff_member_fn.sql
-- SECURITY DEFINER helper called by the create-staff-account
-- Edge Function after the auth user is created.
-- Runs with owner (postgres) privileges — no service_role
-- table-grant issues.
-- ============================================================

CREATE OR REPLACE FUNCTION create_staff_member(
  p_user_id     UUID,
  p_username    TEXT,
  p_email       TEXT,
  p_property_id UUID,
  p_org_id      UUID,
  p_permissions JSONB DEFAULT '{}'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Upsert profile
  INSERT INTO profiles (id, full_name, username, email)
  VALUES (p_user_id, p_username, lower(p_username), p_email)
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    username  = EXCLUDED.username,
    email     = EXCLUDED.email;

  -- Add to organization (ignore if already a member)
  INSERT INTO organization_members (org_id, user_id, role)
  VALUES (p_org_id, p_user_id, 'member')
  ON CONFLICT (org_id, user_id) DO NOTHING;

  -- Add to property_staff (ignore if already added)
  INSERT INTO property_staff (property_id, user_id, role)
  VALUES (p_property_id, p_user_id, 'staff')
  ON CONFLICT (property_id, user_id) DO NOTHING;

  -- Add per-section permissions from the JSONB map
  INSERT INTO property_staff_permissions (property_id, user_id, section, privilege)
  SELECT p_property_id, p_user_id, key, value
  FROM   jsonb_each_text(p_permissions)
  ON CONFLICT (property_id, user_id, section)
    DO UPDATE SET privilege = EXCLUDED.privilege;
END;
$$;

-- Callable by both service_role (edge function) and authenticated users
GRANT EXECUTE ON FUNCTION create_staff_member TO service_role, authenticated;
