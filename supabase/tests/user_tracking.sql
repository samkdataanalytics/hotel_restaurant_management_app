-- Regression checks for 20261023000002_superadmin_user_tracking.sql.
--
-- Paste the whole file into the SQL editor and run it, AFTER the migration. It
-- picks a superadmin and an ordinary profile itself and ALWAYS ends in an error on
-- purpose, so nothing it does can commit. The error message is the report: every
-- line should read PASS.
--
-- Verified 2026-10-23 on a local Postgres 17 with stand-in schemas. Not yet run on
-- hotrest_dev (the migration has not been applied there).
do $$
declare
  normal_id uuid; admin_id uuid;
  r text := '';
  n bigint; tc bigint; j jsonb; st text; t timestamptz; rec record; e text;
begin
  select id into normal_id from public.profiles
    where not is_superadmin and coalesce(is_deleted, false) = false order by created_at limit 1;
  select id into admin_id from public.profiles where is_superadmin limit 1;
  if normal_id is null or admin_id is null then
    raise exception 'Need at least one superadmin and one ordinary profile to run these checks.';
  end if;

  -- 1. an ordinary user is refused by every console function
  perform set_config('request.jwt.claims', json_build_object('sub', normal_id, 'role', 'authenticated')::text, true);
  set local role authenticated;
  foreach e in array array['overview', 'list', 'detail', 'activity'] loop
    begin
      if e = 'overview' then perform public.superadmin_users_overview();
      elsif e = 'list' then perform * from public.superadmin_list_users('', 'all', 10, 0);
      elsif e = 'detail' then perform public.superadmin_user_detail(normal_id);
      else perform * from public.superadmin_user_activity(null, null, null, 10, null);
      end if;
      r := r || format(E'1  FAIL  ordinary user ran %s\n', e);
    exception when others then
      get stacked diagnostics st = returned_sqlstate;
      r := r || case when st = '42501' then format(E'1  PASS  ordinary user refused: %s\n', e) else format(E'1  FAIL  %s: unexpected %s\n', e, st) end;
    end;
  end loop;

  -- 2. ... and cannot read or write the log directly
  select count(*) into n from public.user_activity;
  r := r || case when n = 0 then E'2a PASS  ordinary user sees no activity rows\n' else format(E'2a FAIL  saw %s\n', n) end;
  begin
    insert into public.user_activity (action, entity) values ('x.y', 'x');
    r := r || E'2b FAIL  ordinary user inserted into the log\n';
  exception when others then
    get stacked diagnostics st = returned_sqlstate;
    r := r || case when st = '42501' then E'2b PASS  direct insert refused\n' else format(E'2b FAIL  %s\n', st) end;
  end;
  reset role;

  -- 3. anon cannot execute them
  set local role anon;
  begin
    perform public.superadmin_users_overview();
    r := r || E'3  FAIL  anon ran overview\n';
  exception when others then
    get stacked diagnostics st = returned_sqlstate;
    r := r || case when st = '42501' then E'3  PASS  anon cannot execute\n' else format(E'3  FAIL  %s\n', st) end;
  end;
  reset role;

  -- 4. an action by a signed-in user is logged with that user as the actor
  perform set_config('request.jwt.claims', json_build_object('sub', normal_id, 'role', 'authenticated')::text, true);
  set local role authenticated;
  update public.profiles set job_title = 'Tracking test ' || to_char(clock_timestamp(), 'HH24MISSUS') where id = normal_id;
  reset role;
  select count(*) into n from public.user_activity
    where user_id = normal_id and action = 'profile.updated' and detail #>> '{changed,job_title,to}' like 'Tracking test%';
  r := r || case when n = 1 then E'4  PASS  profile edit logged against the user, with the change\n' else format(E'4  FAIL  %s rows\n', n) end;

  -- 5. a sign-in is logged
  update auth.users set last_sign_in_at = now() where id = normal_id;
  select count(*) into n from public.user_activity where user_id = normal_id and action = 'auth.sign_in' and (detail->>'backfilled') is null;
  r := r || case when n >= 1 then E'5  PASS  sign-in logged\n' else E'5  FAIL  no sign-in entry\n' end;

  -- 6. an unwatched update is not logged
  select count(*) into n from public.user_activity where user_id = normal_id;
  update public.profiles set avatar_url = 'x' where id = normal_id;
  r := r || case when (select count(*) from public.user_activity where user_id = normal_id) = n
                 then E'6  PASS  change to an unwatched column is not logged\n' else E'6  FAIL  unwatched update logged\n' end;

  -- 7. the superadmin sees everything through the functions
  perform set_config('request.jwt.claims', json_build_object('sub', admin_id, 'role', 'authenticated')::text, true);
  set local role authenticated;

  j := public.superadmin_users_overview();
  r := r || case when (j->>'total')::int >= 2 and j ? 'active_7d' and j ? 'unconfirmed' and j ? 'actions_24h'
                 then E'7a PASS  overview has its figures\n' else format(E'7a FAIL  %s\n', j) end;

  select count(*), coalesce(max(total_count), 0) into n, tc from public.superadmin_list_users('', 'all', 100, 0);
  r := r || case when n >= 2 and n = tc then E'7b PASS  list returns every user, total_count matches\n'
                 else format(E'7b FAIL  rows=%s total=%s\n', n, tc) end;

  select count(*) into n from public.superadmin_list_users('', 'all', 1, 0);
  r := r || case when n = 1 then E'7c PASS  limit respected\n' else format(E'7c FAIL  %s\n', n) end;

  select email into e from public.profiles where id = normal_id;
  select count(*) into n from public.superadmin_list_users(split_part(coalesce(nullif(e,''), 'zzz'), '@', 1), 'all', 50, 0);
  r := r || case when n >= 1 or coalesce(e, '') = '' then E'7d PASS  search by email finds the user\n' else E'7d FAIL  search found nobody\n' end;

  select count(*) into n from public.superadmin_list_users('%', 'all', 50, 0);
  r := r || case when n = 0 then E'7e PASS  a bare % is searched for literally, not as a wildcard\n'
                 else format(E'7e FAIL  %% matched %s users\n', n) end;

  select count(*) into n from public.superadmin_list_users('', 'superadmin', 50, 0) where is_superadmin;
  r := r || case when n >= 1 and n = (select count(*) from public.superadmin_list_users('', 'superadmin', 50, 0))
                 then E'7f PASS  superadmin filter\n' else E'7f FAIL  filter wrong\n' end;

  select count(*) into n from public.superadmin_list_users('', 'not-a-filter', 50, 0);
  r := r || case when n >= 2 then E'7g PASS  an unknown filter behaves like "all"\n' else E'7g FAIL\n' end;

  select count(*) into n from public.superadmin_list_users('', 'all', 100000, -5);
  r := r || E'7h PASS  absurd limit/offset are clamped\n';

  -- 8. user detail
  j := public.superadmin_user_detail(normal_id);
  r := r || case when j ? 'orgs' and j ? 'sessions' and j ? 'activity_counts' and j ? 'properties' and j ? 'payments'
                      and (j->>'user_id')::uuid = normal_id
                 then E'8a PASS  detail has every section\n' else format(E'8a FAIL  %s\n', j) end;
  r := r || case when exists (select 1 from jsonb_array_elements(j->'activity_counts') c where c->>'action' = 'profile.updated')
                 then E'8b PASS  detail counts the logged action\n' else E'8b FAIL  action missing from counts\n' end;
  begin
    perform public.superadmin_user_detail('00000000-0000-0000-0000-00000000dead');
    r := r || E'8c FAIL  unknown user returned\n';
  exception when others then
    get stacked diagnostics st = returned_sqlstate;
    r := r || case when st = 'P0002' then E'8c PASS  unknown user -> error\n' else format(E'8c FAIL  %s\n', st) end;
  end;

  -- 9. activity feed
  select count(*) into n from public.superadmin_user_activity(normal_id, null, null, 50, null);
  r := r || case when n >= 2 then E'9a PASS  the user\'s activity is listed\n' else format(E'9a FAIL  %s rows\n', n) end;

  select count(*) into n from public.superadmin_user_activity(normal_id, null, 'profile.', 50, null);
  r := r || case when n >= 1 and n = (select count(*) from public.superadmin_user_activity(normal_id, null, null, 50, null) where action like 'profile.%')
                 then E'9b PASS  action prefix filter\n' else format(E'9b FAIL  %s\n', n) end;

  select count(*) into n from public.superadmin_user_activity(normal_id, null, '_', 50, null);
  r := r || case when n = 0 then E'9c PASS  "_" in the prefix is literal\n' else format(E'9c FAIL  %s\n', n) end;

  select min(created_at) into t from public.superadmin_user_activity(normal_id, null, null, 50, null);
  select count(*) into n from public.superadmin_user_activity(normal_id, null, null, 50, t);
  r := r || case when n = 0 then E'9d PASS  paging: nothing older than the oldest\n' else format(E'9d FAIL  %s older rows\n', n) end;

  select * into rec from public.superadmin_user_activity(normal_id, null, 'profile.updated', 1, null);
  r := r || case when rec.user_id = normal_id and rec.detail #>> '{changed,job_title,to}' like 'Tracking test%'
                 then E'9e PASS  entry carries actor and the change\n' else E'9e FAIL  entry wrong\n' end;
  reset role;

  -- 10. nothing personal about guests is copied into an entry
  select count(*) into n from public.user_activity
    where detail::text ~* '(passport|nic|id_number|date_of_birth|signature|id_document)';
  r := r || case when n = 0 then E'10 PASS  no guest document fields in any entry\n' else format(E'10 FAIL  %s\n', n) end;

  -- 11. logging cannot block the write it observes
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', normal_id, 'role', 'authenticated')::text, true);
    set local role authenticated;
    update public.profiles set full_name = full_name || '' where id = normal_id;   -- unchanged watched column: no entry, no error
    r := r || E'11 PASS  a no-op watched update does not fail\n';
  exception when others then
    r := r || E'11 FAIL  update failed\n';
  end;
  reset role;

  raise exception E'\n%\n(rolled back on purpose)', r;
end $$;
