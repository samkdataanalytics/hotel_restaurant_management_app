-- Regression checks for 20261020000001_security_superadmin_guard.sql.
--
-- Paste the whole file into the SQL editor and run it. No edits needed: it picks
-- an ordinary profile and a superadmin itself. It ALWAYS ends in an error, on
-- purpose — that guarantees nothing it does can commit — and the error message
-- is the report. Expect seven PASS lines and the STATE line to read
--   anon_can_promote=f authed_can_promote=f trigger=1 guard_definer=f anon_update_profiles=f
--
-- Run it only AFTER the migration. Before it, checks 1-4 will FAIL, which is
-- the point (they show the holes) — and it is still safe, because it rolls back.
--
-- Verified on hotrest_dev on 2026-10-23: all seven PASS.
--
-- Not covered: "a superadmin edits ANOTHER user's flag from a browser".
-- profiles_update is `id = auth.uid()`, so RLS matches 0 rows before the trigger
-- runs. Promotion goes through promote_to_superadmin (checks 6 and 7).
do $$
declare
  normal_id uuid; normal_email text; admin_id uuid;
  r text := '';
  n int; flag boolean; msg text; st text;
begin
  select id, email into normal_id, normal_email from public.profiles
    where not is_superadmin and coalesce(is_deleted, false) = false order by created_at limit 1;
  select id into admin_id from public.profiles where is_superadmin limit 1;
  if normal_id is null or admin_id is null then
    raise exception 'Need at least one superadmin and one ordinary profile to run these checks.';
  end if;

  -- 0. State
  r := r || format(E'STATE  anon_can_promote=%s authed_can_promote=%s trigger=%s guard_definer=%s anon_update_profiles=%s\n',
    has_function_privilege('anon','public.promote_to_superadmin(text)','EXECUTE'),
    has_function_privilege('authenticated','public.promote_to_superadmin(text)','EXECUTE'),
    (select count(*) from pg_trigger where tgrelid='public.profiles'::regclass and tgname='trg_guard_profile_privilege' and not tgisinternal),
    (select coalesce((select prosecdef from pg_proc where proname='guard_profile_privilege' and pronamespace='public'::regnamespace), null)),
    has_table_privilege('anon','public.profiles','UPDATE'));

  -- 1. ordinary user promotes themselves -> must be refused
  begin
    perform set_config('request.jwt.claims', json_build_object('sub',normal_id,'role','authenticated')::text, true);
    set local role authenticated;
    update public.profiles set is_superadmin = true where id = normal_id;
    r := r || E'1 FAIL  ordinary user set their own is_superadmin\n';
  exception when others then
    get stacked diagnostics msg = message_text, st = returned_sqlstate;
    r := r || case when st = '42501' then E'1 PASS  self-promotion refused\n' else format(E'1 FAIL  unexpected error %s %s\n', st, msg) end;
  end;
  reset role;

  -- 2. ordinary user calls the function -> must be refused
  begin
    perform set_config('request.jwt.claims', json_build_object('sub',normal_id,'role','authenticated')::text, true);
    set local role authenticated;
    perform public.promote_to_superadmin(normal_email);
    r := r || E'2 FAIL  ordinary user could call promote_to_superadmin\n';
  exception when others then
    get stacked diagnostics st = returned_sqlstate;
    r := r || case when st = '42501' then E'2 PASS  function refused to ordinary user\n' else format(E'2 FAIL  unexpected %s\n', st) end;
  end;
  reset role;

  -- 3. anon calls the function (the public key) -> must be refused
  begin
    set local role anon;
    perform public.promote_to_superadmin(normal_email);
    r := r || E'3 FAIL  anon could call promote_to_superadmin\n';
  exception when others then
    get stacked diagnostics st = returned_sqlstate;
    r := r || case when st = '42501' then E'3 PASS  function refused to anon\n' else format(E'3 FAIL  unexpected %s\n', st) end;
  end;
  reset role;

  -- 4. a superadmin changes their OWN flag -> must be refused
  begin
    perform set_config('request.jwt.claims', json_build_object('sub',admin_id,'role','authenticated')::text, true);
    set local role authenticated;
    update public.profiles set is_superadmin = false where id = admin_id;
    r := r || E'4 FAIL  superadmin changed their own flag\n';
  exception when others then
    get stacked diagnostics st = returned_sqlstate;
    r := r || case when st = '42501' then E'4 PASS  superadmin cannot change own flag\n' else format(E'4 FAIL  unexpected %s\n', st) end;
  end;
  reset role;

  -- 5. ordinary profile edit -> must still work
  begin
    perform set_config('request.jwt.claims', json_build_object('sub',normal_id,'role','authenticated')::text, true);
    set local role authenticated;
    update public.profiles set job_title = 'guard-test' where id = normal_id;
    get diagnostics n = row_count;
    r := r || case when n = 1 then E'5 PASS  ordinary profile edit still works\n' else format(E'5 FAIL  updated %s rows\n', n) end;
  exception when others then
    get stacked diagnostics msg = message_text;
    r := r || format(E'5 FAIL  ordinary edit raised: %s\n', msg);
  end;
  reset role;

  -- 6. service role promotes through the function -> must still work
  begin
    perform set_config('request.jwt.claims', json_build_object('role','service_role')::text, true);
    set local role service_role;
    perform public.promote_to_superadmin(normal_email);
    select is_superadmin into flag from public.profiles where id = normal_id;
    r := r || case when flag then E'6 PASS  service role can still promote\n' else E'6 FAIL  service role call did nothing\n' end;
  exception when others then
    get stacked diagnostics msg = message_text;
    r := r || format(E'6 FAIL  service role raised: %s\n', msg);
  end;
  reset role;

  -- 7. SQL editor / migration role promotes through the function -> must still work
  begin
    perform public.promote_to_superadmin(normal_email);
    select is_superadmin into flag from public.profiles where id = normal_id;
    r := r || case when flag then format(E'7 PASS  %s can still promote\n', session_user) else E'7 FAIL  call did nothing\n' end;
  exception when others then
    get stacked diagnostics msg = message_text;
    r := r || format(E'7 FAIL  raised: %s\n', msg);
  end;

  -- Always abort, so nothing here can ever be committed. The message is the report.
  raise exception E'GUARD CHECK REPORT (everything rolled back)\n%', r;
end $$;
