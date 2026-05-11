-- ─────────────────────────────────────────────────────────────────────────────
-- 030_fix_hotels_rls_recursion.sql
--
-- Fixes "infinite recursion detected in policy for relation hotels" error.
--
-- Root cause: The `hotels_select_member` policy (from 028_soft_delete.sql)
-- contained a sub-SELECT on `hotels` itself to resolve the org_id join,
-- triggering the same RLS policy recursively.
--
-- Fix: Drop ALL existing SELECT/UPDATE policies on `hotels` and recreate
-- them using only foreign-key look-ups into `property_staff` and
-- `organization_members` (never self-referencing back into `hotels`).
-- ─────────────────────────────────────────────────────────────────────────────

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  1. Drop every existing policy on `hotels`                              ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- From 001_multi_tenancy.sql
DROP POLICY IF EXISTS hotels_select         ON hotels;

-- From 002_saas_schema.sql
DROP POLICY IF EXISTS hotels_org_select     ON hotels;

-- From 014_guest_order_rls.sql
DROP POLICY IF EXISTS hotels_guest_read     ON hotels;

-- From 028_soft_delete.sql (the one that causes recursion)
DROP POLICY IF EXISTS hotels_select_member  ON hotels;


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  2. Create a single, non-recursive SELECT policy                        ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
--
-- Access paths (any one is sufficient):
--   a) User has a property_staff row for this hotel
--   b) User is an org member of this hotel's org
--   c) User is a superadmin
--   d) Legacy: hotel_users row
--
-- IMPORTANT: We never SELECT from `hotels` inside this policy.
-- We only read `property_staff`, `organization_members`, and `hotel_users`.

CREATE POLICY hotels_select_v2 ON hotels
  FOR SELECT USING (
    -- Exclude soft-deleted
    (is_deleted = FALSE OR is_deleted IS NULL)
    AND (
      -- (a) Direct property staff
      id IN (
        SELECT ps.property_id
        FROM property_staff ps
        WHERE ps.user_id = auth.uid()
          AND (ps.is_deleted = FALSE OR ps.is_deleted IS NULL)
      )
      -- (b) Org membership → matches hotel.org_id
      OR org_id IN (
        SELECT om.org_id
        FROM organization_members om
        WHERE om.user_id = auth.uid()
          AND (om.is_deleted = FALSE OR om.is_deleted IS NULL)
      )
      -- (c) Legacy hotel_users
      OR id IN (
        SELECT hu.hotel_id
        FROM hotel_users hu
        WHERE hu.user_id = auth.uid()
      )
      -- (d) Superadmin
      OR is_superadmin()
    )
  );


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  3. UPDATE policy (so Edit Property dialog can save changes)             ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
--
-- Re-uses the same non-recursive access check.

DROP POLICY IF EXISTS hotels_update ON hotels;

CREATE POLICY hotels_update ON hotels
  FOR UPDATE USING (
    (is_deleted = FALSE OR is_deleted IS NULL)
    AND (
      id IN (
        SELECT ps.property_id
        FROM property_staff ps
        WHERE ps.user_id = auth.uid()
          AND (ps.is_deleted = FALSE OR ps.is_deleted IS NULL)
      )
      OR org_id IN (
        SELECT om.org_id
        FROM organization_members om
        WHERE om.user_id = auth.uid()
          AND (om.is_deleted = FALSE OR om.is_deleted IS NULL)
      )
      OR id IN (
        SELECT hu.hotel_id
        FROM hotel_users hu
        WHERE hu.user_id = auth.uid()
      )
      OR is_superadmin()
    )
  )
  WITH CHECK (
    (is_deleted = FALSE OR is_deleted IS NULL)
    AND (
      id IN (
        SELECT ps.property_id
        FROM property_staff ps
        WHERE ps.user_id = auth.uid()
          AND (ps.is_deleted = FALSE OR ps.is_deleted IS NULL)
      )
      OR org_id IN (
        SELECT om.org_id
        FROM organization_members om
        WHERE om.user_id = auth.uid()
          AND (om.is_deleted = FALSE OR om.is_deleted IS NULL)
      )
      OR id IN (
        SELECT hu.hotel_id
        FROM hotel_users hu
        WHERE hu.user_id = auth.uid()
      )
      OR is_superadmin()
    )
  );


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  4. Guest/anon read policy (safe — only returns minimal data)           ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
-- Needed for the guest ordering flow where a guest scans a QR and
-- needs to see the property name/logo.

CREATE POLICY hotels_guest_read ON hotels
  FOR SELECT TO anon
  USING (
    (is_deleted = FALSE OR is_deleted IS NULL)
    AND status = 'active'
  );
