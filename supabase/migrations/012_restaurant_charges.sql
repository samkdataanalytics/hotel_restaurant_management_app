-- ============================================================
-- Migration 012: Restaurant tax, service charge & order discounts
--
-- 1. Adds service_charge_rate to hotel_settings
--    (tax_rate already exists from 001_multi_tenancy.sql)
--
-- 2. Adds discount_type and discount_amount to restaurant_orders
--    discount_type: 'percentage' | 'flat' | NULL (no discount)
--    discount_amount: numeric value (% or flat currency amount)
-- ============================================================

-- ── Part 1: Service charge in hotel_settings ─────────────────

ALTER TABLE hotel_settings
  ADD COLUMN IF NOT EXISTS service_charge_rate NUMERIC(5,4) NOT NULL DEFAULT 0.00;

-- ── Part 2: Discount columns on restaurant_orders ────────────

ALTER TABLE restaurant_orders
  ADD COLUMN IF NOT EXISTS discount_type   TEXT    DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS discount_amount NUMERIC(10,2) NOT NULL DEFAULT 0.00;

-- Validate discount_type values
ALTER TABLE restaurant_orders
  DROP CONSTRAINT IF EXISTS chk_discount_type;

ALTER TABLE restaurant_orders
  ADD CONSTRAINT chk_discount_type
    CHECK (discount_type IS NULL OR discount_type IN ('percentage', 'flat'));

-- ── Done ─────────────────────────────────────────────────────
