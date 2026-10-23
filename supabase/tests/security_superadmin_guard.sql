-- Regression checks for 20261020000001_security_superadmin_guard.sql.
--
-- Run each numbered block on its own in the SQL editor (the editor shows only
-- the last statement's result, and the "must fail" blocks end in an error, which
-- is the passing outcome). Every block rolls back, so nothing is changed.
--
-- Substitute two ids from `select id, email, is_superadmin from profiles`:
--   :normal = any user with is_superadmin = false
--   :admin  = the superadmin
-- Verified on hotrest_dev (devadmin / tin@abc.com) on 2026-10-23.

-- 0. STATE — expect: false, false, 1, false, {search_path=public}, false
select has_function_privilege('anon','public.promote_to_superadmin(text)','EXECUTE')          as anon_can_promote,
       has_function_privilege('authenticated','public.promote_to_superadmin(text)','EXECUTE') as authed_can_promote,
       (select count(*) from pg_trigger where tgrelid='public.profiles'::regclass
          and tgname='trg_guard_profile_privilege' and not tgisinternal)                       as guard_trigger_present,
       (select prosecdef from pg_proc where oid='public.guard_profile_privilege()'::regprocedure) as guard_is_definer,
       (select proconfig::text from pg_proc where oid='public.is_superadmin()'::regprocedure)  as is_superadmin_config,
       has_table_privilege('anon','public.profiles','UPDATE')                                  as anon_can_update_profiles;

-- 1. MUST FAIL: ordinary user promotes themselves
--    expect: ERROR 42501 "Not authorized to change superadmin status."
begin;
select set_config('request.jwt.claims', '{"sub":"<normal>","role":"authenticated"}', true);
set local role authenticated;
update public.profiles set is_superadmin = true where id = '<normal>';
rollback;

-- 2. MUST FAIL: ordinary user calls the function
--    expect: ERROR 42501 "permission denied for function promote_to_superadmin"
begin;
select set_config('request.jwt.claims', '{"sub":"<normal>","role":"authenticated"}', true);
set local role authenticated;
select public.promote_to_superadmin('someone@example.com');
rollback;

-- 3. MUST FAIL: anon calls the function (the public anon key)
--    expect: ERROR 42501 "permission denied for function promote_to_superadmin"
begin;
set local role anon;
select public.promote_to_superadmin('someone@example.com');
rollback;

-- 4. MUST FAIL: a superadmin cannot change their OWN flag
--    expect: ERROR 42501 "Not authorized to change superadmin status."
begin;
select set_config('request.jwt.claims', '{"sub":"<admin>","role":"authenticated"}', true);
set local role authenticated;
update public.profiles set is_superadmin = false where id = '<admin>';
rollback;

-- 5. MUST SUCCEED: an ordinary profile edit is unaffected
--    expect: one row, is_superadmin = false
begin;
select set_config('request.jwt.claims', '{"sub":"<normal>","role":"authenticated"}', true);
set local role authenticated;
with changed as (update public.profiles set job_title = 'guard-test'
                 where id = '<normal>' returning email, job_title, is_superadmin)
select * from changed;
rollback;

-- 6. MUST SUCCEED: the service role can still promote (webhooks, edge functions)
--    expect: is_superadmin = true (rolled back)
begin;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
set local role service_role;
select public.promote_to_superadmin('<normal email>');
select email, is_superadmin from public.profiles where email = '<normal email>';
rollback;

-- 7. MUST SUCCEED: the SQL editor / migration role can still promote
--    (this is how supabase/migrations/README.md says to create the first admin)
begin;
select public.promote_to_superadmin('<normal email>');
select session_user, email, is_superadmin from public.profiles where email = '<normal email>';
rollback;

-- Not testable from a browser session: "a superadmin edits ANOTHER user's flag".
-- profiles_update is `id = auth.uid()`, so RLS matches 0 rows before the trigger
-- runs (verified: rows_updated = 0). Promotion goes through the function above.
