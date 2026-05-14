-- ─── Fix missing table-level grants ─────────────────────────────────────────
-- Several tables were created via migrations without explicit GRANTs.
-- The service_role JWT (used in Edge Functions) needs table-level SELECT
-- even though it bypasses RLS. The anon/authenticated roles also need
-- explicit grants for tables that predate Supabase's automatic grant setup.

-- plans (migration 022) — queried by Edge Functions with service_role key
GRANT SELECT ON TABLE plans TO anon, authenticated;
GRANT ALL    ON TABLE plans TO service_role;

-- notifications (migration 017) — written by app on login
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE notifications TO authenticated;
GRANT ALL ON TABLE notifications TO service_role;

-- payhere_orders (migration 042) — written/read by payhere-hash and payhere-notify
GRANT SELECT, INSERT, UPDATE ON TABLE payhere_orders TO authenticated;
GRANT ALL ON TABLE payhere_orders TO service_role;

-- pending_provisions (migration 044) — read by app on first login
GRANT SELECT ON TABLE pending_provisions TO authenticated;
GRANT ALL    ON TABLE pending_provisions TO service_role;
