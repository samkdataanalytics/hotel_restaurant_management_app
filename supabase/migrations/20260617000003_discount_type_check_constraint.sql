-- Add CHECK constraint so discount_type only accepts valid values.
-- Without this any string could be stored, causing discountAmount()
-- to silently fall through to the flat branch for unknown types.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'bookings_discount_type_check'
  ) THEN
    ALTER TABLE bookings
      ADD CONSTRAINT bookings_discount_type_check
      CHECK (discount_type IN ('flat', 'percentage'));
  END IF;
END;
$$;
