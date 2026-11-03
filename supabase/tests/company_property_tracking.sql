-- Regression checks for 20261023000004_superadmin_companies_properties.sql.
--
-- Paste the whole file into the SQL editor and run it, AFTER that migration (and
-- 20261023000002). It uses whatever companies and properties already exist, needs
-- at least one of each plus one superadmin and one ordinary profile, and ALWAYS ends
-- in an error on purpose so nothing commits. The message is the report: every line
-- should read PASS.
do $$
declare
  normal_id uuid; admin_id uuid; org uuid; org_name text; prop uuid; other uuid := gen_random_uuid();
  r text := '';
  n bigint; tc bigint; j jsonb; j2 jsonb; st text; e text; k text; txt text;
begin
  select id into normal_id from public.profiles where not is_superadmin and coalesce(is_deleted, false) = false order by created_at limit 1;
  select id into admin_id from public.profiles where is_superadmin limit 1;
  select o.id, o.name into org, org_name from public.organizations o
    where not coalesce(o.is_deleted, false) and exists (select 1 from public.hotels h where h.org_id = o.id and not coalesce(h.is_deleted, false))
    order by o.created_at limit 1;
  select h.id into prop from public.hotels h where h.org_id = org and not coalesce(h.is_deleted, false) order by h.created_at limit 1;
  if normal_id is null or admin_id is null or org is null or prop is null then
    raise exception 'Need a superadmin, an ordinary profile, and a company with a property.';
  end if;

  -- 1. an ordinary user is refused by every function
  perform set_config('request.jwt.claims', json_build_object('sub', normal_id, 'role', 'authenticated')::text, true);
  set local role authenticated;
  foreach k in array array['overview', 'companies', 'company', 'properties', 'property', 'activity'] loop
    begin
      if k = 'overview' then perform public.superadmin_platform_overview();
      elsif k = 'companies' then perform * from public.superadmin_list_companies('', 'all', 5, 0);
      elsif k = 'company' then perform public.superadmin_company_detail(org);
      elsif k = 'properties' then perform * from public.superadmin_list_properties('', 'all', null, 5, 0);
      elsif k = 'property' then perform public.superadmin_property_detail(prop);
      else perform * from public.superadmin_activity(null, null, null, null, 5, null);
      end if;
      r := r || format(E'1  FAIL  ordinary user ran %s\n', k);
    exception when others then
      get stacked diagnostics st = returned_sqlstate;
      r := r || case when st = '42501' then format(E'1  PASS  ordinary user refused: %s\n', k) else format(E'1  FAIL  %s: %s\n', k, st) end;
    end;
  end loop;
  reset role;

  -- 2. anon cannot execute
  set local role anon;
  begin
    perform public.superadmin_platform_overview();
    r := r || E'2  FAIL  anon ran overview\n';
  exception when others then
    get stacked diagnostics st = returned_sqlstate;
    r := r || case when st = '42501' then E'2  PASS  anon cannot execute\n' else format(E'2  FAIL  %s\n', st) end;
  end;
  reset role;

  -- 3. the superadmin: overview
  perform set_config('request.jwt.claims', json_build_object('sub', admin_id, 'role', 'authenticated')::text, true);
  set local role authenticated;
  j := public.superadmin_platform_overview();
  r := r || case when j ? 'companies' and j ? 'properties' and j ? 'bookings' and j ? 'orders' and j ? 'subscriptions'
                      and j ? 'activity' and (j #>> '{companies,total}')::int >= 1 and (j #>> '{properties,total}')::int >= 1
                 then E'3a PASS  overview has every section\n' else format(E'3a FAIL  %s\n', left(j::text, 200)) end;
  r := r || case when jsonb_array_length(j #> '{activity,daily}') = 14 then E'3b PASS  14-day trend\n' else E'3b FAIL  trend length\n' end;
  select coalesce(sum(value::int), 0) into n from jsonb_each_text(j #> '{companies,by_status}');
  r := r || case when n = (j #>> '{companies,total}')::int then E'3c PASS  companies by status add up to the total\n' else format(E'3c FAIL  %s vs %s\n', n, j #>> '{companies,total}') end;

  -- 4. companies list
  select count(*), coalesce(max(total_count), 0) into n, tc from public.superadmin_list_companies('', 'all', 200, 0);
  r := r || case when n >= 1 and n = tc then E'4a PASS  every company listed, total_count matches\n' else format(E'4a FAIL  %s/%s\n', n, tc) end;
  select count(*) into n from public.superadmin_list_companies(org_name, 'all', 50, 0) where org_id = org;
  r := r || case when n = 1 then E'4b PASS  search by name finds the company\n' else E'4b FAIL\n' end;
  select count(*) into n from public.superadmin_list_companies('%', 'all', 50, 0);
  r := r || case when n = 0 then E'4c PASS  % searched literally\n' else format(E'4c FAIL  %s\n', n) end;
  select count(*) into n from public.superadmin_list_companies('', 'all', 1, 0);
  r := r || case when n = 1 then E'4d PASS  limit respected\n' else E'4d FAIL\n' end;
  select count(*) into n from public.superadmin_list_companies('', 'nonsense', 50, 0);
  r := r || case when n >= 1 then E'4e PASS  unknown filter acts like all\n' else E'4e FAIL\n' end;
  select count(*) into n from public.superadmin_list_companies('', 'suspended', 50, 0) where status <> 'suspended';
  r := r || case when n = 0 then E'4f PASS  status filter returns only that status\n' else E'4f FAIL\n' end;

  -- 5. company detail agrees with the list
  j := public.superadmin_company_detail(org);
  select properties, members into n, tc from public.superadmin_list_companies(org_name, 'all', 50, 0) where org_id = org;
  r := r || case when j ? 'limits' and j ? 'totals' and j ? 'members' and j ? 'properties' and j ? 'payments' and j ? 'activity_counts'
                 then E'5a PASS  detail has every section\n' else E'5a FAIL\n' end;
  r := r || case when jsonb_array_length(j -> 'properties') = n and jsonb_array_length(j -> 'members') = tc
                 then E'5b PASS  detail and list agree on property and member counts\n' else format(E'5b FAIL  %s/%s vs %s/%s\n', jsonb_array_length(j -> 'properties'), jsonb_array_length(j -> 'members'), n, tc) end;
  r := r || case when (j #>> '{limits,properties,used}')::int = n then E'5c PASS  limit usage matches\n' else E'5c FAIL\n' end;
  begin
    perform public.superadmin_company_detail(other);
    r := r || E'5d FAIL  unknown company returned\n';
  exception when others then
    get stacked diagnostics st = returned_sqlstate;
    r := r || case when st = 'P0002' then E'5d PASS  unknown company -> error\n' else format(E'5d FAIL  %s\n', st) end;
  end;

  -- 6. properties list
  select count(*), coalesce(max(total_count), 0) into n, tc from public.superadmin_list_properties('', 'all', null, 200, 0);
  r := r || case when n >= 1 and n = tc then E'6a PASS  every property listed\n' else format(E'6a FAIL  %s/%s\n', n, tc) end;
  select count(*) into n from public.superadmin_list_properties('', 'all', org, 200, 0) where org_id <> org;
  r := r || case when n = 0 then E'6b PASS  company filter returns only that company\n' else E'6b FAIL\n' end;
  select count(*) into n from public.superadmin_list_properties('', 'all', org, 200, 0);
  r := r || case when n = jsonb_array_length(j -> 'properties') then E'6c PASS  same properties as the company detail\n' else E'6c FAIL\n' end;
  select count(*) into n from public.superadmin_list_properties('', 'bogus', null, 200, 0);
  r := r || case when n >= 1 then E'6d PASS  unknown filter acts like all\n' else E'6d FAIL\n' end;

  -- 7. property detail
  j2 := public.superadmin_property_detail(prop);
  r := r || case when j2 ? 'staff' and j2 ? 'totals' and j2 ? 'rooms_by_status' and j2 ? 'recent_bookings' and j2 ? 'recent_orders'
                      and j2 ? 'activity_counts' and (j2 #>> '{company,org_id}')::uuid = org
                 then E'7a PASS  property detail has every section and names its company\n' else E'7a FAIL\n' end;
  txt := j::text || j2::text;
  reset role;   -- read the guests table as the owner: this check is about what the details contain
  r := r || case when not exists (select 1 from public.guests g where coalesce(g.full_name, '') <> '' and position(g.full_name in txt) > 0)
                 then E'7b PASS  no guest name appears in either detail\n' else E'7b FAIL  a guest name leaked\n' end;
  set local role authenticated;
  begin
    perform public.superadmin_property_detail(other);
    r := r || E'7c FAIL\n';
  exception when others then
    get stacked diagnostics st = returned_sqlstate;
    r := r || case when st = 'P0002' then E'7c PASS  unknown property -> error\n' else format(E'7c FAIL  %s\n', st) end;
  end;
  reset role;

  -- 8. changes to a property and a plan are logged, and every filter finds them
  perform set_config('request.jwt.claims', json_build_object('sub', admin_id, 'role', 'authenticated')::text, true);
  update public.hotels set name = name || ' (renamed)' where id = prop;
  update public.plans set price_monthly = coalesce(price_monthly, 0) + 1 where slug = (select slug from public.plans order by slug limit 1);
  set local role authenticated;
  select count(*) into n from public.superadmin_activity(null, null, prop, 'property.', 50, null);
  r := r || case when n >= 1 then E'8a PASS  property change found by property filter\n' else E'8a FAIL\n' end;
  select count(*) into n from public.superadmin_activity(null, org, null, 'property.', 50, null);
  r := r || case when n >= 1 then E'8b PASS  ... and by company filter\n' else E'8b FAIL\n' end;
  select count(*) into n from public.superadmin_activity(admin_id, null, null, 'property.', 50, null);
  r := r || case when n >= 1 then E'8c PASS  ... and by the person who made it\n' else E'8c FAIL\n' end;
  select count(*) into n from public.superadmin_activity(null, null, other, null, 50, null);
  r := r || case when n = 0 then E'8d PASS  a different property sees nothing\n' else E'8d FAIL\n' end;
  select count(*) into n from public.superadmin_activity(normal_id, null, prop, 'property.', 50, null);
  r := r || case when n = 0 then E'8e PASS  filters combine (AND)\n' else E'8e FAIL\n' end;
  select count(*) into n from public.superadmin_activity(null, null, null, 'plan.', 50, null);
  r := r || case when n >= 1 then E'8f PASS  plan price change logged\n' else E'8f FAIL\n' end;
  j := public.superadmin_property_detail(prop);
  r := r || case when exists (select 1 from jsonb_array_elements(j -> 'activity_counts') c where c ->> 'action' like 'property.%')
                 then E'8g PASS  property detail counts the change\n' else E'8g FAIL\n' end;
  reset role;

  raise exception E'\n%\n(rolled back on purpose)', r;
end $$;
