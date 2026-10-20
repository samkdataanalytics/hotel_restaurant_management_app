-- Receipt photos for expenses captured on the staff mobile app (M-03).
--
-- Separate from guest-documents deliberately. These are business records with a
-- different audience and a different lifetime to a photographed passport:
-- receipts want keeping for the tax year, identity documents want deleting as
-- soon as the stay is reconciled. Sharing a bucket would force one retention
-- policy onto both.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'expense-receipts',
  'expense-receipts',
  FALSE,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- Same path convention as guest-documents: '{hotel_id}/{expense_id}/{file}',
-- so the first segment is the tenant key and is_hotel_member() gates on it.
DROP POLICY IF EXISTS expense_receipts_select ON storage.objects;
CREATE POLICY expense_receipts_select ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'expense-receipts'
    AND is_hotel_member(((storage.foldername(name))[1])::uuid)
  );

DROP POLICY IF EXISTS expense_receipts_insert ON storage.objects;
CREATE POLICY expense_receipts_insert ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'expense-receipts'
    AND is_hotel_member(((storage.foldername(name))[1])::uuid)
  );

DROP POLICY IF EXISTS expense_receipts_update ON storage.objects;
CREATE POLICY expense_receipts_update ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'expense-receipts'
    AND is_hotel_member(((storage.foldername(name))[1])::uuid)
  );

DROP POLICY IF EXISTS expense_receipts_delete ON storage.objects;
CREATE POLICY expense_receipts_delete ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'expense-receipts'
    AND is_hotel_member(((storage.foldername(name))[1])::uuid)
  );

-- Nullable: the great majority of expenses are still entered without a photo,
-- and requiring one would push staff back to keeping paper.
ALTER TABLE expenses
  ADD COLUMN IF NOT EXISTS receipt_url TEXT;

COMMENT ON COLUMN expenses.receipt_url IS
  'Object path in the private expense-receipts bucket.';

NOTIFY pgrst, 'reload schema';
