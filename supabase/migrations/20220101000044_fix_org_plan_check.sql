-- Add 'starter' to the organizations plan CHECK constraint.
-- Original constraint only covered 'free','pro','enterprise'.

ALTER TABLE organizations
  DROP CONSTRAINT IF EXISTS organizations_plan_check;

ALTER TABLE organizations
  ADD CONSTRAINT organizations_plan_check
    CHECK (plan IN ('free', 'starter', 'pro', 'enterprise'));
