-- ============================================================
-- Migration 062: Add missing foreign keys for bookings / check_ins
-- ============================================================
-- The app embeds related rows via PostgREST:
--   bookings.select('*, guests(*), rooms(*)')
--   check_ins.select('*, bookings(*), guests(*), rooms(*)')
-- but guest_id / room_id / booking_id were declared as plain UUID columns with
-- NO foreign keys (base schema). PostgREST infers embeddable relationships from
-- FK constraints, so these queries fail with PGRST200:
--   "Could not find a relationship between 'bookings' and 'guests' ..."
-- (seen on Reservations, Check-ins, and Financials).
--
-- Fix: add the FKs. First null out any dangling references so the constraints
-- validate on dirty/seed data (non-destructive — only clears pointers that
-- already point at nothing). ON DELETE SET NULL keeps history if a parent row
-- is removed. Idempotent: DROP CONSTRAINT IF EXISTS before each ADD.
-- ============================================================

-- ── Clean orphaned references (so ADD CONSTRAINT validates) ───────────────────
UPDATE bookings  SET guest_id   = NULL WHERE guest_id   IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM guests   g WHERE g.id = bookings.guest_id);
UPDATE bookings  SET room_id    = NULL WHERE room_id    IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM rooms    r WHERE r.id = bookings.room_id);
UPDATE check_ins SET booking_id = NULL WHERE booking_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM bookings b WHERE b.id = check_ins.booking_id);
UPDATE check_ins SET guest_id   = NULL WHERE guest_id   IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM guests   g WHERE g.id = check_ins.guest_id);
UPDATE check_ins SET room_id    = NULL WHERE room_id    IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM rooms    r WHERE r.id = check_ins.room_id);

-- ── bookings FKs ──────────────────────────────────────────────────────────────
ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_guest_id_fkey;
ALTER TABLE bookings
  ADD CONSTRAINT bookings_guest_id_fkey
  FOREIGN KEY (guest_id) REFERENCES guests(id) ON DELETE SET NULL;

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_room_id_fkey;
ALTER TABLE bookings
  ADD CONSTRAINT bookings_room_id_fkey
  FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE SET NULL;

-- ── check_ins FKs ─────────────────────────────────────────────────────────────
ALTER TABLE check_ins DROP CONSTRAINT IF EXISTS check_ins_booking_id_fkey;
ALTER TABLE check_ins
  ADD CONSTRAINT check_ins_booking_id_fkey
  FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE SET NULL;

ALTER TABLE check_ins DROP CONSTRAINT IF EXISTS check_ins_guest_id_fkey;
ALTER TABLE check_ins
  ADD CONSTRAINT check_ins_guest_id_fkey
  FOREIGN KEY (guest_id) REFERENCES guests(id) ON DELETE SET NULL;

ALTER TABLE check_ins DROP CONSTRAINT IF EXISTS check_ins_room_id_fkey;
ALTER TABLE check_ins
  ADD CONSTRAINT check_ins_room_id_fkey
  FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE SET NULL;

-- ── Force PostgREST to refresh its relationship cache immediately ─────────────
NOTIFY pgrst, 'reload schema';
