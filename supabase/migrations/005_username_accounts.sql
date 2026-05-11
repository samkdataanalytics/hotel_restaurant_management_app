-- ============================================================
-- 005_username_accounts.sql
-- Username-based staff accounts (no email required)
-- Run this in the Supabase SQL editor.
-- ============================================================

-- ─── 1. Add username column to profiles ───────────────────────────────────────

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS username TEXT;

-- Unique per username (case-insensitive enforced via lower() in app)
CREATE UNIQUE INDEX IF NOT EXISTS profiles_username_idx
  ON profiles(lower(username)) WHERE username IS NOT NULL;


-- ─── 2. Lookup helper — called by login screen for username-based sign-in ─────
-- Returns the synthetic email stored for a staff username so the client
-- can call signInWithPassword(email: result, password: ...).
-- Accessible without auth so the login screen can use it.

CREATE OR REPLACE FUNCTION get_email_by_username(p_username TEXT)
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT email
  FROM   profiles
  WHERE  lower(username) = lower(p_username)
  LIMIT  1;
$$;

GRANT EXECUTE ON FUNCTION get_email_by_username TO anon, authenticated;


-- ─── Done ─────────────────────────────────────────────────────────────────────
-- Staff accounts use the synthetic email pattern:
--   {username}@staff.internal
-- stored in both auth.users and profiles.email.
-- Login: user types username → client calls get_email_by_username() →
--        signs in with the resolved email + their password.
-- Account creation is handled by the create-staff-account Edge Function
-- using the service role key (so admin does not get logged out).
-- ─────────────────────────────────────────────────────────────────────────────
