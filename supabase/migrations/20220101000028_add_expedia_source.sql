-- Drop the old check constraint that doesn't include 'expedia'
ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_source_check;

-- Re-add with expedia included
ALTER TABLE bookings
  ADD CONSTRAINT bookings_source_check
  CHECK (source IN ('bookingCom', 'airbnb', 'expedia', 'direct', 'other'));
