-- Checks for 20261103000002_plan_limits_server_side.sql, on the throwaway local
-- Postgres only (it creates its own companies, hotels, rooms and members).
-- Always ends in an error on purpose so nothing is kept; the message is the report.
do $$
declare
  r text := '';
  a uuid := gen_random_uuid(); b uuid := gen_random_uuid(); c uuid := gen_random_uuid();
  admin_id uuid := gen_random_uuid();
  h1 uuid; h2 uuid; hb uuid; tbl uuid;
  st text; msg text; n int;
begin
  insert into auth.users(id, email) values (admin_id, 'admin@example.test');
  insert into public.profiles(id, is_superadmin) values (admin_id, true);

  -- Starter in the stub: 1 property, 5 users, 20 rooms, 10 tables
  insert into public.organizations(id, name, plan, status) values (a, 'A starter', 'starter', 'active');
  insert into public.organizations(id, name, plan, status) values (b, 'B growth',  'growth',  'active');

  -- 1. properties: the limit is the plan's
  h1 := gen_random_uuid();
  insert into public.hotels(id, name, org_id) values (h1, 'A1', a);
  r := r || E'1a PASS  first property allowed\n';
  begin
    insert into public.hotels(id, name, org_id) values (gen_random_uuid(), 'A2', a);
    r := r || E'1b FAIL  second property allowed on a 1-property plan\n';
  exception when others then
    get stacked diagnostics st = returned_sqlstate, msg = message_text;
    r := r || case when st = 'PL402' and msg like '%allows 1 properties%' then E'1b PASS  second property refused (PL402, says the limit)\n' else format(E'1b FAIL  %s %s\n', st, msg) end;
  end;

  -- 2. another company is unaffected
  insert into public.hotels(id, name, org_id) values (gen_random_uuid(), 'B1', b), (gen_random_uuid(), 'B2', b);
  r := r || E'2  PASS  a company on a bigger plan is not held to another company''s limit\n';

  -- 3. a soft-deleted property does not count
  update public.hotels set is_deleted = true where id = h1;
  insert into public.hotels(id, name, org_id) values (gen_random_uuid(), 'A2', a);
  r := r || E'3  PASS  a deleted property frees its slot\n';
  select id into h2 from public.hotels where org_id = a and not coalesce(is_deleted, false);

  -- 4. rooms: custom limit beats the plan (plan says 20)
  update public.organizations set custom_max_rooms = 3 where id = a;
  insert into public.rooms(hotel_id, room_number) values (h2, '1'), (h2, '2'), (h2, '3');
  r := r || E'4a PASS  three rooms allowed under a custom limit of 3\n';
  begin
    insert into public.rooms(hotel_id, room_number) values (h2, '4');
    r := r || E'4b FAIL  fourth room allowed\n';
  exception when others then
    get stacked diagnostics st = returned_sqlstate;
    r := r || case when st = 'PL402' then E'4b PASS  fourth room refused: the custom limit wins over the plan\n' else format(E'4b FAIL  %s\n', st) end;
  end;

  -- 5. a multi-row insert cannot slip past the limit
  update public.organizations set custom_max_rooms = 5 where id = a;
  begin
    insert into public.rooms(hotel_id, room_number) values (h2, '4'), (h2, '5'), (h2, '6'), (h2, '7');
    r := r || E'5  FAIL  bulk insert went past the limit\n';
  exception when others then
    get stacked diagnostics st = returned_sqlstate;
    r := r || case when st = 'PL402' then E'5  PASS  bulk insert past the limit refused as a whole\n' else format(E'5  FAIL  %s\n', st) end;
  end;

  -- 6. already over the limit: data stays, edits work, new ones refused
  update public.organizations set custom_max_rooms = 1 where id = a;
  update public.rooms set status = 'cleaning' where hotel_id = h2;
  select count(*) into n from public.rooms where hotel_id = h2;
  r := r || case when n = 3 then E'6a PASS  an over-limit company keeps its 3 rooms and can edit them\n' else E'6a FAIL\n' end;
  begin
    insert into public.rooms(hotel_id, room_number) values (h2, '9');
    r := r || E'6b FAIL\n';
  exception when others then
    get stacked diagnostics st = returned_sqlstate;
    r := r || case when st = 'PL402' then E'6b PASS  ... but cannot add a room\n' else format(E'6b FAIL  %s\n', st) end;
  end;

  -- 7. unlimited (-1)
  update public.organizations set custom_max_rooms = -1 where id = a;
  insert into public.rooms(hotel_id, room_number) select h2, 'u' || g from generate_series(1, 30) g;
  r := r || E'7  PASS  -1 means unlimited\n';

  -- 8. tables, and an upsert that edits an existing table at the limit
  update public.organizations set custom_max_tables = 2 where id = a;
  tbl := gen_random_uuid();
  insert into public.restaurant_tables(id, hotel_id, status) values (tbl, h2, 'free'), (gen_random_uuid(), h2, 'free');
  begin
    insert into public.restaurant_tables(hotel_id, status) values (h2, 'free');
    r := r || E'8a FAIL  third table allowed\n';
  exception when others then
    get stacked diagnostics st = returned_sqlstate;
    r := r || case when st = 'PL402' then E'8a PASS  third table refused\n' else format(E'8a FAIL  %s\n', st) end;
  end;
  insert into public.restaurant_tables(id, hotel_id, status) values (tbl, h2, 'occupied')
    on conflict (id) do update set status = excluded.status;
  select status into st from public.restaurant_tables where id = tbl;
  r := r || case when st = 'occupied' then E'8b PASS  editing a table by upsert still works at the limit\n' else E'8b FAIL\n' end;

  -- 9. staff accounts (organization members), including the repeat of an existing member
  update public.organizations set custom_max_users = 2 where id = a;
  insert into public.organization_members(org_id, user_id, role) values (a, gen_random_uuid(), 'owner'), (a, admin_id, 'member');
  begin
    insert into public.organization_members(org_id, user_id, role) values (a, gen_random_uuid(), 'member');
    r := r || E'9a FAIL  third member allowed\n';
  exception when others then
    get stacked diagnostics st = returned_sqlstate;
    r := r || case when st = 'PL402' then E'9a PASS  third staff account refused\n' else format(E'9a FAIL  %s\n', st) end;
  end;

  -- 10. expired trial, stored or elapsed, and suspended: nothing can be added, even under the limit
  update public.organizations set custom_max_tables = 50, status = 'trial_expired' where id = a;
  begin insert into public.restaurant_tables(hotel_id, status) values (h2, 'free'); r := r || E'10a FAIL\n';
  exception when others then get stacked diagnostics st = returned_sqlstate, msg = message_text;
    r := r || case when st = 'PL402' and msg like '%trial has ended%' then E'10a PASS  stored trial_expired refused\n' else format(E'10a FAIL  %s\n', st) end; end;
  update public.organizations set status = 'trialing', trial_ends_at = now() - interval '1 hour' where id = a;
  begin insert into public.restaurant_tables(hotel_id, status) values (h2, 'free'); r := r || E'10b FAIL\n';
  exception when others then get stacked diagnostics st = returned_sqlstate;
    r := r || case when st = 'PL402' then E'10b PASS  trial past its end date refused even before the status is flipped\n' else format(E'10b FAIL  %s\n', st) end; end;
  update public.organizations set status = 'trialing', trial_ends_at = now() + interval '5 days' where id = a;
  insert into public.restaurant_tables(hotel_id, status) values (h2, 'free');
  r := r || E'10c PASS  a running trial adds normally\n';
  update public.organizations set status = 'suspended' where id = a;
  begin insert into public.restaurant_tables(hotel_id, status) values (h2, 'free'); r := r || E'10d FAIL\n';
  exception when others then get stacked diagnostics st = returned_sqlstate, msg = message_text;
    r := r || case when st = 'PL402' and msg like '%suspended%' then E'10d PASS  suspended refused\n' else format(E'10d FAIL  %s\n', st) end; end;

  -- 11. a superadmin is exempt
  perform set_config('request.jwt.claims', json_build_object('sub', admin_id, 'role', 'authenticated')::text, true);
  insert into public.restaurant_tables(hotel_id, status) values (h2, 'free');
  insert into public.hotels(id, name, org_id) values (gen_random_uuid(), 'A-admin', a);
  r := r || E'11 PASS  a superadmin can add on a suspended, full company\n';
  perform set_config('request.jwt.claims', '', true);

  -- 12. a plan that cannot be found counts as 1, like the screens
  insert into public.organizations(id, name, plan, status) values (c, 'C unknown plan', 'ghost', 'active');
  insert into public.hotels(id, name, org_id) values (gen_random_uuid(), 'C1', c);
  begin insert into public.hotels(id, name, org_id) values (gen_random_uuid(), 'C2', c); r := r || E'12 FAIL\n';
  exception when others then get stacked diagnostics st = returned_sqlstate;
    r := r || case when st = 'PL402' then E'12 PASS  unknown plan -> limit of 1\n' else format(E'12 FAIL  %s\n', st) end; end;

  -- 13. API roles cannot call the helpers
  begin
    set local role authenticated;
    perform public.org_plan_limit(a, 'rooms');
    reset role;
    r := r || E'13 FAIL  an API role ran org_plan_limit\n';
  exception when others then
    reset role;
    get stacked diagnostics st = returned_sqlstate;
    r := r || case when st = '42501' then E'13 PASS  helpers are not callable from the API\n' else format(E'13 FAIL  %s\n', st) end;
  end;

  raise exception E'\n%\n(rolled back on purpose)', r;
end $$;
