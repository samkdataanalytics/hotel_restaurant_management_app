-- ============================================================
-- 006_service_role_grants.sql
-- Grant table access to service_role so Edge Functions can
-- perform admin operations (create staff accounts, etc.)
-- Run this in the Supabase SQL editor.
-- ============================================================

GRANT ALL ON TABLE profiles                  TO service_role;
GRANT ALL ON TABLE organization_members      TO service_role;
GRANT ALL ON TABLE property_staff            TO service_role;
GRANT ALL ON TABLE property_staff_permissions TO service_role;
GRANT ALL ON TABLE staff_invites             TO service_role;
