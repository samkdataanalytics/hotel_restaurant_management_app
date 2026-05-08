-- ─── Fix missing table grants for notifications ──────────────────────────────
-- Migration 017 created the notifications table and RLS policies but never
-- granted DML privileges to the authenticated role, causing 42501 errors.

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE notifications TO authenticated;
GRANT ALL ON TABLE notifications TO service_role;
