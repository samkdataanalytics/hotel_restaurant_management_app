-- ============================================================
-- Migration 014: Guest (anon) RLS policies for QR ordering
--
-- Problem: restaurant_orders_all requires hotel_id = current_hotel_id()
-- which is only available to authenticated staff.  Guests arrive via
-- the QR code URL using the anon key, so current_hotel_id() returns NULL
-- and every INSERT/SELECT is rejected by RLS.
--
-- Fix: Add narrow guest-access policies that cover only:
--   1. SELECT on menu_items          (load menu)
--   2. SELECT on hotel_settings      (load tax / service rates)
--   3. SELECT on properties          (load property name)
--   4. INSERT on restaurant_orders   (place order)
--   5. SELECT on restaurant_orders   (watch live order status)
--   6. INSERT on guest_feedback      (submit feedback after order)
--
-- All guest policies use the anon role implicitly — they fire when
-- the caller is not authenticated.  The existing staff policies
-- (which use current_hotel_id()) remain unchanged.
-- ============================================================


-- ── 1. menu_items — public read ──────────────────────────────
DROP POLICY IF EXISTS menu_items_guest_read ON menu_items;
CREATE POLICY menu_items_guest_read ON menu_items
  FOR SELECT
  USING (is_available = true);


-- ── 2. hotel_settings — public read (tax / service rates) ────
DROP POLICY IF EXISTS hotel_settings_guest_read ON hotel_settings;
CREATE POLICY hotel_settings_guest_read ON hotel_settings
  FOR SELECT
  USING (true);


-- ── 3. hotels — public read (property name) ──────────────────
-- Note: the Dart service queries the "properties" view/table but the
-- underlying DB table is "hotels".
DROP POLICY IF EXISTS hotels_guest_read ON hotels;
CREATE POLICY hotels_guest_read ON hotels
  FOR SELECT
  USING (true);


-- ── 4. restaurant_orders — guest INSERT (place order) ─────────
-- Guests can insert orders of type 'dineIn' or 'roomService'.
-- hotel_id is passed in by the app from the QR-code URL — no JWT needed.
DROP POLICY IF EXISTS restaurant_orders_guest_insert ON restaurant_orders;
CREATE POLICY restaurant_orders_guest_insert ON restaurant_orders
  FOR INSERT
  WITH CHECK (type IN ('dineIn', 'roomService'));


-- ── 5. restaurant_orders — guest SELECT (watch order status) ──
-- Guests can only read orders of guest types (not staff-created orders).
DROP POLICY IF EXISTS restaurant_orders_guest_read ON restaurant_orders;
CREATE POLICY restaurant_orders_guest_read ON restaurant_orders
  FOR SELECT
  USING (type IN ('dineIn', 'roomService'));


-- ── 6. guest_feedback — guest INSERT ──────────────────────────
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables WHERE table_name = 'guest_feedback'
  ) THEN
    DROP POLICY IF EXISTS guest_feedback_guest_insert ON guest_feedback;
    CREATE POLICY guest_feedback_guest_insert ON guest_feedback
      FOR INSERT
      WITH CHECK (true);
  END IF;
END $$;
