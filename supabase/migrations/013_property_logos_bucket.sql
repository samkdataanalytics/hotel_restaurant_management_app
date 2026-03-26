-- ============================================================
-- Migration 013: Property logos storage bucket
--
-- Creates a public Supabase Storage bucket for property logos.
-- Logos are uploaded as: property-logos/{property_id}/logo.{ext}
-- The bucket is public so logo URLs can be embedded in invoices
-- and served without auth tokens.
-- ============================================================

-- Create the bucket (idempotent via ON CONFLICT DO NOTHING)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'property-logos',
  'property-logos',
  true,
  2097152,                              -- 2 MB max per file
  ARRAY['image/jpeg','image/png','image/webp','image/gif']
)
ON CONFLICT (id) DO NOTHING;

-- Allow any authenticated user to upload/update their property logo
CREATE POLICY "Authenticated users can upload property logos"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'property-logos');

CREATE POLICY "Authenticated users can update property logos"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (bucket_id = 'property-logos');

-- Public read access (bucket is public, but RLS still needs a policy)
CREATE POLICY "Public read access for property logos"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'property-logos');
