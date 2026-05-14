-- ─── Third-party delivery order support ───────────────────────────────────────
-- Adds delivery platform tracking to restaurant_orders.
-- Supported platforms: UberEats | PickMe | Other (free text)

ALTER TABLE restaurant_orders
  ADD COLUMN IF NOT EXISTS delivery_platform  TEXT,  -- 'UberEats' | 'PickMe' | 'Other'
  ADD COLUMN IF NOT EXISTS delivery_order_ref TEXT;  -- platform order ID / reference

-- Extend the type check constraint to include 'delivery'
ALTER TABLE restaurant_orders
  DROP CONSTRAINT IF EXISTS restaurant_orders_type_check;

ALTER TABLE restaurant_orders
  ADD CONSTRAINT restaurant_orders_type_check
  CHECK (type IN ('dineIn', 'takeaway', 'roomService', 'delivery'));
