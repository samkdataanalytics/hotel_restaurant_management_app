-- ============================================================
-- Migration 065: organization_members -> profiles foreign key
-- ============================================================
-- Fixes PGRST200 in the SuperAdmin "Members" tab:
--   "Could not find a relationship between 'organization_members'
--    and 'profiles' in the schema cache"
--
-- Cause: organization_members.user_id and profiles.id BOTH reference
-- auth.users(id), but there is no FK directly between the two tables.
-- PostgREST only embeds across a declared FK between tables in an
-- exposed schema -- it will not infer a join through auth.users, which
-- is not exposed. So .select('*, profiles(full_name, email)') fails.
--
-- Fix: declare the missing FK. Backfill first, because handle_new_user()
-- was broken for a period (see migration 057), so some members may have
-- no profiles row and a naive ADD CONSTRAINT would fail on them.
-- Idempotent: backfill is ON CONFLICT DO NOTHING; constraint is guarded.
-- ============================================================

-- -- 1. Backfill any member whose profiles row is missing ------------------
-- Pulls the address from auth.users so the Members tab shows a real email
-- rather than a blank cell. Runs as postgres in migration context.
INSERT INTO public.profiles (id, email)
SELECT DISTINCT om.user_id, COALESCE(u.email, '')
FROM   organization_members om
JOIN   auth.users u ON u.id = om.user_id
WHERE  NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = om.user_id)
ON CONFLICT (id) DO NOTHING;

-- -- 2. Declare the FK PostgREST needs to embed profiles -------------------
-- ON DELETE CASCADE matches the existing auth.users cascade on both sides,
-- so deleting a user still removes the membership exactly as before.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE  conname = 'organization_members_user_id_profiles_fkey'
  ) THEN
    ALTER TABLE organization_members
      ADD CONSTRAINT organization_members_user_id_profiles_fkey
      FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
  END IF;
END $$;

-- -- 3. Tell PostgREST to pick up the new relationship ---------------------
NOTIFY pgrst, 'reload schema';
