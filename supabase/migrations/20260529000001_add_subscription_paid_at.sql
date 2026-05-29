-- Tracks when an enterprise org's custom subscription was last paid.
-- NULL  = provisioned but no successful payment yet  → payment wall active.
-- Non-null = paid at least once  → allowed into the app.
-- Set by payhere-notify edge function when plan='enterprise' payment succeeds.

ALTER TABLE organizations
  ADD COLUMN IF NOT EXISTS subscription_paid_at TIMESTAMPTZ;
