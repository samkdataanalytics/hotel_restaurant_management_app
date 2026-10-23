-- Local-only trigger checks for 20261023000002_superadmin_user_tracking.sql, run
-- against the stand-in tables in user_tracking_stubs.sql (the real tables have many
-- more required columns, so these inserts could not run unchanged on hotrest_dev).
-- Ends in an error carrying the report; rolls back.
do $$
declare
  u uuid := '00000000-0000-0000-0000-0000000000b2';
  org uuid := gen_random_uuid(); hotel uuid := gen_random_uuid(); bk uuid := gen_random_uuid();
  r text := ''; n int; a record;
begin
  insert into public.organizations (id, name) values (org, 'Acme');
  insert into public.hotels (id, name, org_id) values (hotel, 'Acme Hotel', org);

  perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);

  -- booking created: actor, hotel, org (resolved through the hotel), reference, no guest data
  insert into public.bookings (id, booking_ref, hotel_id, status, total_amount, guest_id)
    values (bk, 'BK-0042', hotel, 'pending', 120, gen_random_uuid());
  select * into a from public.user_activity where entity_id = bk::text and action = 'booking.created';
  r := r || case when a.user_id = u and a.org_id = org and a.property_id = hotel and a.detail->>'booking_ref' = 'BK-0042'
                      and not (a.detail ? 'guest_id')
                 then E'1 PASS  booking.created: actor, hotel and company resolved, reference kept, guest id not copied\n'
                 else format(E'1 FAIL  %s\n', row_to_json(a)) end;

  -- status change reads as its own action, with from/to
  update public.bookings set status = 'confirmed' where id = bk;
  select * into a from public.user_activity where entity_id = bk::text and action = 'booking.confirmed';
  r := r || case when a.detail #>> '{changed,status,from}' = 'pending' and a.detail #>> '{changed,status,to}' = 'confirmed'
                 then E'2 PASS  booking.confirmed with the transition\n' else E'2 FAIL\n' end;

  -- an update that touches no watched column writes nothing
  select count(*) into n from public.user_activity where entity_id = bk::text;
  update public.bookings set total_amount = 150 where id = bk;
  r := r || case when (select count(*) from public.user_activity where entity_id = bk::text) = n
                 then E'3 PASS  unwatched column: no entry\n' else E'3 FAIL\n' end;

  -- orders, expenses, rooms
  insert into public.restaurant_orders (hotel_id, order_number, status, type) values (hotel, 'ORD-7', 'new', 'dine_in');
  insert into public.expenses (hotel_id, description, amount, category) values (hotel, repeat('x', 300), 50, 'supplies');
  insert into public.rooms (hotel_id, room_number, status) values (hotel, '101', 'available');
  select count(*) into n from public.user_activity where org_id = org and action in ('order.created', 'expense.created', 'room.created');
  r := r || case when n = 3 then E'4 PASS  order, expense and room creation logged\n' else format(E'4 FAIL  %s\n', n) end;
  r := r || case when (select length(detail->>'description') from public.user_activity where action = 'expense.created' and org_id = org) = 80
                 then E'5 PASS  long descriptions are cut to 80 characters\n' else E'5 FAIL\n' end;

  -- membership: who was added, by whom
  insert into public.organization_members (org_id, user_id, role) values (org, '00000000-0000-0000-0000-0000000000a1', 'manager');
  select * into a from public.user_activity where action = 'org_member.created' and org_id = org;
  r := r || case when a.user_id = u and a.detail->>'target_user' = '00000000-0000-0000-0000-0000000000a1' and a.detail->>'role' = 'manager'
                 then E'6 PASS  membership change names the actor and the person affected\n' else format(E'6 FAIL  %s\n', row_to_json(a)) end;
  update public.organization_members set role = 'owner' where org_id = org;
  r := r || case when exists (select 1 from public.user_activity where action = 'org_member.updated' or action = 'org_member.owner' or entity = 'org_member' and detail #>> '{changed,role,to}' = 'owner')
                 then E'7 PASS  role change logged\n' else E'7 FAIL\n' end;

  -- a payment recorded by the webhook (no session): the payer is the actor
  perform set_config('request.jwt.claims', '', true);
  insert into public.payhere_orders (id, org_id, user_id, plan_slug, amount, currency, status) values ('PH-1', org, u, 'growth', 8000, 'LKR', 'pending');
  select * into a from public.user_activity where action = 'payment.created' and org_id = org;
  r := r || case when a.user_id = u and a.detail->>'plan_slug' = 'growth' then E'8 PASS  webhook payment attributed to the payer\n' else E'8 FAIL\n' end;
  update public.payhere_orders set status = 'success' where id = 'PH-1';
  r := r || case when exists (select 1 from public.user_activity where action = 'payment.success') then E'9 PASS  payment.success\n' else E'9 FAIL\n' end;

  -- a system change with no session has no actor
  insert into public.rooms (hotel_id, room_number, status) values (hotel, '102', 'available');
  select * into a from public.user_activity where action = 'room.created' and detail->>'room_number' = '102';
  r := r || case when a.user_id is null then E'10 PASS  no session -> no actor\n' else E'10 FAIL\n' end;

  -- a plan change on the company
  update public.organizations set plan = 'growth' where id = org;
  select * into a from public.user_activity where entity = 'org' and org_id = org and detail #>> '{changed,plan,to}' = 'growth';
  r := r || case when a.id is not null then E'11 PASS  plan change logged against the company\n' else E'11 FAIL\n' end;

  -- the log can never block the write: make every log insert fail, then write
  alter table public.user_activity add constraint always_fails check (false) not valid;
  begin
    insert into public.rooms (hotel_id, room_number, status) values (hotel, '103', 'available');
    r := r || case when exists (select 1 from public.rooms where room_number = '103')
                   then E'12 PASS  a failing log insert did not stop the room being created\n' else E'12 FAIL\n' end;
  exception when others then
    r := r || E'12 FAIL  the write was blocked by the logger\n';
  end;

  raise exception E'\n%\n(rolled back on purpose)', r;
end $$;
