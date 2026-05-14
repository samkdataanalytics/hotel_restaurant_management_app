-- Add booking_channels column to hotels table
-- Stores the OTA / channel mix selected during property setup.
-- Values: 'bookingCom', 'airbnb', 'expedia', 'direct', 'other'

ALTER TABLE hotels
  ADD COLUMN IF NOT EXISTS booking_channels jsonb NOT NULL DEFAULT '["direct"]'::jsonb;
