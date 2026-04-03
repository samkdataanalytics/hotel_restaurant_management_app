-- ============================================================
-- Migration 016: Extend restaurant_orders type check constraint
--
-- The original check constraint only allowed 'dineIn' and 'takeaway'.
-- Room service QR ordering requires a 'roomService' type.
-- Drop the old constraint and recreate it with all valid values.
-- ============================================================

ALTER TABLE restaurant_orders
  DROP CONSTRAINT IF EXISTS restaurant_orders_type_check;

ALTER TABLE restaurant_orders
  ADD CONSTRAINT restaurant_orders_type_check
  CHECK (type IN ('dineIn', 'takeaway', 'roomService'));
