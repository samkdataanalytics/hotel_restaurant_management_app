-- Regression check for 20261103000001_superadmin_optional_tables.sql.
--
-- The user and company detail screens read staff_invites, a table some databases
-- never created. This drops it (inside the transaction), calls both functions, and
-- expects them to answer with an invite count of 0 instead of failing with 42P01.
--
-- Paste the whole file into the SQL editor AFTER that migration (and 20261023000002
-- and 20261023000004). It ALWAYS ends in an error on purpose, which also undoes the
-- DROP TABLE, so nothing is changed. The message is the report: every line should
-- read PASS. Do not run it on a database where another session is using the table
-- (the drop briefly locks it until the rollback).
do $$
declare
  admin_id uuid; some_user uuid; org uuid;
  r text := '';
  j jsonb; st text; n bigint;
begin
  select id into admin_id from public.profiles where is_superadmin limit 1;
  select id into some_user from public.profiles order by created_at limit 1;
  select o.id into org from public.organizations o order by o.created_at limit 1;
  if admin_id is null or some_user is null or org is null then
    raise exception 'Need a superadmin, a profile and a company to run these checks.';
  end if;

  perform set_config('request.jwt.claims', json_build_object('sub', admin_id, 'role', 'authenticated')::text, true);

  -- 1. with the table present both work (and the user/company calls still return their sections)
  set local role authenticated;
  j := public.superadmin_user_detail(some_user);
  r := r || case when j ? 'invites_sent' and j ? 'payments' and j ? 'activity_counts' then E'1a PASS  user detail works with the table present\n' else E'1a FAIL\n' end;
  j := public.superadmin_company_detail(org);
  r := r || case when j #> '{totals,pending_invites}' is not null and j ? 'members' then E'1b PASS  company detail works with the table present\n' else E'1b FAIL\n' end;
  reset role;

  -- 2. the table is absent
  if to_regclass('public.staff_invites') is not null then
    drop table public.staff_invites cascade;
  end if;
  r := r || case when to_regclass('public.staff_invites') is null then E'2  PASS  staff_invites is gone for the rest of this test\n' else E'2  FAIL  could not drop it\n' end;

  set local role authenticated;
  begin
    j := public.superadmin_user_detail(some_user);
    r := r || case when (j ->> 'invites_sent')::int = 0 and j ? 'payments' and j ? 'sessions' and j ? 'activity_counts'
                   then E'3a PASS  user detail answers without the table (0 invites, everything else intact)\n'
                   else format(E'3a FAIL  invites_sent=%s\n', j ->> 'invites_sent') end;
  exception when others then
    get stacked diagnostics st = returned_sqlstate;
    r := r || format(E'3a FAIL  user detail raised %s\n', st);
  end;
  begin
    j := public.superadmin_company_detail(org);
    r := r || case when (j #>> '{totals,pending_invites}')::int = 0 and j ? 'members' and j ? 'properties' and j ? 'limits'
                   then E'3b PASS  company detail answers without the table (0 pending, everything else intact)\n'
                   else format(E'3b FAIL  pending=%s\n', j #>> '{totals,pending_invites}') end;
  exception when others then
    get stacked diagnostics st = returned_sqlstate;
    r := r || format(E'3b FAIL  company detail raised %s\n', st);
  end;

  -- 4. the helper is not callable from the API roles
  begin
    perform public.superadmin_invite_count(some_user, null);
    r := r || E'4  FAIL  an API role ran the helper\n';
  exception when others then
    get stacked diagnostics st = returned_sqlstate;
    r := r || case when st = '42501' then E'4  PASS  helper not executable by API roles\n' else format(E'4  FAIL  %s\n', st) end;
  end;
  reset role;

  raise exception E'\n%\n(rolled back on purpose)', r;
end $$;
