-- ============================================================
-- Migration 053: Restore anon grants that break existing features
-- ============================================================
--
-- Migration 048 revoked two functions from anon that are legitimately
-- needed by unauthenticated callers:
--
--   cancel_guest_order: the function comment explicitly states
--   "Called by anon (guest QR) or authenticated (staff) clients."
--   Guest ordering UI uses the Supabase anon key — there is no
--   auth session available when a table guest cancels their order.
--
--   get_email_by_username: no longer needed from anon — the login
--   screen has been updated to construct the synthetic email directly
--   without an RPC lookup (see login_screen.dart fix). The revoke
--   can stay; this migration only restores cancel_guest_order.
-- ============================================================

GRANT EXECUTE ON FUNCTION cancel_guest_order(UUID) TO anon;
