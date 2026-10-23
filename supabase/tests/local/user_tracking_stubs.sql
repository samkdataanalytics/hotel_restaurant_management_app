-- Extra stand-ins for supabase/tests/user_tracking.sql on a plain local Postgres
-- (run after supabase_stubs.sql). The shapes follow the real tables closely enough
-- for the triggers and functions in 20261023000002_superadmin_user_tracking.sql.
alter table public.profiles
  add column if not exists full_name text not null default '',
  add column if not exists job_title text not null default '',
  add column if not exists phone text not null default '',
  add column if not exists avatar_url text not null default '',
  add column if not exists email text not null default '',
  add column if not exists username text,
  add column if not exists deleted_at timestamptz,
  add column if not exists updated_at timestamptz not null default now();

alter table auth.users
  add column if not exists last_sign_in_at timestamptz,
  add column if not exists email_confirmed_at timestamptz,
  add column if not exists confirmed_at timestamptz,
  add column if not exists phone text,
  add column if not exists banned_until timestamptz,
  add column if not exists raw_app_meta_data jsonb not null default '{}',
  add column if not exists created_at timestamptz not null default now();

create table if not exists auth.sessions (
  id uuid primary key default gen_random_uuid(), user_id uuid, created_at timestamptz default now(),
  refreshed_at timestamp, user_agent text, ip inet);

create table public.organizations (
  id uuid primary key default gen_random_uuid(), name text, plan text default 'starter', status text default 'trialing',
  billing_cycle text, trial_ends_at timestamptz, subscription_paid_at timestamptz, is_deleted boolean default false);
create table public.hotels (id uuid primary key default gen_random_uuid(), name text, org_id uuid);
create table public.organization_members (
  id uuid primary key default gen_random_uuid(), org_id uuid, user_id uuid, role text,
  created_at timestamptz default now(), is_deleted boolean default false, can_manage_billing boolean default false);
create table public.property_staff (
  id uuid primary key default gen_random_uuid(), property_id uuid, user_id uuid, role text,
  created_at timestamptz default now(), is_deleted boolean default false);
create table public.bookings (
  id uuid primary key default gen_random_uuid(), booking_ref text, hotel_id uuid, status text, is_paid boolean default false,
  total_amount numeric, guest_id uuid);
create table public.check_ins (id uuid primary key default gen_random_uuid(), hotel_id uuid, booking_id uuid);
create table public.restaurant_orders (
  id uuid primary key default gen_random_uuid(), order_number text, hotel_id uuid, status text, payment_status text, type text);
create table public.expenses (id uuid primary key default gen_random_uuid(), hotel_id uuid, description text, amount numeric, category text, is_paid boolean);
create table public.rooms (id uuid primary key default gen_random_uuid(), hotel_id uuid, room_number text, status text, type text);
create table public.menu_items (id uuid primary key default gen_random_uuid(), hotel_id uuid, name text, price numeric, category text);
create table public.restaurant_tables (id uuid primary key default gen_random_uuid(), hotel_id uuid, status text);
create table public.staff_invites (id uuid primary key default gen_random_uuid(), property_id uuid, org_id uuid, invited_email text, invited_by uuid, status text);
create table public.staff_shifts (id uuid primary key default gen_random_uuid(), hotel_id uuid, staff_user_id uuid, status text);
create table public.staff_time_records (id uuid primary key default gen_random_uuid(), hotel_id uuid, staff_user_id uuid, clock_out timestamptz);
create table public.payhere_orders (
  id text primary key, org_id uuid, user_id uuid, plan_slug text, billing_cycle text, amount numeric, currency text,
  status text, created_at timestamptz default now());

-- The profile update policy of the real project: a user edits their own row.
alter table public.profiles enable row level security;
grant select, update on public.profiles to authenticated;
create policy profiles_self on public.profiles for all to authenticated using (id = auth.uid()) with check (id = auth.uid());
grant select on public.organization_members, public.organizations, public.hotels to authenticated;
