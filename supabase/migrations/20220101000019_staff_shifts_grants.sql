-- ============================================================
-- Migration 019: Grant authenticated role access to shift tables
--
-- Tables created via SQL migration do NOT receive automatic
-- grants (unlike tables created in the Supabase dashboard).
-- RLS policies control row visibility; these grants allow the
-- authenticated role to attempt queries at all.
-- ============================================================

GRANT SELECT, INSERT, UPDATE, DELETE ON staff_shifts       TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON staff_time_records TO authenticated;
