-- ============================================================
-- Migration 061: Rate locking ("rates locked in for life when you sign up")
-- ============================================================
-- Per-org snapshot of the active price sheet, captured at org creation.
-- Future SuperAdmin price changes do NOT affect an org that already has a
-- locked book; new signups lock whatever prices are live at their signup.
--
-- Decisions:
--   * Lock timing: at signup, snapshot ALL active non-custom plans.
--   * Existing orgs: NOT backfilled — they keep following live plans pricing.
--     (Only orgs created after this migration get a locked book.)
--   * Enterprise (is_custom_price) is never locked here — it uses the org's
--     negotiated custom_price_* as before.
--
-- Enforcement lives in the payhere-hash Edge Function (authoritative amount).
-- This migration provides the data + the signup-time snapshot.
-- Idempotent: IF NOT EXISTS / CREATE OR REPLACE / DROP POLICY IF EXISTS.
-- ============================================================

-- ── Locked price book ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS org_locked_prices (
  org_id        UUID          NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  plan_slug     TEXT          NOT NULL,
  price_monthly NUMERIC(10,2) NOT NULL,
  locked_at     TIMESTAMPTZ   NOT NULL DEFAULT now(),
  PRIMARY KEY (org_id, plan_slug)
);

COMMENT ON TABLE org_locked_prices IS
  'Per-org snapshot of plan monthly prices captured at signup. Overrides the '
  'live plans table for that org (rate-locked-for-life). No row => follow live pricing.';

ALTER TABLE org_locked_prices ENABLE ROW LEVEL SECURITY;

-- Members can read their own org''s locked prices; superadmins read all.
DROP POLICY IF EXISTS org_locked_prices_select ON org_locked_prices;
CREATE POLICY org_locked_prices_select ON org_locked_prices
  FOR SELECT
  USING (org_id = current_org_id() OR is_superadmin());

-- Only superadmins may change locked prices directly from a client; everything
-- else is written by SECURITY DEFINER functions / service_role (webhook, signup).
DROP POLICY IF EXISTS org_locked_prices_superadmin_all ON org_locked_prices;
CREATE POLICY org_locked_prices_superadmin_all ON org_locked_prices
  FOR ALL
  USING (is_superadmin())
  WITH CHECK (is_superadmin());

GRANT SELECT ON org_locked_prices TO authenticated;
GRANT ALL    ON org_locked_prices TO service_role;

-- ── Snapshot the price sheet at org creation ───────────────────────────────────
-- Re-declare create_or_recover_organization (last defined in migration 059),
-- preserving the trial init and adding the locked-price snapshot in step 4.
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
  INSERT INTO organizations
         (name,   slug,   country,   phone,   logo_url,   plan,     status,     trial_ends_at)
  VALUES (p_name, p_slug, p_country, p_phone, p_logo_url, 'growth', 'trialing', now() + interval '45 days')
  RETURNING id INTO v_org_id;

  INSERT INTO organization_members (org_id, user_id, role)
  VALUES (v_org_id, v_user_id, 'owner');

  -- 4b. Rate lock: snapshot the live price sheet for this org (non-custom plans).
  --     This is what "rates locked in for life when you sign up now" means.
  INSERT INTO org_locked_prices (org_id, plan_slug, price_monthly)
  SELECT v_org_id, p.slug, p.price_monthly
  FROM   plans p
  WHERE  p.is_active = true
    AND  p.is_custom_price = false
  ON CONFLICT (org_id, plan_slug) DO NOTHING;

  RETURN QUERY SELECT * FROM organizations WHERE id = v_org_id;
END;
$$;

REVOKE ALL ON FUNCTION create_or_recover_organization(TEXT,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION create_or_recover_organization(TEXT,TEXT,TEXT,TEXT,TEXT) TO authenticated;
