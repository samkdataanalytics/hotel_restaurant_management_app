-- ── Enable WebSockets for Realtime ─────────────────────────────────────────────
-- The Guest Room Service UI uses Supabase Streams to reactively update the UI 
-- based on the current order status ('pending', 'developing', 'ready', 'served').
-- By default, Supabase does not broadcast table modifications to websocket clients.
-- This script adds restaurant_orders to the `supabase_realtime` publication so 
-- that the `.stream()` listener receives the push notifications.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
      AND tablename = 'restaurant_orders'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE restaurant_orders;
  END IF;
END $$;

-- Crucial: Postgres only sends the primary key and *changed* columns in the replication WAL by default.
-- Because the `restaurant_orders_guest_read` RLS policy depends on `type` and `hotel_id` to verify 
-- visibility, if an update (like changing 'status') doesn't also update 'type' and 'hotel_id', 
-- those columns are missing from the WAL. The Realtime server's RLS engine then fails the policy 
-- because `null IN ('dineIn', ...)` is false, dropping the websocket event silently!
-- Setting REPLICA IDENTITY FULL forces Postgres to send ALL columns for every UPDATE event.
ALTER TABLE restaurant_orders REPLICA IDENTITY FULL;
