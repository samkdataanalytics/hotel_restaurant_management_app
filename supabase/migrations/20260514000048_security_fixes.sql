-- ============================================================
-- Migration 048: Security hardening fixes
-- ============================================================

-- ── C-2: Tighten staff_invites UPDATE ────────────────────────
-- Previous policy was USING (true) — any authenticated user
-- could modify any invite across any org. Restrict to property
-- members and superadmins only.
-- Wrapped in DO block because the table may not exist on all deployments.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'staff_invites'
  ) THEN
    DROP POLICY IF EXISTS si_update ON staff_invites;

    EXECUTE $pol$
      CREATE POLICY si_update ON staff_invites
        FOR UPDATE USING (
          is_hotel_member(property_id) OR is_superadmin()
        ) WITH CHECK (
          is_hotel_member(property_id) OR is_superadmin()
        )
    $pol$;
  END IF;
END;
$$;


-- ── H-5: Restrict username lookup to authenticated only ───────
-- get_email_by_username was callable by anon — username enumeration oracle.
REVOKE EXECUTE ON FUNCTION get_email_by_username(TEXT) FROM anon;

-- ── M-4: Restrict username resolver to authenticated only ─────
-- resolve_staff_username was callable by anon — username existence enumeration.
REVOKE EXECUTE ON FUNCTION resolve_staff_username(TEXT) FROM anon;


-- ── M-1: Fix is_hotel_member to exclude soft-deleted members ──
-- Previously did not filter is_deleted, so removed org members
-- retained RLS access to property_staff_permissions etc.
CREATE OR REPLACE FUNCTION is_hotel_member(p_hotel_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM   organization_members om
    WHERE  om.user_id = auth.uid()
      AND  om.org_id  = (SELECT org_id FROM hotels WHERE id = p_hotel_id)
      AND  (om.is_deleted = FALSE OR om.is_deleted IS NULL)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION is_hotel_member(UUID) TO authenticated;


-- ── M-2: Revoke SECURITY DEFINER staff RPCs from authenticated ─
-- create_staff_member and add_staff_to_property bypass RLS and
-- had no caller authorization check — any authenticated user
-- could escalate themselves to manager on any property.
-- Edge Functions use service_role key so they are unaffected.
REVOKE EXECUTE ON FUNCTION create_staff_member(UUID, TEXT, TEXT, UUID, UUID, JSONB, TEXT)    FROM authenticated;
REVOKE EXECUTE ON FUNCTION add_staff_to_property(UUID, UUID, TEXT, JSONB)                    FROM authenticated;


-- ── L-3: Remove unnecessary INSERT/UPDATE on payhere_orders ───
-- Authenticated users only need SELECT. INSERT/UPDATE is done
-- exclusively by the payhere-hash Edge Function via service_role.
REVOKE INSERT, UPDATE ON TABLE payhere_orders FROM authenticated;
GRANT  SELECT         ON TABLE payhere_orders TO  authenticated;


-- ── M-5: Restrict cancel_guest_order to authenticated only ────
-- Any anon could cancel any order by UUID. Restrict to
-- authenticated sessions (staff or known guest session).
REVOKE EXECUTE ON FUNCTION cancel_guest_order(UUID) FROM anon;
