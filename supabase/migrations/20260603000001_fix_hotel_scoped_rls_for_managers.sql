-- ============================================================
-- Migration 060: Fix hotel-scoped RLS so managers (and multi-property
--                owners) can read/write, not just hotel_users members
-- ============================================================
--
-- Root cause: the original per-table policies (migration 001) gate access on
--   hotel_id = current_hotel_id()
-- where current_hotel_id() = (SELECT hotel_id FROM hotel_users WHERE
-- user_id = auth.uid() LIMIT 1).
--
-- Only create_property() seeds a hotel_users row (for the owner). Managers are
-- provisioned via create_staff_member() -> organization_members + property_staff
-- ONLY (no hotel_users row), so current_hotel_id() returns NULL for them and
-- every INSERT/UPDATE/DELETE on these tables fails the WITH CHECK -> RLS error
-- (first hit when a manager creates a restaurant table). The same LIMIT 1 lookup
-- also breaks multi-property owners (it returns one arbitrary hotel).
--
-- Fix: replace the predicate with
--   is_hotel_member(hotel_id) OR hotel_id = current_hotel_id()
-- is_hotel_member() (hardened in migration 048) checks active organization_members
-- for the hotel's org -> grants owners, admins AND managers access to every hotel
-- in their org while preserving tenant isolation. The OR keeps any legacy
-- hotel_users-only account working (zero regression).
--
-- Scope: only the per-table "<table>_all" staff policies that still use the
-- legacy function. NOT touched (already hardened elsewhere / different shape):
--   hotels (hotels_select_v3 + write policies, migrations 033/041),
--   notifications (032), staff_shifts (020),
--   and all anon/guest policies (additive, unchanged).
-- Idempotent: DROP POLICY IF EXISTS before each CREATE.
-- ============================================================

-- Shared predicate (inlined per policy):
--   is_hotel_member(hotel_id) OR hotel_id = current_hotel_id()

-- ── rooms ────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS rooms_all ON rooms;
CREATE POLICY rooms_all ON rooms
  USING      (is_hotel_member(hotel_id) OR hotel_id = current_hotel_id())
  WITH CHECK (is_hotel_member(hotel_id) OR hotel_id = current_hotel_id());

-- ── guests ───────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS guests_all ON guests;
CREATE POLICY guests_all ON guests
  USING      (is_hotel_member(hotel_id) OR hotel_id = current_hotel_id())
  WITH CHECK (is_hotel_member(hotel_id) OR hotel_id = current_hotel_id());

-- ── bookings ─────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS bookings_all ON bookings;
CREATE POLICY bookings_all ON bookings
  USING      (is_hotel_member(hotel_id) OR hotel_id = current_hotel_id())
  WITH CHECK (is_hotel_member(hotel_id) OR hotel_id = current_hotel_id());

-- ── check_ins ────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS check_ins_all ON check_ins;
CREATE POLICY check_ins_all ON check_ins
  USING      (is_hotel_member(hotel_id) OR hotel_id = current_hotel_id())
  WITH CHECK (is_hotel_member(hotel_id) OR hotel_id = current_hotel_id());

-- ── expenses ─────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS expenses_all ON expenses;
CREATE POLICY expenses_all ON expenses
  USING      (is_hotel_member(hotel_id) OR hotel_id = current_hotel_id())
  WITH CHECK (is_hotel_member(hotel_id) OR hotel_id = current_hotel_id());

-- ── menu_items ───────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS menu_items_all ON menu_items;
CREATE POLICY menu_items_all ON menu_items
  USING      (is_hotel_member(hotel_id) OR hotel_id = current_hotel_id())
  WITH CHECK (is_hotel_member(hotel_id) OR hotel_id = current_hotel_id());

-- ── ingredients ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS ingredients_all ON ingredients;
CREATE POLICY ingredients_all ON ingredients
  USING      (is_hotel_member(hotel_id) OR hotel_id = current_hotel_id())
  WITH CHECK (is_hotel_member(hotel_id) OR hotel_id = current_hotel_id());

-- ── ingredient_prices ────────────────────────────────────────────────────────
DROP POLICY IF EXISTS ingredient_prices_all ON ingredient_prices;
CREATE POLICY ingredient_prices_all ON ingredient_prices
  USING      (is_hotel_member(hotel_id) OR hotel_id = current_hotel_id())
  WITH CHECK (is_hotel_member(hotel_id) OR hotel_id = current_hotel_id());

-- ── menu_item_cost_records ───────────────────────────────────────────────────
DROP POLICY IF EXISTS menu_item_cost_records_all ON menu_item_cost_records;
CREATE POLICY menu_item_cost_records_all ON menu_item_cost_records
  USING      (is_hotel_member(hotel_id) OR hotel_id = current_hotel_id())
  WITH CHECK (is_hotel_member(hotel_id) OR hotel_id = current_hotel_id());

-- ── restaurant_tables (the reported failure) ─────────────────────────────────
DROP POLICY IF EXISTS restaurant_tables_all ON restaurant_tables;
CREATE POLICY restaurant_tables_all ON restaurant_tables
  USING      (is_hotel_member(hotel_id) OR hotel_id = current_hotel_id())
  WITH CHECK (is_hotel_member(hotel_id) OR hotel_id = current_hotel_id());

-- ── restaurant_orders ────────────────────────────────────────────────────────
-- (guest anon INSERT/SELECT policies remain separate and unchanged)
DROP POLICY IF EXISTS restaurant_orders_all ON restaurant_orders;
CREATE POLICY restaurant_orders_all ON restaurant_orders
  USING      (is_hotel_member(hotel_id) OR hotel_id = current_hotel_id())
  WITH CHECK (is_hotel_member(hotel_id) OR hotel_id = current_hotel_id());

-- ── inventory ────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS inventory_all ON inventory;
CREATE POLICY inventory_all ON inventory
  USING      (is_hotel_member(hotel_id) OR hotel_id = current_hotel_id())
  WITH CHECK (is_hotel_member(hotel_id) OR hotel_id = current_hotel_id());

-- ── hotel_settings (manager read + update of property settings) ──────────────
DROP POLICY IF EXISTS hotel_settings_select ON hotel_settings;
CREATE POLICY hotel_settings_select ON hotel_settings
  FOR SELECT USING (is_hotel_member(hotel_id) OR hotel_id = current_hotel_id());

DROP POLICY IF EXISTS hotel_settings_update ON hotel_settings;
CREATE POLICY hotel_settings_update ON hotel_settings
  FOR UPDATE USING      (is_hotel_member(hotel_id) OR hotel_id = current_hotel_id())
             WITH CHECK (is_hotel_member(hotel_id) OR hotel_id = current_hotel_id());
