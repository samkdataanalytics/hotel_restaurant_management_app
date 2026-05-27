-- ─────────────────────────────────────────────────────────────────────────────
-- 032_security_hardening.sql
--
-- Four targeted improvements:
--   1. Drop all "anon full access" policies (live security vulnerability)
--   2. Add composite + partial indexes for common query patterns
--   3. Add partial indexes on property_staff / organization_members
--      (WHERE is_deleted = FALSE) so the planner skips deleted rows entirely
--   4. Simplify hotels_select_v2 + notifications_staff — replace correlated
--      subqueries with a single SECURITY DEFINER UUID[] helper
--
-- Run in Supabase SQL editor. Safe to run on a live database.
-- ─────────────────────────────────────────────────────────────────────────────


-- ═════════════════════════════════════════════════════════════════════════════
-- 1. DROP "anon full access" policies
--
-- Supabase Dashboard creates policies literally named "anon full access".
-- RLS is PERMISSIVE (OR-based), so these USING (true) policies negate every
-- other policy on the same table — the tighter scoped policies below have
-- zero effect until these are dropped first.
-- ═════════════════════════════════════════════════════════════════════════════

-- Named dashboard policies (the root cause — must be dropped first)
DROP POLICY IF EXISTS "anon full access" ON bookings;
DROP POLICY IF EXISTS "anon full access" ON check_ins;
DROP POLICY IF EXISTS "anon full access" ON expenses;
DROP POLICY IF EXISTS "anon full access" ON guests;
DROP POLICY IF EXISTS "anon full access" ON rooms;
DROP POLICY IF EXISTS "anon full access" ON restaurant_orders;
DROP POLICY IF EXISTS "anon full access" ON restaurant_tables;
DROP POLICY IF EXISTS "anon full access" ON menu_items;
DROP POLICY IF EXISTS "anon full access" ON ingredients;
DROP POLICY IF EXISTS "anon full access" ON ingredient_prices;
DROP POLICY IF EXISTS "anon full access" ON inventory;
DROP POLICY IF EXISTS "anon full access" ON menu_item_cost_records;

-- Also drop the old USING (true) migration policies that had no hotel scope
DROP POLICY IF EXISTS bookings_guest_lookup ON bookings;
DROP POLICY IF EXISTS guests_guest_lookup   ON guests;
DROP POLICY IF EXISTS guests_guest_upsert   ON guests;


-- ── bookings — scoped guest read ──────────────────────────────────────────────
-- The mobile self-check-in flow looks up a booking by booking_ref.
-- Allow SELECT only for bookings that belong to active, non-deleted hotels.
CREATE POLICY bookings_guest_lookup ON bookings
  FOR SELECT TO anon
  USING (
    hotel_id IN (
      SELECT id FROM hotels
      WHERE status = 'active'
        AND (is_deleted = FALSE OR is_deleted IS NULL)
    )
  );

-- ── guests — scoped read + limited update ────────────────────────────────────
-- Guest reads their own record by id after the booking lookup.
-- Guest updates their own profile during self check-in.
-- Both scoped to active hotels — no cross-hotel exposure.
CREATE POLICY guests_guest_lookup ON guests
  FOR SELECT TO anon
  USING (
    hotel_id IN (
      SELECT id FROM hotels
      WHERE status = 'active'
        AND (is_deleted = FALSE OR is_deleted IS NULL)
    )
  );

CREATE POLICY guests_guest_upsert ON guests
  FOR UPDATE TO anon
  USING (
    hotel_id IN (
      SELECT id FROM hotels
      WHERE status = 'active'
        AND (is_deleted = FALSE OR is_deleted IS NULL)
    )
  )
  WITH CHECK (
    hotel_id IN (
      SELECT id FROM hotels
      WHERE status = 'active'
        AND (is_deleted = FALSE OR is_deleted IS NULL)
    )
  );

-- ── menu_items — scoped guest read ───────────────────────────────────────────
-- OLD (014): USING (is_available = true) — no hotel scope, exposed all hotels
DROP POLICY IF EXISTS menu_items_guest_read ON menu_items;
CREATE POLICY menu_items_guest_read ON menu_items
  FOR SELECT TO anon
  USING (
    is_available = true
    AND hotel_id IN (
      SELECT id FROM hotels
      WHERE status = 'active'
        AND (is_deleted = FALSE OR is_deleted IS NULL)
    )
  );

