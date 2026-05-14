-- ============================================================
-- Migration 018: Staff Shift Scheduling & Time Tracking
--
-- Creates two tables:
--   staff_shifts       – planned/assigned shifts
--   staff_time_records – actual clock-in / clock-out entries
-- ============================================================

-- ── 1. staff_shifts ──────────────────────────────────────────

CREATE TABLE IF NOT EXISTS staff_shifts (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  hotel_id        UUID        NOT NULL REFERENCES hotels(id) ON DELETE CASCADE,
  staff_user_id   UUID        NOT NULL,            -- auth.uid() of the assignee
  staff_name      TEXT        NOT NULL DEFAULT '', -- denormalised for fast display
  shift_date      DATE        NOT NULL,
  start_time      TEXT        NOT NULL,            -- 'HH:mm'
  end_time        TEXT        NOT NULL,            -- 'HH:mm'
  role            TEXT        NOT NULL DEFAULT 'staff',
  notes           TEXT        NOT NULL DEFAULT '',
  status          TEXT        NOT NULL DEFAULT 'scheduled'
                  CHECK (status IN ('scheduled','completed','cancelled')),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS staff_shifts_hotel_date_idx
  ON staff_shifts(hotel_id, shift_date);

CREATE INDEX IF NOT EXISTS staff_shifts_user_idx
  ON staff_shifts(hotel_id, staff_user_id);

-- ── 2. staff_time_records ────────────────────────────────────

CREATE TABLE IF NOT EXISTS staff_time_records (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  hotel_id        UUID        NOT NULL REFERENCES hotels(id) ON DELETE CASCADE,
  staff_user_id   UUID        NOT NULL,
  staff_name      TEXT        NOT NULL DEFAULT '',
  shift_id        UUID        REFERENCES staff_shifts(id) ON DELETE SET NULL,
  clock_in        TIMESTAMPTZ NOT NULL DEFAULT now(),
  clock_out       TIMESTAMPTZ,
  notes           TEXT        NOT NULL DEFAULT '',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS staff_time_records_hotel_idx
  ON staff_time_records(hotel_id, clock_in DESC);

CREATE INDEX IF NOT EXISTS staff_time_records_user_idx
  ON staff_time_records(hotel_id, staff_user_id, clock_in DESC);

-- ── 3. RLS ───────────────────────────────────────────────────

ALTER TABLE staff_shifts       ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_time_records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS shifts_hotel_access       ON staff_shifts;
DROP POLICY IF EXISTS time_records_hotel_access ON staff_time_records;

-- All authenticated hotel staff can read/write within their hotel.
-- Fine-grained (manager-only) controls are enforced in the Dart layer.
CREATE POLICY shifts_hotel_access ON staff_shifts
  USING      (hotel_id = current_hotel_id())
  WITH CHECK (hotel_id = current_hotel_id());

CREATE POLICY time_records_hotel_access ON staff_time_records
  USING      (hotel_id = current_hotel_id())
  WITH CHECK (hotel_id = current_hotel_id());
