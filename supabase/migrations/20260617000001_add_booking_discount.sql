-- Add discount fields to bookings table
-- discount_type: 'flat' (fixed amount off) or 'percentage' (% off total)
-- discount_value: the numeric value of the discount (amount or percent)
-- total_amount remains the gross amount; net is derived as total - discount

ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS discount_type  TEXT    NOT NULL DEFAULT 'flat',
  ADD COLUMN IF NOT EXISTS discount_value NUMERIC NOT NULL DEFAULT 0;
