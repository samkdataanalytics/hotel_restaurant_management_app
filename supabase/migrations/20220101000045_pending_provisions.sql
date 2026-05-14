-- ─── Pending Enterprise Provisions ────────────────────────────────────────────
-- When a superadmin provisions an enterprise customer who hasn't signed up yet,
-- the config is stored here. On first login after onboarding, the app checks
-- this table and applies the provision automatically.

CREATE TABLE IF NOT EXISTS pending_provisions (
  id              UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  email           TEXT           NOT NULL UNIQUE,
  max_properties  INTEGER        NOT NULL DEFAULT 1,
  max_users       INTEGER        NOT NULL DEFAULT 10,
  max_rooms       INTEGER        NOT NULL DEFAULT 50,
  max_tables      INTEGER        NOT NULL DEFAULT 20,
  price_monthly   NUMERIC(10,2),
  price_annually  NUMERIC(10,2),
  billing_cycle   TEXT           NOT NULL DEFAULT 'monthly',
  provisioned_by  UUID           REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at      TIMESTAMPTZ    NOT NULL DEFAULT now()
);

ALTER TABLE pending_provisions ENABLE ROW LEVEL SECURITY;

-- Superadmins have full control
DROP POLICY IF EXISTS "pending_provisions_superadmin_all" ON pending_provisions;
CREATE POLICY "pending_provisions_superadmin_all"
  ON pending_provisions FOR ALL
  USING (is_superadmin())
  WITH CHECK (is_superadmin());

-- Authenticated users can read their own pending provision (for auto-apply on signup)
DROP POLICY IF EXISTS "pending_provisions_self_read" ON pending_provisions;
CREATE POLICY "pending_provisions_self_read"
  ON pending_provisions FOR SELECT
  TO authenticated
  USING (lower(email) = lower(auth.jwt() ->> 'email'));

GRANT ALL ON TABLE pending_provisions TO service_role;
GRANT SELECT ON TABLE pending_provisions TO authenticated;
