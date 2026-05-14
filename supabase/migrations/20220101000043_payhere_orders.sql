-- Tracks PayHere payment orders — created before checkout, updated by webhook.
-- Inserts and status updates are done exclusively via Edge Functions (service role).

CREATE TABLE payhere_orders (
  id                  TEXT          PRIMARY KEY,  -- 'PH-<timestamp>'
  org_id              UUID          NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  user_id             UUID          NOT NULL REFERENCES auth.users(id)    ON DELETE CASCADE,
  plan_slug           TEXT          NOT NULL,
  billing_cycle       TEXT          NOT NULL CHECK (billing_cycle IN ('monthly', 'annually')),
  amount              NUMERIC(10,2) NOT NULL,
  currency            TEXT          NOT NULL DEFAULT 'LKR',
  status              TEXT          NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending', 'completed', 'failed', 'cancelled')),
  payhere_payment_id  TEXT,
  created_at          TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ   NOT NULL DEFAULT now()
);

ALTER TABLE payhere_orders ENABLE ROW LEVEL SECURITY;

-- Owners can read their own orders (e.g. for a billing history page)
CREATE POLICY "payhere_orders_owner_select"
  ON payhere_orders FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- No client-side INSERT / UPDATE — Edge Functions use service role

-- Explicit grants required for Supabase's PostgREST roles
GRANT ALL   ON TABLE payhere_orders TO service_role;
GRANT SELECT ON TABLE payhere_orders TO authenticated;
