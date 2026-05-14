-- ─── Per-org custom plan limits ───────────────────────────────────────────────
-- When these columns are non-null they override the plan table limits.
-- Set by superadmin when fulfilling an enterprise / custom plan request.

ALTER TABLE organizations
  ADD COLUMN IF NOT EXISTS custom_max_properties  INTEGER,
  ADD COLUMN IF NOT EXISTS custom_max_users        INTEGER,
  ADD COLUMN IF NOT EXISTS custom_max_rooms        INTEGER,
  ADD COLUMN IF NOT EXISTS custom_max_tables       INTEGER,
  ADD COLUMN IF NOT EXISTS custom_price_monthly    NUMERIC(10,2), -- charged amount per month
  ADD COLUMN IF NOT EXISTS custom_price_annually   NUMERIC(10,2), -- charged amount per year
  ADD COLUMN IF NOT EXISTS billing_cycle           TEXT;          -- 'monthly' | 'annually'

-- Superadmins need UPDATE on organizations to set custom limits
-- (policy already covers this via existing superadmin policies, but
--  grant the column-level permission explicitly just in case)
GRANT UPDATE (plan, custom_max_properties, custom_max_users,
              custom_max_rooms, custom_max_tables,
              custom_price_monthly, custom_price_annually, billing_cycle)
  ON organizations TO authenticated;
