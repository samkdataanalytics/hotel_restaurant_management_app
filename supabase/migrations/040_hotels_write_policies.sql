-- Adds missing INSERT/UPDATE/DELETE policies to hotels and hotel_settings.
-- Without these, any authenticated write (from the Flutter app) is denied
-- because RLS is enabled but only SELECT policies existed.

-- ── hotels ───────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS hotels_insert ON hotels;
CREATE POLICY hotels_insert ON hotels
  FOR INSERT WITH CHECK (
    org_id = current_org_id()
    OR is_superadmin()
  );

DROP POLICY IF EXISTS hotels_update ON hotels;
CREATE POLICY hotels_update ON hotels
  FOR UPDATE USING (
    org_id = current_org_id()
    OR is_superadmin()
  )
  WITH CHECK (
    org_id = current_org_id()
    OR is_superadmin()
  );

DROP POLICY IF EXISTS hotels_delete ON hotels;
CREATE POLICY hotels_delete ON hotels
  FOR DELETE USING (
    org_id = current_org_id()
    OR is_superadmin()
  );

-- ── hotel_settings ────────────────────────────────────────────────────────────
-- hotel_settings_update already exists; only the INSERT path was missing
-- (needed by the upsert in addProperty).

DROP POLICY IF EXISTS hotel_settings_insert ON hotel_settings;
CREATE POLICY hotel_settings_insert ON hotel_settings
  FOR INSERT WITH CHECK (
    hotel_id IN (
      SELECT id FROM hotels WHERE org_id = current_org_id()
    )
    OR is_superadmin()
  );

-- ── hotel_users ───────────────────────────────────────────────────────────────
-- Allow org owners/admins to add staff entries (addProperty needs this).

DROP POLICY IF EXISTS hotel_users_insert ON hotel_users;
CREATE POLICY hotel_users_insert ON hotel_users
  FOR INSERT WITH CHECK (
    hotel_id IN (
      SELECT id FROM hotels WHERE org_id = current_org_id()
    )
    OR is_superadmin()
  );
