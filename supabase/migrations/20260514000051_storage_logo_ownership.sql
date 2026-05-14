-- ============================================================
-- Migration 051: H-6 — Restrict property-logos uploads to org members
-- ============================================================
--
-- Previous INSERT/UPDATE policies only checked bucket_id, allowing
-- any authenticated user to upload or overwrite logos for ANY property.
-- Files are stored as {property_id}/logo.{ext}, so we extract the first
-- path segment and verify the caller belongs to that property's org.
-- ============================================================

-- Drop the permissive policies
DROP POLICY IF EXISTS "Authenticated users can upload property logos"  ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update property logos"  ON storage.objects;

-- Upload: caller must be a member of the org that owns the property
CREATE POLICY "Org members can upload property logos"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'property-logos'
    AND is_hotel_member(((storage.foldername(name))[1])::UUID)
  );

-- Update: same ownership check on the existing object
CREATE POLICY "Org members can update property logos"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'property-logos'
    AND is_hotel_member(((storage.foldername(name))[1])::UUID)
  )
  WITH CHECK (
    bucket_id = 'property-logos'
    AND is_hotel_member(((storage.foldername(name))[1])::UUID)
  );
