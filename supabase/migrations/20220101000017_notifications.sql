-- ============================================================
-- Migration 017: In-app Notifications
--
-- Creates the notifications table and a nightly pg_cron job
-- that generates housekeeping alerts every 3 nights for
-- guests who are still checked in.
-- ============================================================


-- ── 1. notifications table ────────────────────────────────────

CREATE TABLE IF NOT EXISTS notifications (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  hotel_id     UUID        NOT NULL REFERENCES hotels(id) ON DELETE CASCADE,
  type         TEXT        NOT NULL,   -- 'reservation'|'checkin'|'checkout'|'room_service'|'low_availability'|'housekeeping'
  title        TEXT        NOT NULL,
  body         TEXT        NOT NULL,
  is_read      BOOLEAN     NOT NULL DEFAULT false,
  metadata     JSONB       NOT NULL DEFAULT '{}',
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS notifications_hotel_idx    ON notifications(hotel_id);
CREATE INDEX IF NOT EXISTS notifications_read_idx     ON notifications(hotel_id, is_read);
CREATE INDEX IF NOT EXISTS notifications_created_idx  ON notifications(hotel_id, created_at DESC);

-- ── 2. RLS ───────────────────────────────────────────────────

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS notifications_staff ON notifications;
CREATE POLICY notifications_staff ON notifications
  USING      (hotel_id = current_hotel_id())
  WITH CHECK (hotel_id = current_hotel_id());


-- ── 3. Housekeeping function ─────────────────────────────────
-- Called by pg_cron every night at 01:00.
-- For every active check-in where (today − check_in_date) is a
-- positive multiple of 3, insert a housekeeping notification
-- unless one already exists for the same booking + day count.

CREATE OR REPLACE FUNCTION generate_housekeeping_notifications()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  rec RECORD;
  nights_stayed INT;
BEGIN
  FOR rec IN
    SELECT
      b.id          AS booking_id,
      b.hotel_id,
      b.check_in    AS check_in_date,
      b.room_id,
      r.room_number,
      g.full_name   AS guest_name
    FROM bookings b
    JOIN rooms   r ON r.id = b.room_id
    JOIN guests  g ON g.id = b.guest_id
    WHERE b.status = 'checkedIn'
  LOOP
    nights_stayed := (CURRENT_DATE - rec.check_in_date::date);

    -- Only fire on multiples of 3, and not on day 0
    IF nights_stayed > 0 AND nights_stayed % 3 = 0 THEN

      -- Avoid duplicate: check if we already notified for this booking+night
      IF NOT EXISTS (
        SELECT 1 FROM notifications
        WHERE hotel_id = rec.hotel_id
          AND type     = 'housekeeping'
          AND metadata->>'booking_id'    = rec.booking_id::text
          AND (metadata->>'nights_stayed')::int = nights_stayed
      ) THEN
        INSERT INTO notifications (hotel_id, type, title, body, metadata)
        VALUES (
          rec.hotel_id,
          'housekeeping',
          'Housekeeping Required — Room ' || rec.room_number,
          rec.guest_name || ' has been staying for ' || nights_stayed ||
            ' nights. Please schedule a room clean.',
          jsonb_build_object(
            'booking_id',    rec.booking_id,
            'room_id',       rec.room_id,
            'room_number',   rec.room_number,
            'guest_name',    rec.guest_name,
            'nights_stayed', nights_stayed
          )
        );
      END IF;
    END IF;
  END LOOP;
END;
$$;


-- ── 4. pg_cron schedule (runs at 01:00 every night) ──────────
-- Requires the pg_cron extension to be enabled in Supabase
-- (Dashboard → Database → Extensions → pg_cron).
-- If pg_cron is not available, the Dart app falls back to
-- checking on login (see NotificationService.checkHousekeeping).

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.schedule(
      'housekeeping-notifications',
      '0 1 * * *',                             -- every night at 01:00
      'SELECT generate_housekeeping_notifications()'
    );
  END IF;
END;
$$;
