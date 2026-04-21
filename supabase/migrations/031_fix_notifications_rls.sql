-- ─────────────────────────────────────────────────────────────────────────────
-- 031_fix_notifications_rls.sql
--
-- Fixes "permission denied for table notifications" error that triggers
-- when the application attempts to auto-insert housekeeping notifications,
-- because the old policy relied solely on the legacy `current_hotel_id()`.
-- ─────────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS notifications_staff ON notifications;

CREATE POLICY notifications_staff ON notifications
  USING (
    hotel_id IN (
        SELECT ps.property_id
        FROM property_staff ps
        WHERE ps.user_id = auth.uid()
          AND (ps.is_deleted = FALSE OR ps.is_deleted IS NULL)
    )
    OR hotel_id IN (
        SELECT h.id
        FROM hotels h
        JOIN organization_members om ON om.org_id = h.org_id
        WHERE om.user_id = auth.uid()
          AND (om.is_deleted = FALSE OR om.is_deleted IS NULL)
    )
    OR hotel_id IN (
        SELECT hu.hotel_id
        FROM hotel_users hu
        WHERE hu.user_id = auth.uid()
    )
    OR is_superadmin()
  )
  WITH CHECK (
    hotel_id IN (
        SELECT ps.property_id
        FROM property_staff ps
        WHERE ps.user_id = auth.uid()
          AND (ps.is_deleted = FALSE OR ps.is_deleted IS NULL)
    )
    OR hotel_id IN (
        SELECT h.id
        FROM hotels h
        JOIN organization_members om ON om.org_id = h.org_id
        WHERE om.user_id = auth.uid()
          AND (om.is_deleted = FALSE OR om.is_deleted IS NULL)
    )
    OR hotel_id IN (
        SELECT hu.hotel_id
        FROM hotel_users hu
        WHERE hu.user_id = auth.uid()
    )
    OR is_superadmin()
  );
