-- Extra stand-ins and a little data for supabase/tests/company_property_tracking.sql
-- on a plain local Postgres (run after user_tracking_stubs.sql). Not for a real database.
alter table public.organizations
  add column if not exists slug text, add column if not exists country text, add column if not exists phone text,
  add column if not exists email text, add column if not exists logo_url text, add column if not exists country_code text,
  add column if not exists created_by uuid, add column if not exists created_at timestamptz not null default now(),
  add column if not exists deleted_at timestamptz,
  add column if not exists custom_max_properties int, add column if not exists custom_max_users int,
  add column if not exists custom_max_rooms int, add column if not exists custom_max_tables int,
  add column if not exists custom_price_monthly numeric, add column if not exists custom_price_annually numeric;
alter table public.hotels
  add column if not exists slug text, add column if not exists type text, add column if not exists address text,
  add column if not exists city text, add column if not exists country text, add column if not exists phone text,
  add column if not exists email text, add column if not exists timezone text, add column if not exists currency text,
  add column if not exists status text default 'active', add column if not exists logo_url text,
  add column if not exists booking_channels jsonb default '["direct"]', add column if not exists is_deleted boolean default false,
  add column if not exists deleted_at timestamptz, add column if not exists created_at timestamptz not null default now();
alter table public.bookings
  add column if not exists created_at timestamptz not null default now(), add column if not exists check_in_date timestamptz,
  add column if not exists check_out_date timestamptz, add column if not exists source text;
alter table public.restaurant_orders
  add column if not exists created_at timestamptz not null default now(), add column if not exists items jsonb,
  add column if not exists room_number text;
alter table public.expenses add column if not exists date timestamptz default now();
alter table public.staff_invites add column if not exists org_id uuid;

create table public.plans (id uuid primary key default gen_random_uuid(), name text, slug text unique, price_monthly numeric,
  is_custom_price boolean default false, max_properties int, max_users int, max_rooms int, max_tables int, is_active boolean default true);
create table public.hotel_settings (hotel_id uuid primary key, tax_rate numeric, service_charge_rate numeric, currency_symbol text, updated_at timestamptz default now());
create table public.hotel_users (id uuid primary key default gen_random_uuid(), hotel_id uuid, user_id uuid, role text);
create table public.enterprise_leads (id uuid primary key default gen_random_uuid(), status text);
create table public.guests (id uuid primary key default gen_random_uuid(), full_name text, hotel_id uuid);

grant select on public.plans to authenticated;

insert into public.plans (name, slug, price_monthly, max_properties, max_users, max_rooms, max_tables)
  values ('Starter', 'starter', 3450, 1, 5, 20, 10), ('Growth', 'growth', 7999, 5, 25, 50, 90);

-- A little data so the checks have something to find (the real database has its own).
do $$
declare org uuid := gen_random_uuid(); hotel uuid := gen_random_uuid(); g uuid := gen_random_uuid();
begin
  insert into public.organizations (id, name, slug, plan, status, country, email, trial_ends_at, created_by)
    values (org, 'Seaview Group', 'seaview', 'growth', 'trialing', 'LK', 'hello@seaview.test', now() + interval '3 days', '00000000-0000-0000-0000-0000000000b2');
  insert into public.organization_members (org_id, user_id, role) values (org, '00000000-0000-0000-0000-0000000000b2', 'owner');
  insert into public.hotels (id, org_id, name, slug, type, city, country, currency, status)
    values (hotel, org, 'Seaview Hotel', 'seaview-hotel', 'both', 'Galle', 'LK', 'LKR', 'active');
  insert into public.hotel_settings (hotel_id, tax_rate, service_charge_rate, currency_symbol) values (hotel, 8, 10, 'LKR');
  insert into public.rooms (hotel_id, room_number, status) values (hotel, '101', 'available'), (hotel, '102', 'occupied');
  insert into public.restaurant_tables (hotel_id, status) values (hotel, 'free');
  insert into public.guests (id, full_name, hotel_id) values (g, 'Zebediah Quillfeather', hotel);
  insert into public.bookings (booking_ref, hotel_id, status, total_amount, is_paid, guest_id, source)
    values ('BK-100', hotel, 'checkedOut', 15000, true, g, 'direct'), ('BK-101', hotel, 'pending', 9000, false, g, 'direct');
  insert into public.restaurant_orders (order_number, hotel_id, status, type, items) values ('ORD-1', hotel, 'served', 'dine_in', '[{"n":1},{"n":2}]');
  insert into public.expenses (hotel_id, description, amount, category) values (hotel, 'Linen', 500, 'supplies');
  insert into public.property_staff (property_id, user_id, role) values (hotel, '00000000-0000-0000-0000-0000000000a1', 'manager');
end $$;
