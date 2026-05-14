-- ============================================================
-- Migration 015: Add room_number column to restaurant_orders
--
-- room service orders need to track which room to deliver to,
-- but table_id is UUID (references restaurant_tables) and cannot
-- store a plain room number string like "101".
-- ============================================================

ALTER TABLE restaurant_orders
  ADD COLUMN IF NOT EXISTS room_number TEXT;
