-- ─────────────────────────────────────────────────────────────────────────────
-- 029_get_my_properties_fn.sql
-- Adds a SECURITY DEFINER RPC that returns all properties accessible to the
-- calling user. Bypasses RLS so it works regardless of which policies are
-- active (pre- or post-028 soft-delete migration).
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION get_my_properties()
RETURNS SETOF hotels
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  RETURN QUERY
    SELECT DISTINCT h.*
    FROM hotels h
    WHERE
      -- Exclude soft-deleted hotels (ignore column if it doesn't exist yet)
      (
        NOT EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_name = 'hotels' AND column_name = 'is_deleted'
        )
        OR h.is_deleted = FALSE
      )
      AND (
        -- Via property_staff
        h.id IN (
          SELECT ps.property_id FROM property_staff ps
          WHERE ps.user_id = v_user_id
        )
        -- Via hotel_users (legacy)
        OR h.id IN (
          SELECT hu.hotel_id FROM hotel_users hu
          WHERE hu.user_id = v_user_id
        )
        -- Via org membership (owner fallback)
        OR h.org_id IN (
          SELECT om.org_id FROM organization_members om
          WHERE om.user_id = v_user_id
        )
      )
    ORDER BY h.created_at;
END;
$$;

GRANT EXECUTE ON FUNCTION get_my_properties() TO authenticated;
