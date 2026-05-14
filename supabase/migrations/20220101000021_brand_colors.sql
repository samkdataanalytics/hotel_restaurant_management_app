-- ============================================================
-- Migration 021: Per-property brand color
--
-- Adds primary_color to both hotels (for OrgProperty model)
-- and hotel_settings (for HotelSettings/invoice/guest screens).
-- Stored in both tables — same pattern as logo_url.
-- ============================================================

ALTER TABLE hotels
  ADD COLUMN IF NOT EXISTS primary_color TEXT NOT NULL DEFAULT '#D4A853';

ALTER TABLE hotel_settings
  ADD COLUMN IF NOT EXISTS primary_color TEXT NOT NULL DEFAULT '#D4A853';
