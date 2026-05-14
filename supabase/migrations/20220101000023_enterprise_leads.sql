-- ─── Enterprise Leads ────────────────────────────────────────────────────────
-- Stores contact requests from the Enterprise plan "Contact Sales" form.
-- Public (anon) can INSERT; only superadmins can SELECT / UPDATE.

CREATE TABLE IF NOT EXISTS enterprise_leads (
  id             UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  name           TEXT           NOT NULL,
  company        TEXT           NOT NULL,
  email          TEXT           NOT NULL,
  phone          TEXT,
  property_count INTEGER,
  message        TEXT,
  status         TEXT           NOT NULL DEFAULT 'new',
  -- status values: new | contacted | converted | declined
  admin_notes    TEXT,
  created_at     TIMESTAMPTZ    NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ    NOT NULL DEFAULT now()
);

-- ─── RLS ─────────────────────────────────────────────────────────────────────

ALTER TABLE enterprise_leads ENABLE ROW LEVEL SECURITY;

-- Anyone (anon) can submit a lead from the landing page
CREATE POLICY leads_public_insert ON enterprise_leads
  FOR INSERT TO anon, authenticated
  WITH CHECK (true);

-- Only superadmins can read all leads
CREATE POLICY leads_superadmin_select ON enterprise_leads
  FOR SELECT TO authenticated
  USING (is_superadmin());

-- Only superadmins can update status / notes
CREATE POLICY leads_superadmin_update ON enterprise_leads
  FOR UPDATE TO authenticated
  USING (is_superadmin())
  WITH CHECK (is_superadmin());

-- ─── Grants ───────────────────────────────────────────────────────────────────

GRANT INSERT ON enterprise_leads TO anon, authenticated;
GRANT SELECT, UPDATE ON enterprise_leads TO authenticated;
