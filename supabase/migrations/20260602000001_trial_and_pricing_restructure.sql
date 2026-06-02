-- ============================================================
-- Migration 059: 45-day trial + four-tier pricing restructure
-- ============================================================
-- Decisions baked in:
--   * Existing plan='free' orgs  -> fresh 45-day trial (growth/trialing).
--   * PayHere webhook            -> set status='active' on success (separate file).
--   * Room/table limits          -> counted org-wide in the app layer (separate files).
--   * Trial expiry               -> lazy/on-access via enforce_my_trial_expiry();
--                                   expire_due_trials() kept callable but NOT scheduled.
-- Idempotent: CREATE OR REPLACE for functions; DROP IF EXISTS before re-adding
-- constraints; data UPDATEs are keyed by slug so re-runs are no-ops.
-- ============================================================

-- -- 1. status enum: add trialing / trial_expired ----------------------------
ALTER TABLE organizations DROP CONSTRAINT IF EXISTS organizations_status_check;
ALTER TABLE organizations
  ADD CONSTRAINT organizations_status_check
    CHECK (status IN ('active', 'suspended', 'trialing', 'trial_expired'));
-- Allowed status values:
--   active        -- paid, or grandfathered/superadmin-activated; full access.
--   trialing      -- inside the 45-day trial; full hero access until trial_ends_at.
--   trial_expired -- trial elapsed unpaid; data READ-ONLY, creation blocked.
--   suspended     -- superadmin hold (pre-existing; no app gating today).

-- -- 2. trial_ends_at (nullable; NOT granted to authenticated) ---------------
ALTER TABLE organizations
  ADD COLUMN IF NOT EXISTS trial_ends_at TIMESTAMPTZ;
-- Deliberately NOT added to the authenticated column GRANT (migration 024),
-- and additionally blocked in guard_org_sensitive_columns() below.

-- -- 3. Migrate existing plan='free' orgs -> fresh 45-day trial --------------
-- (runs as postgres in migration context -> bypasses the guard trigger)
UPDATE organizations
   SET plan          = 'growth',
       status        = 'trialing',
       trial_ends_at = COALESCE(trial_ends_at, now() + interval '45 days')
 WHERE plan = 'free';

