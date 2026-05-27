-- ============================================================
-- Migration 054: M-8 — Server-side pending provision application
-- ============================================================
--
-- Previously, refreshAfterOnboarding() in app_auth_provider.dart
-- applied enterprise limits by calling provisionCustomAccessByUserId()
-- which directly updated organizations.plan from the authenticated
-- client. Migration 052 blocked that via a trigger guard.
--
-- Fix: SECURITY DEFINER function that runs as postgres (owner),
-- bypassing the trigger guard legitimately. The function validates
-- the provision against the caller's own email before applying it,
-- so no caller can apply a provision for a different user.
-- ============================================================

CREATE OR REPLACE FUNCTION apply_pending_provision()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_provision RECORD;
  v_org_id    UUID;
BEGIN
  -- Look up a pending provision keyed to the calling user's email
  SELECT pp.*
  INTO   v_provision
  FROM   pending_provisions pp
  JOIN   auth.users u ON lower(u.email) = lower(pp.email)
  WHERE  u.id = auth.uid()
  LIMIT  1;

  IF NOT FOUND THEN
    RETURN; -- No pending provision for this user
  END IF;

  -- Find the user's primary org
  SELECT om.org_id
  INTO   v_org_id
  FROM   organization_members om
  WHERE  om.user_id    = auth.uid()
    AND  (om.is_deleted = FALSE OR om.is_deleted IS NULL)
  ORDER  BY om.created_at
  LIMIT  1;

  IF v_org_id IS NULL THEN
    RETURN; -- User has not created an org yet — caller should retry after org creation
  END IF;

  -- Apply the provision. Runs as postgres (SECURITY DEFINER owner) so the
  -- guard_org_sensitive_columns trigger allows the plan update.
  UPDATE organizations
  SET    plan                  = 'enterprise',
         custom_max_properties = v_provision.max_properties,
         custom_max_users      = v_provision.max_users,
         custom_max_rooms      = v_provision.max_rooms,
         custom_max_tables     = v_provision.max_tables,
         custom_price_monthly  = v_provision.price_monthly,
         custom_price_annually = v_provision.price_annually,
         billing_cycle         = COALESCE(v_provision.billing_cycle, 'monthly')
  WHERE  id = v_org_id;

  -- Clean up so this is idempotent and won't re-apply on next login
  DELETE FROM pending_provisions
  WHERE  lower(email) = lower(v_provision.email);
END;
$$;

GRANT EXECUTE ON FUNCTION apply_pending_provision() TO authenticated;
