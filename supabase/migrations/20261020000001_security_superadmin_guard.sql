-- Close the two ways an ordinary user could make themselves a superadmin.
--
-- Found while planning the website CMS, whose write access is is_superadmin():
-- that flag is the root of trust for plan prices, every company and lead, org
-- deletion, and now the public site. It was not protected.
--
--   1. promote_to_superadmin(text) had no permission check in its body and
--      EXECUTE was held by PUBLIC, so anyone with the public anon key could
--      promote any registered email through /rest/v1/rpc/.
--   2. profiles_update allows a user to update their own row and nothing
--      restricted which columns, so `UPDATE profiles SET is_superadmin = true
--      WHERE id = auth.uid()` worked for any signed-in user. On dev the
--      profiles_insert policy (id = auth.uid()) allowed the same through INSERT.
--
-- Checked read-only on both projects before writing this; no abuse was
-- visible in the 24h of logs available, but the free plan keeps no more, and
-- profiles has no updated_at trigger or audit trail to say otherwise.

-- ─── 1. The function ────────────────────────────────────────────────────────
--
-- The body check is defence in depth behind the REVOKE below. It accepts the
-- SQL editor / migrations (session_user), the service role, and an existing
-- superadmin. It cannot use current_user: inside a SECURITY DEFINER function
-- that is the function's owner, so it is true for every caller. (See the note
-- on the billing guards at the end of this file.)
CREATE OR REPLACE FUNCTION public.promote_to_superadmin(target_email text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT (
    session_user IN ('postgres', 'supabase_admin')
    OR coalesce(auth.role(), '') = 'service_role'
    OR is_superadmin()
  ) THEN
    RAISE EXCEPTION 'Not authorized to promote superadmins.'
      USING ERRCODE = '42501';
  END IF;

  INSERT INTO profiles (id, is_superadmin)
  SELECT id, true
  FROM   auth.users
  WHERE  email = target_email
  ON CONFLICT (id) DO UPDATE SET is_superadmin = true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.promote_to_superadmin(text)
  FROM PUBLIC, anon, authenticated;

-- ─── 2. The column ──────────────────────────────────────────────────────────
--
-- SECURITY INVOKER on purpose, and the reason this is not a copy of
-- guard_org_sensitive_columns. There, current_user IN ('postgres', ...) is the
-- bypass, but that function is SECURITY DEFINER owned by postgres, so
-- current_user is always postgres and the bypass is always taken. Run as the
-- invoker, current_user is the real caller: 'authenticated' for a browser
-- session, 'service_role' for the service key, 'postgres' for migrations.
--
-- Other SECURITY DEFINER functions that touch profiles (upsert_my_profile,
-- handle_new_user, soft_delete_profile) run as their owner and so pass, which
-- is right: none of them change this flag.
CREATE OR REPLACE FUNCTION public.guard_profile_privilege()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  IF current_user IN ('postgres', 'supabase_admin', 'service_role') THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF NEW.is_superadmin AND NOT is_superadmin() THEN
      RAISE EXCEPTION 'Not authorized to create a superadmin profile.'
        USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.is_superadmin IS DISTINCT FROM OLD.is_superadmin
     OR NEW.id IS DISTINCT FROM OLD.id THEN
    -- A superadmin may change ANOTHER user's flag. Never their own: that
    -- would let a compromised session grant itself nothing it lacks, but it
    -- would also let the last superadmin lock everyone out by accident.
    IF is_superadmin()
       AND NEW.id IS NOT DISTINCT FROM OLD.id
       AND OLD.id IS DISTINCT FROM auth.uid() THEN
      RETURN NEW;
    END IF;
    RAISE EXCEPTION 'Not authorized to change superadmin status.'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_profile_privilege ON public.profiles;
CREATE TRIGGER trg_guard_profile_privilege
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.guard_profile_privilege();

-- anon never legitimately writes profiles; dev had the grant by default.
REVOKE INSERT, UPDATE ON public.profiles FROM anon;

-- ─── 3. The check every policy relies on ────────────────────────────────────
-- SECURITY DEFINER without a pinned search_path can be redirected by a schema
-- earlier on the caller's path.
ALTER FUNCTION public.is_superadmin() SET search_path = public;

NOTIFY pgrst, 'reload schema';

-- ─── Not fixed here: the billing guards ─────────────────────────────────────
-- guard_org_sensitive_columns and guard_billing_permission are SECURITY
-- DEFINER, owned by postgres, and open with `IF current_user IN ('postgres',
-- ...) THEN RETURN NEW`. By the argument above that is true for every caller,
-- so they almost certainly never fire. Not exercised, and repairing them
-- changes live signup / billing / webhook behaviour, so it needs its own
-- tested migration.
