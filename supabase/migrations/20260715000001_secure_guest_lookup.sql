-- C-1/C-2/C-3: Replace broad anon SELECT/UPDATE on bookings & guests with
-- narrow SECURITY DEFINER RPCs scoped to a single booking reference.
-- Drops: bookings_guest_lookup, guests_guest_lookup, guests_guest_upsert.
-- Also fixes the silent bug where guests could not save preferences because
-- the anon UPDATE on bookings was never granted.

-- ─── 1. Lookup RPC ──────────────────────────────────────────────────────────
-- Returns booking + guest + room JSON for the given booking_ref.
-- Returns NULL when the ref is not found or the hotel is inactive.

CREATE OR REPLACE FUNCTION lookup_guest_booking(p_booking_ref TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_booking bookings%ROWTYPE;
  v_guest   guests%ROWTYPE;
  v_room    rooms%ROWTYPE;
BEGIN
  SELECT b.* INTO v_booking
  FROM   bookings b
  JOIN   hotels   h ON h.id = b.hotel_id
  WHERE  b.booking_ref = p_booking_ref
    AND  h.status      = 'active'
    AND  (h.is_deleted = false OR h.is_deleted IS NULL)
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  SELECT * INTO v_guest FROM guests WHERE id = v_booking.guest_id LIMIT 1;
  SELECT * INTO v_room  FROM rooms  WHERE id = v_booking.room_id  LIMIT 1;

  RETURN jsonb_build_object(
    'booking',  to_jsonb(v_booking),
    'guest',    CASE WHEN v_guest.id IS NOT NULL THEN to_jsonb(v_guest) ELSE NULL END,
    'room',     CASE WHEN v_room.id  IS NOT NULL THEN to_jsonb(v_room)  ELSE NULL END,
    'hotel_id', v_booking.hotel_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION lookup_guest_booking(TEXT) TO anon;

-- ─── 2. Submit-form RPC ─────────────────────────────────────────────────────
-- Updates the guest profile AND marks the booking form submitted in one
-- atomic call, scoped to the booking identified by p_booking_ref.
-- Raises an exception if the ref is invalid or the hotel is inactive.

CREATE OR REPLACE FUNCTION submit_guest_form(
  p_booking_ref        TEXT,
  p_full_name          TEXT,
  p_email              TEXT,
  p_phone              TEXT,
  p_id_type            TEXT,
  p_id_number          TEXT,
  p_nationality        TEXT,
  p_passport_or_nic    TEXT    DEFAULT NULL,
  p_date_of_birth      TEXT    DEFAULT NULL,
  p_whats_app          TEXT    DEFAULT NULL,
  p_guest_preferences  JSONB   DEFAULT NULL,
  p_special_requests   TEXT    DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_booking_id UUID;
  v_guest_id   UUID;
BEGIN
  SELECT b.id, b.guest_id INTO v_booking_id, v_guest_id
  FROM   bookings b
  JOIN   hotels   h ON h.id = b.hotel_id
  WHERE  b.booking_ref = p_booking_ref
    AND  h.status      = 'active'
    AND  (h.is_deleted = false OR h.is_deleted IS NULL)
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found: %', p_booking_ref;
  END IF;

  UPDATE guests
  SET
    full_name       = p_full_name,
    email           = p_email,
    phone           = p_phone,
    id_type         = p_id_type,
    id_number       = p_id_number,
    nationality     = p_nationality,
    passport_or_nic = p_passport_or_nic,
    date_of_birth   = CASE
                        WHEN p_date_of_birth IS NULL OR p_date_of_birth = ''
                        THEN NULL
                        ELSE p_date_of_birth::date
                      END,
    whats_app       = p_whats_app
  WHERE id = v_guest_id;

  UPDATE bookings
  SET
    is_guest_form_submitted = true,
    guest_preferences       = COALESCE(p_guest_preferences, guest_preferences),
    special_requests        = CASE
                                WHEN p_special_requests IS NOT NULL AND p_special_requests <> ''
                                THEN p_special_requests
                                ELSE special_requests
                              END
  WHERE id = v_booking_id;
END;
$$;

GRANT EXECUTE ON FUNCTION submit_guest_form(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,JSONB,TEXT) TO anon;

-- ─── 3. Drop the broad anon policies ────────────────────────────────────────

DROP POLICY IF EXISTS bookings_guest_lookup ON bookings;
DROP POLICY IF EXISTS guests_guest_lookup   ON guests;
DROP POLICY IF EXISTS guests_guest_upsert   ON guests;
