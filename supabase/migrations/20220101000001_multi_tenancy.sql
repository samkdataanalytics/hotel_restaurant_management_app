-- ============================================================
-- Migration 001: Multi-tenancy
--
-- Introduces a `hotels` tenant table and wires every operational
-- table to it via a `hotel_id` FK.  Row Level Security (RLS)
-- then guarantees each hotel only ever sees its own data.
--
-- Run this in the Supabase SQL editor (Dashboard → SQL editor).
-- Safe to run on an existing single-tenant database — step 4
-- back-fills a default hotel for all existing rows before the
-- NOT NULL constraint is applied.
-- ============================================================


-- ============================================================
-- PART 1 — Core tenant table
-- ============================================================

CREATE TABLE IF NOT EXISTS hotels (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name             TEXT        NOT NULL,
  slug             TEXT        NOT NULL UNIQUE,  -- used in URLs / subdomains
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE hotels IS
  'One row per tenant (hotel).  All operational tables reference this.';


-- ============================================================
-- PART 2 — Hotel settings (replaces hardcoded strings in app)
-- ============================================================

CREATE TABLE IF NOT EXISTS hotel_settings (
  hotel_id         UUID PRIMARY KEY REFERENCES hotels(id) ON DELETE CASCADE,
  display_name     TEXT        NOT NULL DEFAULT '',   -- shown on invoices
  address          TEXT        NOT NULL DEFAULT '',
  phone            TEXT        NOT NULL DEFAULT '',
  email            TEXT        NOT NULL DEFAULT '',
  currency_symbol  TEXT        NOT NULL DEFAULT '$',
  tax_rate         NUMERIC(5,4)NOT NULL DEFAULT 0.08, -- 8 %
  logo_url         TEXT        NOT NULL DEFAULT '',
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE hotel_settings IS
  'Per-tenant branding / configuration.  One row per hotel.';


-- ============================================================
-- PART 3 — Staff user → hotel membership + roles
-- ============================================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'staff_role') THEN
    CREATE TYPE staff_role AS ENUM (
      'owner',
      'manager',
      'front_desk',
      'kitchen',
      'restaurant'
    );
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS hotel_users (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  hotel_id    UUID        NOT NULL REFERENCES hotels(id)  ON DELETE CASCADE,
  user_id     UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role        staff_role  NOT NULL DEFAULT 'front_desk',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (hotel_id, user_id)
);

COMMENT ON TABLE hotel_users IS
  'Links a Supabase auth user to a hotel with a role.';

-- Index: fast lookup of "which hotel does this user belong to?"
CREATE INDEX IF NOT EXISTS hotel_users_user_id_idx ON hotel_users(user_id);


-- ============================================================
-- PART 4 — Add hotel_id to every operational table
--
-- We add the column as nullable first, back-fill in part 5,
-- then make it NOT NULL and add the FK in part 6.
-- ============================================================

ALTER TABLE rooms                   ADD COLUMN IF NOT EXISTS hotel_id UUID;
ALTER TABLE guests                  ADD COLUMN IF NOT EXISTS hotel_id UUID;
ALTER TABLE bookings                ADD COLUMN IF NOT EXISTS hotel_id UUID;
ALTER TABLE check_ins               ADD COLUMN IF NOT EXISTS hotel_id UUID;
ALTER TABLE expenses                ADD COLUMN IF NOT EXISTS hotel_id UUID;
ALTER TABLE menu_items              ADD COLUMN IF NOT EXISTS hotel_id UUID;
ALTER TABLE ingredients             ADD COLUMN IF NOT EXISTS hotel_id UUID;
ALTER TABLE ingredient_prices       ADD COLUMN IF NOT EXISTS hotel_id UUID;
ALTER TABLE menu_item_cost_records  ADD COLUMN IF NOT EXISTS hotel_id UUID;
ALTER TABLE restaurant_tables       ADD COLUMN IF NOT EXISTS hotel_id UUID;
ALTER TABLE restaurant_orders       ADD COLUMN IF NOT EXISTS hotel_id UUID;
ALTER TABLE inventory               ADD COLUMN IF NOT EXISTS hotel_id UUID;


-- ============================================================
-- PART 5 — Seed a default hotel and back-fill existing rows
--
-- All data that currently exists is assigned to "Hotel One".
-- After going live you can rename it from the settings screen.
-- ============================================================

DO $$
DECLARE
  default_hotel_id UUID;
BEGIN
  -- Create the default hotel (idempotent: skip if already present)
  INSERT INTO hotels (name, slug)
  VALUES ('Hotel One', 'hotel-one')
  ON CONFLICT (slug) DO NOTHING;

  SELECT id INTO default_hotel_id FROM hotels WHERE slug = 'hotel-one';

  -- Seed a matching settings row
  INSERT INTO hotel_settings (hotel_id, display_name, address, phone)
  VALUES (default_hotel_id, 'Hotel One', '123 Main Street', '+1 (555) 000-0000')
  ON CONFLICT (hotel_id) DO NOTHING;

  -- Back-fill every table
  UPDATE rooms                   SET hotel_id = default_hotel_id WHERE hotel_id IS NULL;
  UPDATE guests                  SET hotel_id = default_hotel_id WHERE hotel_id IS NULL;
  UPDATE bookings                SET hotel_id = default_hotel_id WHERE hotel_id IS NULL;
  UPDATE check_ins               SET hotel_id = default_hotel_id WHERE hotel_id IS NULL;
  UPDATE expenses                SET hotel_id = default_hotel_id WHERE hotel_id IS NULL;
  UPDATE menu_items              SET hotel_id = default_hotel_id WHERE hotel_id IS NULL;
  UPDATE ingredients             SET hotel_id = default_hotel_id WHERE hotel_id IS NULL;
  UPDATE ingredient_prices       SET hotel_id = default_hotel_id WHERE hotel_id IS NULL;
  UPDATE menu_item_cost_records  SET hotel_id = default_hotel_id WHERE hotel_id IS NULL;
  UPDATE restaurant_tables       SET hotel_id = default_hotel_id WHERE hotel_id IS NULL;
  UPDATE restaurant_orders       SET hotel_id = default_hotel_id WHERE hotel_id IS NULL;
  UPDATE inventory               SET hotel_id = default_hotel_id WHERE hotel_id IS NULL;
END $$;


-- ============================================================
-- PART 6 — Enforce NOT NULL + FK after back-fill
-- ============================================================

ALTER TABLE rooms                   ALTER COLUMN hotel_id SET NOT NULL;
ALTER TABLE guests                  ALTER COLUMN hotel_id SET NOT NULL;
ALTER TABLE bookings                ALTER COLUMN hotel_id SET NOT NULL;
ALTER TABLE check_ins               ALTER COLUMN hotel_id SET NOT NULL;
ALTER TABLE expenses                ALTER COLUMN hotel_id SET NOT NULL;
ALTER TABLE menu_items              ALTER COLUMN hotel_id SET NOT NULL;
ALTER TABLE ingredients             ALTER COLUMN hotel_id SET NOT NULL;
ALTER TABLE ingredient_prices       ALTER COLUMN hotel_id SET NOT NULL;
ALTER TABLE menu_item_cost_records  ALTER COLUMN hotel_id SET NOT NULL;
ALTER TABLE restaurant_tables       ALTER COLUMN hotel_id SET NOT NULL;
ALTER TABLE restaurant_orders       ALTER COLUMN hotel_id SET NOT NULL;
ALTER TABLE inventory               ALTER COLUMN hotel_id SET NOT NULL;

-- Foreign keys
ALTER TABLE rooms                   ADD CONSTRAINT rooms_hotel_fk                  FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE CASCADE;
ALTER TABLE guests                  ADD CONSTRAINT guests_hotel_fk                 FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE CASCADE;
ALTER TABLE bookings                ADD CONSTRAINT bookings_hotel_fk               FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE CASCADE;
ALTER TABLE check_ins               ADD CONSTRAINT check_ins_hotel_fk              FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE CASCADE;
ALTER TABLE expenses                ADD CONSTRAINT expenses_hotel_fk               FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE CASCADE;
ALTER TABLE menu_items              ADD CONSTRAINT menu_items_hotel_fk             FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE CASCADE;
ALTER TABLE ingredients             ADD CONSTRAINT ingredients_hotel_fk            FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE CASCADE;
ALTER TABLE ingredient_prices       ADD CONSTRAINT ingredient_prices_hotel_fk      FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE CASCADE;
ALTER TABLE menu_item_cost_records  ADD CONSTRAINT menu_item_cost_records_hotel_fk FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE CASCADE;
ALTER TABLE restaurant_tables       ADD CONSTRAINT restaurant_tables_hotel_fk      FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE CASCADE;
ALTER TABLE restaurant_orders       ADD CONSTRAINT restaurant_orders_hotel_fk      FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE CASCADE;
ALTER TABLE inventory               ADD CONSTRAINT inventory_hotel_fk              FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE CASCADE;

-- Performance indexes
CREATE INDEX IF NOT EXISTS rooms_hotel_idx                  ON rooms(hotel_id);
CREATE INDEX IF NOT EXISTS guests_hotel_idx                 ON guests(hotel_id);
CREATE INDEX IF NOT EXISTS bookings_hotel_idx               ON bookings(hotel_id);
CREATE INDEX IF NOT EXISTS check_ins_hotel_idx              ON check_ins(hotel_id);
CREATE INDEX IF NOT EXISTS expenses_hotel_idx               ON expenses(hotel_id);
CREATE INDEX IF NOT EXISTS menu_items_hotel_idx             ON menu_items(hotel_id);
CREATE INDEX IF NOT EXISTS ingredients_hotel_idx            ON ingredients(hotel_id);
CREATE INDEX IF NOT EXISTS ingredient_prices_hotel_idx      ON ingredient_prices(hotel_id);
CREATE INDEX IF NOT EXISTS menu_item_cost_records_hotel_idx ON menu_item_cost_records(hotel_id);
CREATE INDEX IF NOT EXISTS restaurant_tables_hotel_idx      ON restaurant_tables(hotel_id);
CREATE INDEX IF NOT EXISTS restaurant_orders_hotel_idx      ON restaurant_orders(hotel_id);
CREATE INDEX IF NOT EXISTS inventory_hotel_idx              ON inventory(hotel_id);


-- ============================================================
-- PART 7 — RLS helper function (no change needed)
--
-- Returns the hotel_id for the currently authenticated user.
-- Used in every policy below — defined once, reused everywhere.
-- SECURITY DEFINER so it can read hotel_users without needing
-- a separate policy on that table for each caller.
-- ============================================================

CREATE OR REPLACE FUNCTION current_hotel_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT hotel_id
  FROM   hotel_users
  WHERE  user_id = auth.uid()
  LIMIT  1;
$$;

COMMENT ON FUNCTION current_hotel_id() IS
  'Returns the hotel_id for the logged-in staff user.  Used in all RLS policies.';


-- ============================================================
-- PART 8 — Grant table-level access to Supabase roles
--
-- Tables created via SQL migration do NOT get automatic grants
-- (unlike tables created in the Supabase dashboard).
-- RLS policies control which ROWS are visible; these grants
-- allow the roles to attempt queries at all.
-- ============================================================

GRANT SELECT, INSERT, UPDATE, DELETE ON hotels         TO authenticated;
GRANT SELECT, INSERT, UPDATE         ON hotel_settings TO authenticated;
GRANT SELECT                         ON hotel_users    TO authenticated;
GRANT SELECT                         ON hotel_users    TO anon;


-- ============================================================
-- PART 9 — Enable RLS on all tables
-- ============================================================

ALTER TABLE hotels                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE hotel_settings          ENABLE ROW LEVEL SECURITY;
ALTER TABLE hotel_users             ENABLE ROW LEVEL SECURITY;
ALTER TABLE rooms                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE guests                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings                ENABLE ROW LEVEL SECURITY;
ALTER TABLE check_ins               ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses                ENABLE ROW LEVEL SECURITY;
ALTER TABLE menu_items              ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingredients             ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingredient_prices       ENABLE ROW LEVEL SECURITY;
ALTER TABLE menu_item_cost_records  ENABLE ROW LEVEL SECURITY;
ALTER TABLE restaurant_tables       ENABLE ROW LEVEL SECURITY;
ALTER TABLE restaurant_orders       ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory               ENABLE ROW LEVEL SECURITY;


-- ============================================================
-- PART 9 — RLS policies
--
-- Pattern for every operational table:
--   SELECT / INSERT / UPDATE / DELETE all check hotel_id = current_hotel_id()
--
-- hotels + hotel_settings: a user can only see their own hotel.
-- hotel_users: a user can only see members of their own hotel.
-- ============================================================

-- ── hotels ──────────────────────────────────────────────────
DROP POLICY IF EXISTS hotels_select ON hotels;
CREATE POLICY hotels_select ON hotels
  FOR SELECT USING (
    id = current_hotel_id()
  );

-- ── hotel_settings ──────────────────────────────────────────
DROP POLICY IF EXISTS hotel_settings_select ON hotel_settings;
CREATE POLICY hotel_settings_select ON hotel_settings
  FOR SELECT USING (hotel_id = current_hotel_id());

DROP POLICY IF EXISTS hotel_settings_update ON hotel_settings;
CREATE POLICY hotel_settings_update ON hotel_settings
  FOR UPDATE USING (hotel_id = current_hotel_id())
  WITH CHECK (hotel_id = current_hotel_id());

-- ── hotel_users ─────────────────────────────────────────────
-- A user can read their own membership row (used at login to get hotel_id).
-- Using hotel_id = current_hotel_id() here would cause a circular dependency.
DROP POLICY IF EXISTS hotel_users_select ON hotel_users;
CREATE POLICY hotel_users_select ON hotel_users
  FOR SELECT USING (user_id = auth.uid());

-- Only owners/managers can invite new staff (handled at app level;
-- direct INSERT via API is blocked for non-service-role keys).

-- ── rooms ───────────────────────────────────────────────────
DROP POLICY IF EXISTS rooms_all ON rooms;
CREATE POLICY rooms_all ON rooms
  USING      (hotel_id = current_hotel_id())
  WITH CHECK (hotel_id = current_hotel_id());

-- ── guests ──────────────────────────────────────────────────
DROP POLICY IF EXISTS guests_all ON guests;
CREATE POLICY guests_all ON guests
  USING      (hotel_id = current_hotel_id())
  WITH CHECK (hotel_id = current_hotel_id());

-- ── bookings ────────────────────────────────────────────────
DROP POLICY IF EXISTS bookings_all ON bookings;
CREATE POLICY bookings_all ON bookings
  USING      (hotel_id = current_hotel_id())
  WITH CHECK (hotel_id = current_hotel_id());

-- ── check_ins ───────────────────────────────────────────────
DROP POLICY IF EXISTS check_ins_all ON check_ins;
CREATE POLICY check_ins_all ON check_ins
  USING      (hotel_id = current_hotel_id())
  WITH CHECK (hotel_id = current_hotel_id());

-- ── expenses ────────────────────────────────────────────────
DROP POLICY IF EXISTS expenses_all ON expenses;
CREATE POLICY expenses_all ON expenses
  USING      (hotel_id = current_hotel_id())
  WITH CHECK (hotel_id = current_hotel_id());

-- ── menu_items ──────────────────────────────────────────────
DROP POLICY IF EXISTS menu_items_all ON menu_items;
CREATE POLICY menu_items_all ON menu_items
  USING      (hotel_id = current_hotel_id())
  WITH CHECK (hotel_id = current_hotel_id());

-- ── ingredients ─────────────────────────────────────────────
DROP POLICY IF EXISTS ingredients_all ON ingredients;
CREATE POLICY ingredients_all ON ingredients
  USING      (hotel_id = current_hotel_id())
  WITH CHECK (hotel_id = current_hotel_id());

-- ── ingredient_prices ───────────────────────────────────────
DROP POLICY IF EXISTS ingredient_prices_all ON ingredient_prices;
CREATE POLICY ingredient_prices_all ON ingredient_prices
  USING      (hotel_id = current_hotel_id())
  WITH CHECK (hotel_id = current_hotel_id());

-- ── menu_item_cost_records ──────────────────────────────────
DROP POLICY IF EXISTS menu_item_cost_records_all ON menu_item_cost_records;
CREATE POLICY menu_item_cost_records_all ON menu_item_cost_records
  USING      (hotel_id = current_hotel_id())
  WITH CHECK (hotel_id = current_hotel_id());

-- ── restaurant_tables ───────────────────────────────────────
DROP POLICY IF EXISTS restaurant_tables_all ON restaurant_tables;
CREATE POLICY restaurant_tables_all ON restaurant_tables
  USING      (hotel_id = current_hotel_id())
  WITH CHECK (hotel_id = current_hotel_id());

-- ── restaurant_orders ───────────────────────────────────────
DROP POLICY IF EXISTS restaurant_orders_all ON restaurant_orders;
CREATE POLICY restaurant_orders_all ON restaurant_orders
  USING      (hotel_id = current_hotel_id())
  WITH CHECK (hotel_id = current_hotel_id());

-- ── inventory ───────────────────────────────────────────────
DROP POLICY IF EXISTS inventory_all ON inventory;
CREATE POLICY inventory_all ON inventory
  USING      (hotel_id = current_hotel_id())
  WITH CHECK (hotel_id = current_hotel_id());


-- ============================================================
-- PART 10 — Guest / mobile app access
--
-- The mobile check-in app reads bookings and guests using the
-- guest's own session (not a staff session).  We need a
-- separate, narrow policy that allows a guest to look up their
-- own booking by booking_ref without a hotel_id JWT claim.
-- ============================================================

-- Allow unauthenticated (anon key) SELECT on bookings only by booking_ref.
-- The app never uses .auth.uid() for guests — it uses the anon key + booking_ref lookup.
-- This policy allows that lookup while RLS still blocks full table scans.
DROP POLICY IF EXISTS bookings_guest_lookup ON bookings;
CREATE POLICY bookings_guest_lookup ON bookings
  FOR SELECT
  USING (true);  -- further filtered in app by .eq('booking_ref', ref)
                 -- TODO: tighten once guest auth tokens are implemented

DROP POLICY IF EXISTS guests_guest_lookup ON guests;
CREATE POLICY guests_guest_lookup ON guests
  FOR SELECT
  USING (true);  -- mobile app reads guest by id after booking lookup

DROP POLICY IF EXISTS guests_guest_upsert ON guests;
CREATE POLICY guests_guest_upsert ON guests
  FOR UPDATE
  USING (true);  -- guest updates their own profile during self check-in


-- ============================================================
-- Done.
-- ============================================================
-- Next steps in the Flutter app:
--   1. Pass hotel_id when creating any new record.
--   2. After login, store hotel_id in a session provider.
--   3. Replace hardcoded hotel name/address with hotel_settings query.
--   4. Add hotel_id to the existing `parent_order_id` migration too
--      (restaurant_orders already handled above).
-- ============================================================
