-- ─────────────────────────────────────────────────────────────────────────────
-- 035_fix_property_visibility.sql
--
-- Problem: get_my_properties() and my_accessible_hotel_ids() both show ALL
-- properties in an org to ANY org member, including regular staff.
-- Staff should only see properties they are explicitly assigned to via
-- property_staff.
--
-- Fix: Restrict the org-membership fallback to owner/admin roles only.
-- Regular members/staff will only see properties via property_staff or
-- hotel_users (legacy).
-- ─────────────────────────────────────────────────────────────────────────────

-- ── 1. Fix get_my_properties() RPC ──────────────────────────────────────────

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
      -- Exclude soft-deleted hotels
      (
        NOT EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_name = 'hotels' AND column_name = 'is_deleted'
        )
        OR h.is_deleted = FALSE
      )
      AND (
        -- Path 1: Direct property assignment (property_staff)
        h.id IN (
          SELECT ps.property_id FROM property_staff ps
          WHERE ps.user_id = v_user_id
            AND (ps.is_deleted = FALSE OR ps.is_deleted IS NULL)
        )
        -- Path 2: Legacy hotel_users
        OR h.id IN (
          SELECT hu.hotel_id FROM hotel_users hu
          WHERE hu.user_id = v_user_id
        )
        -- Path 3: Org owner/admin only — they see ALL org properties
        OR h.org_id IN (
          SELECT om.org_id FROM organization_members om
          WHERE om.user_id = v_user_id
            AND om.role IN ('owner', 'admin')
            AND (om.is_deleted = FALSE OR om.is_deleted IS NULL)
        )
      )
    ORDER BY h.created_at;
END;
$$;

-- ── 2. Fix my_accessible_hotel_ids() (used by RLS policies on
--    notifications, hotels, etc.) ────────────────────────────────────────────

CREATE OR REPLACE FUNCTION my_accessible_hotel_ids()
RETURNS UUID[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT ARRAY(
    SELECT DISTINCT sub.hotel_id
    FROM (
      -- (a) direct property_staff row
      SELECT ps.property_id AS hotel_id
      FROM property_staff ps
      WHERE ps.user_id    = auth.uid()
        AND (ps.is_deleted = FALSE OR ps.is_deleted IS NULL)

      UNION ALL

      -- (b) org owner/admin → all non-deleted hotels in the same org
      SELECT h.id AS hotel_id
      FROM hotels h
      JOIN organization_members om ON om.org_id = h.org_id
      WHERE om.user_id    = auth.uid()
        AND om.role IN ('owner', 'admin')
        AND (om.is_deleted = FALSE OR om.is_deleted IS NULL)
        AND (h.is_deleted = FALSE OR h.is_deleted IS NULL)

      UNION ALL

      -- (c) legacy hotel_users row
      SELECT hu.hotel_id
      FROM hotel_users hu
      WHERE hu.user_id = auth.uid()
    ) sub
  )
$$;
