-- ============================================================
-- Migration 057: Fix signup trigger (search_path + email)
-- ============================================================
--
-- handle_new_user() was defined without SET search_path = public.
-- On newer Supabase instances, SECURITY DEFINER functions without
-- an explicit search_path default to an empty path, causing the
-- INSERT INTO profiles to fail with "relation not found" — which
-- Supabase Auth surfaces as "Database error saving new user".
--
-- Fix: replace handle_new_user with a version that has the correct
-- search_path and also stores email, then re-point the trigger.
-- ============================================================

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email)
  VALUES (NEW.id, COALESCE(NEW.email, ''))
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- Re-point the trigger to the updated function
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();