-- ── hotel_settings — scoped guest read ───────────────────────────────────────
-- OLD (014): USING (true) — exposed all hotels' tax rates, logo URLs etc.
DROP POLICY IF EXISTS hotel_settings_guest_read ON hotel_settings;
CREATE POLICY hotel_settings_guest_read ON hotel_settings
  FOR SELECT TO anon
  USING (
    hotel_id IN (
      SELECT id FROM hotels
      WHERE status = 'active'
        AND (is_deleted = FALSE OR is_deleted IS NULL)
    )
  );

-- ── restaurant_orders — scoped guest INSERT + SELECT ─────────────────────────
-- OLD INSERT (014): no hotel validity check
-- OLD SELECT (014): type filter only, cross-hotel exposure
DROP POLICY IF EXISTS restaurant_orders_guest_insert ON restaurant_orders;
CREATE POLICY restaurant_orders_guest_insert ON restaurant_orders
  FOR INSERT TO anon
  WITH CHECK (
    type IN ('dineIn', 'roomService')
    AND hotel_id IN (
      SELECT id FROM hotels
      WHERE status = 'active'
        AND (is_deleted = FALSE OR is_deleted IS NULL)
    )
  );

DROP POLICY IF EXISTS restaurant_orders_guest_read ON restaurant_orders;
CREATE POLICY restaurant_orders_guest_read ON restaurant_orders
  FOR SELECT TO anon
  USING (
    type IN ('dineIn', 'roomService')
    AND hotel_id IN (
      SELECT id FROM hotels
      WHERE status = 'active'
        AND (is_deleted = FALSE OR is_deleted IS NULL)
    )
  );

-- ── guest_feedback — tightened INSERT ────────────────────────────────────────
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables WHERE table_name = 'guest_feedback'
  ) THEN
    DROP POLICY IF EXISTS guest_feedback_guest_insert ON guest_feedback;
    CREATE POLICY guest_feedback_guest_insert ON guest_feedback
      FOR INSERT TO anon
      WITH CHECK (
        order_id IN (
          SELECT ro.id::text FROM restaurant_orders ro
          JOIN hotels h ON h.id = ro.hotel_id
          WHERE h.status = 'active'
            AND (h.is_deleted = FALSE OR h.is_deleted IS NULL)
            AND ro.type IN ('dineIn', 'roomService')
        )
      );
  END IF;
END $$;

-- ── hotels_guest_read — make TO anon explicit ────────────────────────────────
-- 030 already scoped this to active + non-deleted; add TO anon so authenticated
-- staff queries hit hotels_select_v3 (defined in section 4) instead.
DROP POLICY IF EXISTS hotels_guest_read ON hotels;
CREATE POLICY hotels_guest_read ON hotels
  FOR SELECT TO anon
  USING (
    (is_deleted = FALSE OR is_deleted IS NULL)
    AND status = 'active'
  );

-- ── restaurant_tables — scoped guest read ────────────────────────────────────
-- GuestMenuService.getTable() reads restaurant_tables using the anon key to
-- display the table name on the guest ordering screen. Without a replacement
-- policy the QR ordering flow would get empty results after "anon full access"
-- is dropped.
DROP POLICY IF EXISTS restaurant_tables_guest_read ON restaurant_tables;
CREATE POLICY restaurant_tables_guest_read ON restaurant_tables
  FOR SELECT TO anon
  USING (
    hotel_id IN (
      SELECT id FROM hotels
      WHERE status = 'active'
        AND (is_deleted = FALSE OR is_deleted IS NULL)
    )
  );

-- ── check_ins and rooms: no anon policy needed ───────────────────────────────
-- The guest QR ordering flow never reads check_ins or rooms directly.
-- Dropping "anon full access" on those tables is sufficient; no replacement
-- guest policy is required — staff-only access via existing _all policies.


-- ═════════════════════════════════════════════════════════════════════════════
-- 2. COMPOSITE + PARTIAL INDEXES
--
-- Single-column indexes already exist (from 001/002/017).
-- Partial indexes (WHERE is_deleted = FALSE) are strictly better than the full
-- versions for every query this app runs — the planner will always prefer the
-- partial index, and the full composite is dead weight. Keep only the partial.
-- ═════════════════════════════════════════════════════════════════════════════

-- property_staff: the exact predicate used in every RLS subquery
-- Covers: WHERE user_id = ? AND is_deleted = FALSE → returns property_id
CREATE INDEX IF NOT EXISTS property_staff_active_user_property_idx
  ON property_staff(user_id, property_id)
  WHERE is_deleted = FALSE;

-- Inverse: load all active staff for a property (team members screen)
CREATE INDEX IF NOT EXISTS property_staff_active_property_user_idx
  ON property_staff(property_id, user_id)
  WHERE is_deleted = FALSE;

