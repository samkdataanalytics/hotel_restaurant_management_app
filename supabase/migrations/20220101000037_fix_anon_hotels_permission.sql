-- ─────────────────────────────────────────────────────────────────────────────
-- 036_fix_anon_hotels_permission.sql
--
-- Root cause: hotels_select_v3 and hotels_update (from 032/033) have no TO
-- clause, so they fire for EVERY role including anon. Their USING expression
-- calls my_accessible_hotel_ids() — a function anon has no EXECUTE on.
-- PostgreSQL evaluates all PERMISSIVE policies before OR-ing them, so even
-- though hotels_guest_read (TO anon) would allow the row, PostgreSQL still
-- tries to execute my_accessible_hotel_ids() first → 42501 permission denied.
--
-- Fix: restrict hotels_select_v3, hotels_update, and notifications_staff to
-- TO authenticated. Anon queries then only hit hotels_guest_read (which exists
-- from 032 section 1 and does NOT call my_accessible_hotel_ids()).
-- ─────────────────────────────────────────────────────────────────────────────

-- ── hotels SELECT ─────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS hotels_select_v3 ON hotels;

CREATE POLICY hotels_select_v3 ON hotels
  FOR SELECT TO authenticated
  USING (
    (is_deleted = FALSE OR is_deleted IS NULL)
    AND (
      is_superadmin()
      OR id = ANY(my_accessible_hotel_ids())
    )
  );

-- Ensure the anon read policy is in place (idempotent)
DROP POLICY IF EXISTS hotels_guest_read ON hotels;
CREATE POLICY hotels_guest_read ON hotels
  FOR SELECT TO anon
  USING (
    (is_deleted = FALSE OR is_deleted IS NULL)
    AND status = 'active'
  );

-- ── hotels UPDATE ─────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS hotels_update ON hotels;

CREATE POLICY hotels_update ON hotels
  FOR UPDATE TO authenticated
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

-- ── notifications (staff only — anon never queries this table) ────────────────

DROP POLICY IF EXISTS notifications_staff ON notifications;

CREATE POLICY notifications_staff ON notifications
  FOR ALL TO authenticated
  USING (
    hotel_id = ANY(my_accessible_hotel_ids())
    OR is_superadmin()
  )
  WITH CHECK (
    hotel_id = ANY(my_accessible_hotel_ids())
    OR is_superadmin()
  );
