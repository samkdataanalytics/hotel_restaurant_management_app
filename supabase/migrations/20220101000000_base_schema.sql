-- ============================================================
-- Migration 000: Base schema
--
-- Creates the original operational tables that existed before
-- the migration system was introduced.  All statements use
-- CREATE TABLE IF NOT EXISTS so this is safe to run on the
-- production database (which already has these tables).
-- ============================================================

CREATE TABLE IF NOT EXISTS rooms (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_number       TEXT NOT NULL,
  type              TEXT NOT NULL,
  floor             INTEGER NOT NULL DEFAULT 0,
  status            TEXT NOT NULL DEFAULT 'available',
  price_per_night   NUMERIC NOT NULL DEFAULT 0,
  maintenance_start TIMESTAMPTZ,
  maintenance_end   TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS guests (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name       TEXT NOT NULL DEFAULT '',
  email           TEXT NOT NULL DEFAULT '',
  phone           TEXT NOT NULL DEFAULT '',
  id_type         TEXT NOT NULL DEFAULT '',
  id_number       TEXT NOT NULL DEFAULT '',
  nationality     TEXT NOT NULL DEFAULT '',
  passport_or_nic TEXT,
  date_of_birth   TIMESTAMPTZ,
  whats_app       TEXT
);

CREATE TABLE IF NOT EXISTS bookings (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_ref             TEXT NOT NULL DEFAULT '',
  guest_id                UUID,
  room_id                 UUID,
  check_in_date           TIMESTAMPTZ NOT NULL DEFAULT now(),
  check_out_date          TIMESTAMPTZ NOT NULL DEFAULT now(),
  status                  TEXT NOT NULL DEFAULT 'pending',
  number_of_guests        INTEGER NOT NULL DEFAULT 1,
  special_requests        TEXT,
  source                  TEXT,
  total_amount            NUMERIC,
  is_qr_generated         BOOLEAN DEFAULT false,
  is_qr_sent              BOOLEAN DEFAULT false,
  is_guest_form_submitted BOOLEAN DEFAULT false,
  is_paid                 BOOLEAN DEFAULT false,
  guest_preferences       JSONB,
  created_at              TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS check_ins (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id    UUID,
  guest_id      UUID,
  room_id       UUID,
  check_in_time TIMESTAMPTZ NOT NULL DEFAULT now(),
  id_verified   BOOLEAN NOT NULL DEFAULT false,
  key_issued    BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE IF NOT EXISTS expenses (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  description TEXT NOT NULL DEFAULT '',
  amount      NUMERIC NOT NULL DEFAULT 0,
  category    TEXT NOT NULL DEFAULT '',
  date        TIMESTAMPTZ NOT NULL DEFAULT now(),
  end_date    TIMESTAMPTZ,
  room_id     UUID,
  is_billable BOOLEAN DEFAULT false,
  is_paid     BOOLEAN DEFAULT false,
  booking_id  UUID
);

CREATE TABLE IF NOT EXISTS menu_items (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name         TEXT NOT NULL DEFAULT '',
  description  TEXT,
  price        NUMERIC NOT NULL DEFAULT 0,
  category     TEXT,
  image_url    TEXT,
  is_available BOOLEAN DEFAULT true,
  ingredients  JSONB,
  modifiers    JSONB
);

CREATE TABLE IF NOT EXISTS ingredients (
  id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL DEFAULT '',
  unit TEXT NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS ingredient_prices (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ingredient_id   UUID,
  price_per_unit  NUMERIC NOT NULL DEFAULT 0,
  date            TIMESTAMPTZ NOT NULL DEFAULT now(),
  note            TEXT
);

CREATE TABLE IF NOT EXISTS menu_item_cost_records (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  menu_item_id UUID,
  cost         NUMERIC NOT NULL DEFAULT 0,
  date         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS restaurant_tables (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_number TEXT NOT NULL DEFAULT '',
  capacity     INTEGER NOT NULL DEFAULT 1,
  status       TEXT DEFAULT 'available'
);

CREATE TABLE IF NOT EXISTS restaurant_orders (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_number       TEXT NOT NULL DEFAULT '',
  table_id           UUID,
  type               TEXT,
  status             TEXT,
  payment_status     TEXT,
  booking_id         UUID,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  items              JSONB NOT NULL DEFAULT '[]',
  inventory_restored BOOLEAN DEFAULT false,
  parent_order_id    UUID,
  discount_type      TEXT,
  discount_amount    NUMERIC DEFAULT 0,
  room_number        TEXT,
  delivery_platform  TEXT,
  delivery_order_ref TEXT
);

CREATE TABLE IF NOT EXISTS inventory (
  ingredient_id   UUID PRIMARY KEY,
  current_stock   NUMERIC NOT NULL DEFAULT 0,
  min_stock_level NUMERIC,
  updated_at      TIMESTAMPTZ DEFAULT now()
);