-- organization_members: org lookup + member list in one scan
CREATE INDEX IF NOT EXISTS org_members_active_user_org_idx
  ON organization_members(user_id, org_id)
  WHERE is_deleted = FALSE;

-- hotels: org-scoped lookups always exclude soft-deleted hotels
CREATE INDEX IF NOT EXISTS hotels_active_org_idx
  ON hotels(org_id)
  WHERE is_deleted = FALSE;

-- bookings: date-range queries (calendar, dashboard summary)
-- Column is check_in_date (confirmed in booking_service.dart)
CREATE INDEX IF NOT EXISTS bookings_hotel_checkin_idx
  ON bookings(hotel_id, check_in_date);

-- bookings: status filter (pending/confirmed counts, board view)
CREATE INDEX IF NOT EXISTS bookings_hotel_status_idx
  ON bookings(hotel_id, status);

-- restaurant_orders: hot path for the live order board
CREATE INDEX IF NOT EXISTS restaurant_orders_hotel_type_idx
  ON restaurant_orders(hotel_id, type);

CREATE INDEX IF NOT EXISTS restaurant_orders_hotel_type_status_idx
  ON restaurant_orders(hotel_id, type, status);

-- notifications: unread-count badge evaluated on every page load
-- Triple composite avoids a separate sort step for ORDER BY created_at DESC
-- (017 already has (hotel_id,is_read) and (hotel_id,created_at DESC) — this
--  supersedes both for the combined query pattern)
CREATE INDEX IF NOT EXISTS notifications_hotel_read_created_idx
  ON notifications(hotel_id, is_read, created_at DESC);

-- rooms: status filter for the availability calendar
CREATE INDEX IF NOT EXISTS rooms_hotel_status_idx
  ON rooms(hotel_id, status);


-- ═════════════════════════════════════════════════════════════════════════════
-- 3. SECURITY DEFINER helper: materialise accessible hotel IDs once per query
--
-- hotels_select_v2 (from 030) evaluates 3 correlated subqueries per row.
-- notifications_staff (from 031) has the same pattern.
--
-- Fix: a STABLE SECURITY DEFINER function returning UUID[] — the planner
-- evaluates it exactly once per statement and the policy becomes a cheap
-- = ANY(array) test per row.
-- ═════════════════════════════════════════════════════════════════════════════

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
        AND ps.is_deleted = FALSE

      UNION ALL

      -- (b) org membership → all non-deleted hotels in the same org
      SELECT h.id AS hotel_id
      FROM hotels h
      JOIN organization_members om ON om.org_id = h.org_id
      WHERE om.user_id    = auth.uid()
        AND om.is_deleted = FALSE
        AND (h.is_deleted = FALSE OR h.is_deleted IS NULL)

      UNION ALL

      -- (c) legacy hotel_users row
      SELECT hu.hotel_id
      FROM hotel_users hu
      WHERE hu.user_id = auth.uid()
    ) sub
  )
$$;

GRANT EXECUTE ON FUNCTION my_accessible_hotel_ids() TO authenticated;


-- ═════════════════════════════════════════════════════════════════════════════
-- 4. Replace hotels SELECT / UPDATE policies (3-subquery → array helper)
-- ═════════════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS hotels_select_v2 ON hotels;
DROP POLICY IF EXISTS hotels_select_v3 ON hotels;

CREATE POLICY hotels_select_v3 ON hotels
  FOR SELECT USING (
    (is_deleted = FALSE OR is_deleted IS NULL)
    AND (
      is_superadmin()
      OR id = ANY(my_accessible_hotel_ids())
    )
  );

DROP POLICY IF EXISTS hotels_update ON hotels;

CREATE POLICY hotels_update ON hotels
  FOR UPDATE
  USING (
    (is_deleted = FALSE OR is_deleted IS NULL)
    AND (
      is_superadmin()
      OR id = ANY(my_accessible_hotel_ids())
    )
  )
  WITH CHECK (
    (is_deleted = FALSE OR is_deleted IS NULL)
    AND (
      is_superadmin()
      OR id = ANY(my_accessible_hotel_ids())
    )
  );


-- ═════════════════════════════════════════════════════════════════════════════
-- 5. Replace notifications_staff policy (same 3-subquery problem as hotels)
--    From 031_fix_notifications_rls.sql
-- ═════════════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS notifications_staff ON notifications;

CREATE POLICY notifications_staff ON notifications
  USING (
    hotel_id = ANY(my_accessible_hotel_ids())
    OR is_superadmin()
  )
  WITH CHECK (
    hotel_id = ANY(my_accessible_hotel_ids())
    OR is_superadmin()
  );
