-- ─── Pricing Plans ────────────────────────────────────────────────────────────
-- Superadmin-managed pricing tiers shown on the landing page.
-- Use -1 for any limit field to represent "unlimited".

CREATE TABLE plans (
  id               UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  name             TEXT           NOT NULL,
  slug             TEXT           NOT NULL UNIQUE,
  price_monthly    NUMERIC(10,2)  NOT NULL DEFAULT 0,
  is_custom_price  BOOLEAN        NOT NULL DEFAULT false, -- true → show "Custom" instead of price
  max_properties   INTEGER        NOT NULL DEFAULT 1,     -- -1 = unlimited
  max_users        INTEGER        NOT NULL DEFAULT 5,
  max_rooms        INTEGER        NOT NULL DEFAULT 20,
  max_tables       INTEGER        NOT NULL DEFAULT 5,
  is_highlighted   BOOLEAN        NOT NULL DEFAULT false,  -- "Most Popular" badge
  is_active        BOOLEAN        NOT NULL DEFAULT true,
  sort_order       INTEGER        NOT NULL DEFAULT 0,
  created_at       TIMESTAMPTZ    NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ    NOT NULL DEFAULT now()
);

-- ─── RLS ──────────────────────────────────────────────────────────────────────
ALTER TABLE plans ENABLE ROW LEVEL SECURITY;

-- Anyone (including unauthenticated visitors) can read active plans for landing page
CREATE POLICY "plans_public_read"
  ON plans FOR SELECT
  USING (is_active = true);

-- Superadmins have full control
CREATE POLICY "plans_superadmin_all"
  ON plans FOR ALL
  USING (is_superadmin())
  WITH CHECK (is_superadmin());

-- ─── Seed default 4 plans ─────────────────────────────────────────────────────
INSERT INTO plans (name, slug, price_monthly, is_custom_price, max_properties, max_users, max_rooms, max_tables, is_highlighted, sort_order)
VALUES
  ('Free',       'free',       0,   false, 1,  5,   20,  5,  false, 1),
  ('Starter',    'starter',    49,  false, 1,  10,  50,  15, false, 2),
  ('Pro',        'pro',        99,  false, 3,  25,  150, 30, true,  3),
  ('Enterprise', 'enterprise', 0,   true,  -1, -1,  -1,  -1, false, 4);
