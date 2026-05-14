-- ============================================================
-- Migration 020: Fix RLS policies on shift tables
--
-- Replace current_hotel_id() (returns one hotel for the user)
-- with is_hotel_member(hotel_id) — the established pattern used
-- in property_staff_permissions, staff_invites, etc.
-- is_hotel_member checks whether auth.uid() belongs to the
-- specific hotel_id on the row being accessed.
-- ============================================================

DROP POLICY IF EXISTS shifts_hotel_access       ON staff_shifts;
DROP POLICY IF EXISTS time_records_hotel_access ON staff_time_records;

CREATE POLICY shifts_hotel_access ON staff_shifts
  USING      (is_hotel_member(hotel_id) OR is_superadmin())
  WITH CHECK (is_hotel_member(hotel_id) OR is_superadmin());

CREATE POLICY time_records_hotel_access ON staff_time_records
  USING      (is_hotel_member(hotel_id) OR is_superadmin())
  WITH CHECK (is_hotel_member(hotel_id) OR is_superadmin());
