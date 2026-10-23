-- Minimal stand-ins for the parts of a Supabase project the CMS migration touches
-- (roles, auth.uid(), storage, profiles/is_superadmin), so the migration and its
-- regression test can run on a plain local Postgres and in CI. Not for any real database.
do $$ begin
  begin create role anon nologin; exception when duplicate_object then null; end;
  begin create role authenticated nologin; exception when duplicate_object then null; end;
  begin create role service_role nologin; exception when duplicate_object then null; end;
end $$;
create schema extensions;
create schema auth;
create table auth.users (id uuid primary key default gen_random_uuid(), email text);
create function auth.uid() returns uuid language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''),
                  (nullif(current_setting('request.jwt.claims', true), '')::json ->> 'sub'))::uuid $$;
create function auth.role() returns text language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claim.role', true), ''),
                  (nullif(current_setting('request.jwt.claims', true), '')::json ->> 'role'))::text $$;
create table public.profiles (id uuid primary key, is_superadmin boolean not null default false, is_deleted boolean not null default false, created_at timestamptz not null default now());
create function public.is_superadmin() returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select is_superadmin from public.profiles where id = auth.uid()), false) $$;
grant usage on schema public, auth to anon, authenticated;
grant execute on function auth.uid(), auth.role(), public.is_superadmin() to anon, authenticated;
create schema storage;
create table storage.buckets (id text primary key, name text, public boolean default false, file_size_limit bigint, allowed_mime_types text[]);
create table storage.objects (id uuid default gen_random_uuid(), bucket_id text, name text, owner uuid);
alter table storage.objects enable row level security;
insert into auth.users(id,email) values ('00000000-0000-0000-0000-0000000000a1','admin@x'),('00000000-0000-0000-0000-0000000000b2','user@x');
insert into public.profiles(id,is_superadmin) values ('00000000-0000-0000-0000-0000000000a1', true),('00000000-0000-0000-0000-0000000000b2', false);
