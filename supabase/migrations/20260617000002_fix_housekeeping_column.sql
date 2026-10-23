-- Fix: generate_housekeeping_notifications() referenced b.check_in
-- (non-existent column). The correct column name is check_in_date.

CREATE OR REPLACE FUNCTION generate_housekeeping_notifications()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  rec RECORD;
  nights_stayed INT;
BEGIN
  FOR rec IN
    SELECT
      b.id            AS booking_id,
      b.hotel_id,
      b.check_in_date,
      b.room_id,
      r.room_number,
      g.full_name     AS guest_name
    FROM bookings b
    JOIN rooms   r ON r.id = b.room_id
    JOIN guests  g ON g.id = b.guest_id
    WHERE b.status = 'checkedIn'
  LOOP
    nights_stayed := (CURRENT_DATE - rec.check_in_date::date);

    IF nights_stayed > 0 AND nights_stayed % 3 = 0 THEN
      IF NOT EXISTS (
        SELECT 1 FROM notifications
        WHERE hotel_id  = rec.hotel_id
          AND type      = 'housekeeping'
          AND metadata->>'booking_id'     = rec.booking_id::text
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
