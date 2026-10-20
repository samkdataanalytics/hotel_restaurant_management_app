-- Realtime for the tables the staff app writes but could not see change.
--
-- After 20261008160951 the publication covered the front desk and orders.
-- These are the rest of what the mobile app mutates: a manager marking an item
-- out of stock, a rota edit, a stock count, a table added on the web panel.
-- Without them a second device shows stale data until someone pulls to refresh.
--
-- menu_items is the operationally important one: when the kitchen 86s a dish,
-- every waiter's order screen has to stop offering it immediately, or the
-- next three tables order something that cannot be made.
--
-- REPLICA IDENTITY FULL for the same reason as the earlier migrations: a
-- partial UPDATE otherwise omits the tenant key from the WAL, the realtime RLS
-- check cannot evaluate, and the event is dropped without a trace.

DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'menu_items',        -- availability toggles reach waiters
    'restaurant_tables', -- table added/renamed on the web panel
    'expenses',          -- manager expense entry
    'staff_shifts',      -- rota and clock-in/out
    'ingredients',       -- stock names and reorder levels
    'inventory',         -- stock counts
    'property_staff'     -- team changes; note: property_id, not hotel_id
  ]
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND tablename = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
    EXECUTE format('ALTER TABLE public.%I REPLICA IDENTITY FULL', t);
  END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';