-- -- 4. Repurpose the 4 public plans (data) ----------------------------------
-- Display order after this: Starter(1), Growth(2, Most Popular), Pro(3), Enterprise(4).
-- free row -> Growth hero tier. Caps/price below are PLACEHOLDERS the owner edits
-- in the SuperAdmin panel; growth is the hero/trial tier so caps are the most
-- generous non-enterprise values. NEVER set max_tables = 0 (F&B in every tier).
UPDATE plans SET
  name            = 'Growth',
  slug            = 'growth',
  is_custom_price = false,
  is_highlighted  = true,
  is_active       = true,
  sort_order      = 2,
  max_properties  = 10,    -- PLACEHOLDER
  max_users       = 50,    -- PLACEHOLDER
  max_rooms       = 300,   -- PLACEHOLDER
  max_tables      = 60,    -- PLACEHOLDER (never 0)
  price_monthly   = 9990,  -- PLACEHOLDER (non-zero so it doesn't render "Free")
  updated_at      = now()
WHERE slug = 'free';

UPDATE plans SET
  is_highlighted = false, sort_order = 1, updated_at = now()
WHERE slug = 'starter';                          -- caps/price unchanged

UPDATE plans SET
  sort_order = 3, updated_at = now()
WHERE slug = 'pro';                              -- price left as owner-set placeholder

UPDATE plans SET
  is_custom_price = true, is_active = true, sort_order = 4, updated_at = now()
WHERE slug = 'enterprise';                       -- custom-request tier, unchanged

-- -- 5. plan default off 'free'; tighten CHECK (after step 3 cleared 'free') --
ALTER TABLE organizations ALTER COLUMN plan SET DEFAULT 'starter';

ALTER TABLE organizations DROP CONSTRAINT IF EXISTS organizations_plan_check;
ALTER TABLE organizations
  ADD CONSTRAINT organizations_plan_check
    CHECK (plan IN ('growth', 'starter', 'pro', 'enterprise'));

-- -- 6. Initialize the trial at org-creation (RPC step 4) --------------------
CREATE OR REPLACE FUNCTION create_or_recover_organization(
  p_name     TEXT,
  p_slug     TEXT,
  p_country  TEXT  DEFAULT '',
  p_phone    TEXT  DEFAULT '',
  p_logo_url TEXT  DEFAULT ''
)
RETURNS SETOF organizations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org_id  UUID;
  v_user_id UUID := auth.uid();
BEGIN
  -- 1. User already has active org membership -> idempotent full-retry path.
  SELECT om.org_id INTO v_org_id
  FROM   organization_members om
  WHERE  om.user_id    = v_user_id
    AND  (om.is_deleted = FALSE OR om.is_deleted IS NULL)
  LIMIT  1;

  IF v_org_id IS NOT NULL THEN
    RETURN QUERY SELECT * FROM organizations WHERE id = v_org_id;
    RETURN;
  END IF;

  -- 2. Orphaned org recovery (org row exists, membership INSERT failed before).
  SELECT id INTO v_org_id
  FROM   organizations
  WHERE  slug = p_slug AND created_by = v_user_id
  LIMIT  1;

  IF v_org_id IS NOT NULL THEN
    INSERT INTO organization_members (org_id, user_id, role)
    VALUES (v_org_id, v_user_id, 'owner')
    ON CONFLICT DO NOTHING;
    RETURN QUERY SELECT * FROM organizations WHERE id = v_org_id;
    RETURN;
  END IF;

  -- 3. Slug taken by another user's org.
  IF EXISTS (SELECT 1 FROM organizations WHERE slug = p_slug) THEN
    RAISE EXCEPTION
      'An organization with this URL already exists. Please try a different company name.';
  END IF;

  -- 4. Create new org + membership atomically -- START THE 45-DAY TRIAL.
  --    plan='growth' (hero) so even a naive plan-only limit check grants hero
  --    caps; status='trialing'; trial_ends_at 45 days out.
  INSERT INTO organizations
         (name,   slug,   country,   phone,   logo_url,   plan,     status,     trial_ends_at)
  VALUES (p_name, p_slug, p_country, p_phone, p_logo_url, 'growth', 'trialing', now() + interval '45 days')
  RETURNING id INTO v_org_id;

  INSERT INTO organization_members (org_id, user_id, role)
  VALUES (v_org_id, v_user_id, 'owner');

  RETURN QUERY SELECT * FROM organizations WHERE id = v_org_id;
END;
$$;

REVOKE ALL ON FUNCTION create_or_recover_organization(TEXT,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION create_or_recover_organization(TEXT,TEXT,TEXT,TEXT,TEXT) TO authenticated;

-- -- 7. Guard: block self-service trial_ends_at edits (all prior checks kept) -
CREATE OR REPLACE FUNCTION guard_org_sensitive_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- service_role, postgres, and supabase_admin bypass this guard
  -- (payhere-notify webhook, Edge Functions, and migrations run as these roles)
  IF current_user IN ('service_role', 'postgres', 'supabase_admin') THEN
    RETURN NEW;
  END IF;

  -- Superadmins may change any column (used by the admin panel)
  IF is_superadmin() THEN
    RETURN NEW;
  END IF;

  -- Regular authenticated users: block changes to payment / admin columns
  IF NEW.plan                  IS DISTINCT FROM OLD.plan                  THEN
    RAISE EXCEPTION 'Not authorized to change organization plan.';
  END IF;
  IF NEW.status                IS DISTINCT FROM OLD.status                THEN
    RAISE EXCEPTION 'Not authorized to change organization status.';
  END IF;
  IF NEW.trial_ends_at         IS DISTINCT FROM OLD.trial_ends_at         THEN
    RAISE EXCEPTION 'Not authorized to change organization trial period.';
  END IF;
  IF NEW.billing_cycle         IS DISTINCT FROM OLD.billing_cycle         THEN
    RAISE EXCEPTION 'Not authorized to change billing cycle directly.';
  END IF;
  IF NEW.created_by            IS DISTINCT FROM OLD.created_by            THEN
    RAISE EXCEPTION 'Not authorized to change organization creator.';
  END IF;
  IF NEW.custom_max_properties IS DISTINCT FROM OLD.custom_max_properties THEN
    RAISE EXCEPTION 'Not authorized to change organization custom limits.';
  END IF;
  IF NEW.custom_max_users      IS DISTINCT FROM OLD.custom_max_users      THEN
    RAISE EXCEPTION 'Not authorized to change organization custom limits.';
  END IF;
  IF NEW.custom_max_rooms      IS DISTINCT FROM OLD.custom_max_rooms      THEN
    RAISE EXCEPTION 'Not authorized to change organization custom limits.';
  END IF;
  IF NEW.custom_max_tables     IS DISTINCT FROM OLD.custom_max_tables     THEN
    RAISE EXCEPTION 'Not authorized to change organization custom limits.';
  END IF;
  IF NEW.custom_price_monthly  IS DISTINCT FROM OLD.custom_price_monthly  THEN
    RAISE EXCEPTION 'Not authorized to change organization custom limits.';
  END IF;
  IF NEW.custom_price_annually IS DISTINCT FROM OLD.custom_price_annually THEN
    RAISE EXCEPTION 'Not authorized to change organization custom limits.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_org_sensitive ON organizations;
CREATE TRIGGER trg_guard_org_sensitive
  BEFORE UPDATE ON organizations
  FOR EACH ROW EXECUTE FUNCTION guard_org_sensitive_columns();

-- -- 8. Trial-expiry helpers (SECURITY DEFINER; only flip trialing->expired) --
-- Batch flip -- callable for manual maintenance or a future pg_cron wiring.
-- NOTE: intentionally NOT scheduled. Run manually with:
--   SELECT expire_due_trials();
-- or later: SELECT cron.schedule('expire-trials','0 * * * *','SELECT expire_due_trials();');
CREATE OR REPLACE FUNCTION expire_due_trials()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_count INTEGER;
BEGIN
  UPDATE organizations
     SET status = 'trial_expired'
   WHERE status = 'trialing'
     AND trial_ends_at IS NOT NULL
     AND trial_ends_at < now();
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;
REVOKE ALL ON FUNCTION expire_due_trials() FROM PUBLIC;  -- superadmin/service only

-- Per-caller flip -- invoked by the app on load so the stored status reflects
-- reality for the caller's own org (mirrors apply_pending_provision).
CREATE OR REPLACE FUNCTION enforce_my_trial_expiry()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_org_id UUID;
BEGIN
  SELECT om.org_id INTO v_org_id
  FROM   organization_members om
  WHERE  om.user_id = auth.uid()
    AND  (om.is_deleted = FALSE OR om.is_deleted IS NULL)
  LIMIT  1;

  IF v_org_id IS NULL THEN RETURN; END IF;

  UPDATE organizations
     SET status = 'trial_expired'
   WHERE id = v_org_id
     AND status = 'trialing'
     AND trial_ends_at IS NOT NULL
     AND trial_ends_at < now();
END;
$$;
REVOKE ALL ON FUNCTION enforce_my_trial_expiry() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION enforce_my_trial_expiry() TO authenticated;
