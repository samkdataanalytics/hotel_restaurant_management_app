-- Phase 2 front-desk support for the staff mobile app.
--
-- Four independent pieces, all additive:
--   1. A PRIVATE bucket for guest identity documents.
--   2. Columns on check_ins to reference them.
--   3. A housekeeping state on rooms, separate from occupancy.
--   4. The realtime publication the arrivals and room boards need, plus the
--      notifications table, whose live stream has never actually worked.
--
-- Nothing here alters an existing column or policy, so the web panel is
-- unaffected: it simply does not read the new columns.

-- ─── 1. Guest identity documents ────────────────────────────────────────────
--
-- PRIVATE, unlike property-logos. These are photographed passports and NICs:
-- a public bucket would expose them to anyone who guessed a URL. 10MB cap and
-- an image-only mime allowlist keep it from becoming general file storage.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'guest-documents',
  'guest-documents',
  FALSE,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- Object paths are '{hotel_id}/{check_in_id}/{filename}', so the first path
-- segment is the tenant key and is_hotel_member() can gate on it directly —
-- the same predicate every other tenant table uses.
DROP POLICY IF EXISTS guest_documents_select ON storage.objects;
CREATE POLICY guest_documents_select ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'guest-documents'
    AND is_hotel_member(((storage.foldername(name))[1])::uuid)
  );

DROP POLICY IF EXISTS guest_documents_insert ON storage.objects;
CREATE POLICY guest_documents_insert ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'guest-documents'
    AND is_hotel_member(((storage.foldername(name))[1])::uuid)
  );

DROP POLICY IF EXISTS guest_documents_update ON storage.objects;
CREATE POLICY guest_documents_update ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'guest-documents'
    AND is_hotel_member(((storage.foldername(name))[1])::uuid)
  );

DROP POLICY IF EXISTS guest_documents_delete ON storage.objects;
CREATE POLICY guest_documents_delete ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'guest-documents'
    AND is_hotel_member(((storage.foldername(name))[1])::uuid)
  );

-- Deliberately NO anon policy. The guest QR self check-in flow does not upload
-- identity documents, and an anon write path into this bucket would be the
-- easiest way to turn it into open storage.

-- ─── 2. Document references on check_ins ────────────────────────────────────
--
-- Nullable: every existing check-in has no document, and the desk must still
-- be able to check someone in when the camera is unavailable.
ALTER TABLE check_ins
  ADD COLUMN IF NOT EXISTS id_document_url TEXT,
  ADD COLUMN IF NOT EXISTS signature_url   TEXT;

COMMENT ON COLUMN check_ins.id_document_url IS
  'Object path in the private guest-documents bucket. Subject to whatever '
  'identity-document retention policy the operator adopts — this is PII.';

-- ─── 3. Housekeeping state ──────────────────────────────────────────────────
--
-- Separate from rooms.status, which tracks occupancy (available / occupied /
-- maintenance). A room can be occupied AND dirty, or available AND awaiting
-- inspection, so folding the two into one column loses information the
-- housekeeping round needs.
ALTER TABLE rooms
  ADD COLUMN IF NOT EXISTS housekeeping_status TEXT NOT NULL DEFAULT 'ready'
    CHECK (housekeeping_status IN ('ready', 'dirty', 'cleaning', 'inspected'));

COMMENT ON COLUMN rooms.housekeeping_status IS
  'Cleaning state, independent of occupancy in rooms.status.';

-- Existing rooms default to 'ready' rather than 'dirty': assuming every room
-- in an operating hotel is dirty on the day this ships would bury the real
-- ones under false positives.

-- ─── 4. Realtime for the front-desk boards ──────────────────────────────────
--
-- Roadmap note 03. Until now only restaurant_orders was published, so the
-- arrivals and room boards had to poll. REPLICA IDENTITY FULL matters for the
-- same reason it did for restaurant_orders in migration 035: without it a
-- partial UPDATE omits hotel_id from the WAL, the realtime RLS check cannot
-- evaluate, and the event is silently dropped.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'bookings'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE bookings;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'check_ins'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE check_ins;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'rooms'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE rooms;
  END IF;

  -- notifications has been read through a .stream() in notification_service
  -- since it was written, but was never published — so watchNotifications()
  -- has only ever emitted its initial snapshot and then gone quiet. This is
  -- the fix for that, not a new feature.
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
  END IF;
END $$;

ALTER TABLE bookings      REPLICA IDENTITY FULL;
ALTER TABLE check_ins     REPLICA IDENTITY FULL;
ALTER TABLE rooms         REPLICA IDENTITY FULL;
ALTER TABLE notifications REPLICA IDENTITY FULL;

NOTIFY pgrst, 'reload schema';
