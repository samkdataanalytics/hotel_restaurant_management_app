-- ============================================================
-- Migration 066: require company contact details
-- ============================================================
-- A company could previously register with no phone, no country and no
-- email at all:
--   * step1_company_details.dart had NO validator on country or phone
--   * create_or_recover_organization declared p_phone TEXT DEFAULT ''
--   * organizations.phone is NOT NULL DEFAULT '' -- empty string passes
--   * organizations had no email column whatsoever
-- Evidence in prod: one org registered with the phone number '123'.
--
-- This adds the missing columns and enforces presence + format in the
-- database, so the rules hold even for a direct PostgREST/RPC call that
-- bypasses the Flutter form.
--
-- Constraints are added NOT VALID: they are enforced on every INSERT and
-- UPDATE from now on, but pre-existing rows are grandfathered so the
-- migration cannot fail on historical data. Validate them later with
--   ALTER TABLE organizations VALIDATE CONSTRAINT <name>;
-- once the legacy rows are cleaned.
-- ============================================================

-- -- 1. New columns ---------------------------------------------------------
-- country keeps the display name (read by the SuperAdmin list and the
-- Organization model); country_code carries the ISO 3166-1 alpha-2 value.
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS email        TEXT NOT NULL DEFAULT '';
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS country_code TEXT NOT NULL DEFAULT '';

COMMENT ON COLUMN organizations.email IS
  'Company contact/billing address. Independent of the owner login email, which disappears if that person leaves.';
COMMENT ON COLUMN organizations.country_code IS
  'ISO 3166-1 alpha-2. Authoritative; the country column is the display name.';

-- -- 2. Backfill email from the owner profile --------------------------------
UPDATE organizations o
   SET email = p.email
  FROM organization_members om
  JOIN profiles p ON p.id = om.user_id
 WHERE om.org_id = o.id
   AND om.role   = 'owner'
   AND COALESCE(om.is_deleted, FALSE) = FALSE
   AND trim(o.email) = ''
   AND trim(COALESCE(p.email, '')) <> '';

-- -- 3. Backfill country_code, normalising the free-text spellings -----------
-- Existing data had both 'Sri Lanka' and 'SriLanka' as distinct values.
UPDATE organizations o
   SET country_code = m.code,
       country      = m.display
  FROM (VALUES
    ('srilanka',           'LK', 'Sri Lanka'),
    ('india',              'IN', 'India'),
    ('maldives',           'MV', 'Maldives'),
    ('singapore',          'SG', 'Singapore'),
    ('unitedstates',       'US', 'United States'),
    ('usa',                'US', 'United States'),
    ('unitedkingdom',      'GB', 'United Kingdom'),
    ('uk',                 'GB', 'United Kingdom'),
    ('australia',          'AU', 'Australia'),
    ('canada',             'CA', 'Canada'),
    ('unitedarabemirates', 'AE', 'United Arab Emirates'),
    ('uae',                'AE', 'United Arab Emirates')
  ) AS m(key, code, display)
 WHERE o.country_code = ''
   AND lower(regexp_replace(o.country, '[^a-zA-Z]', '', 'g')) = m.key;

-- -- 4. Format constraints (enforced on new writes; legacy rows exempt) ------
ALTER TABLE organizations DROP CONSTRAINT IF EXISTS organizations_email_chk;
ALTER TABLE organizations ADD  CONSTRAINT organizations_email_chk
  CHECK (email ~ '^[^@[:space:]]+@[^@[:space:].]+([.][^@[:space:].]+)+$') NOT VALID;

-- 7-15 digits is the E.164 range, counted after stripping +, spaces, dashes
-- and parentheses, so '+94 77 165 3296' passes and '123' does not.
ALTER TABLE organizations DROP CONSTRAINT IF EXISTS organizations_phone_chk;
ALTER TABLE organizations ADD  CONSTRAINT organizations_phone_chk
  CHECK (length(regexp_replace(phone, '[^0-9]', '', 'g')) BETWEEN 7 AND 15) NOT VALID;

ALTER TABLE organizations DROP CONSTRAINT IF EXISTS organizations_country_code_chk;
ALTER TABLE organizations ADD  CONSTRAINT organizations_country_code_chk
  CHECK (country_code ~ '^[A-Z][A-Z]$') NOT VALID;

-- -- 5. Validate the same rules in the signup RPC ----------------------------
-- The old 5-argument signature is dropped so it cannot be used as a
-- validation bypass. The new parameters carry defaults, so a stale client
-- calling with the old argument list fails with a clear, actionable message
-- rather than "function does not exist".
DROP FUNCTION IF EXISTS create_or_recover_organization(TEXT,TEXT,TEXT,TEXT,TEXT);

CREATE OR REPLACE FUNCTION create_or_recover_organization(
  p_name         TEXT,
  p_slug         TEXT,
  p_country      TEXT DEFAULT '',
  p_phone        TEXT DEFAULT '',
  p_logo_url     TEXT DEFAULT '',
  p_email        TEXT DEFAULT '',
  p_country_code TEXT DEFAULT ''
)
RETURNS SETOF organizations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_org_id       UUID;
  v_user_id      UUID := auth.uid();
  v_email        TEXT := lower(trim(COALESCE(p_email, '')));
  v_phone        TEXT := trim(COALESCE(p_phone, ''));
  v_country      TEXT := trim(COALESCE(p_country, ''));
  v_country_code TEXT := upper(trim(COALESCE(p_country_code, '')));
  v_digits       TEXT;
BEGIN
  -- 1. User already has active org membership -> idempotent full-retry path.
  --    Deliberately BEFORE validation so a retry can always recover the org.
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

  -- 3. Validate contact details -- only on the actual creation path.
  IF v_email = '' THEN
    RAISE EXCEPTION 'Company email is required.';
  END IF;
  IF v_email !~ '^[^@[:space:]]+@[^@[:space:].]+([.][^@[:space:].]+)+$' THEN
    RAISE EXCEPTION 'Please enter a valid company email address.';
  END IF;

  v_digits := regexp_replace(v_phone, '[^0-9]', '', 'g');
  IF v_digits = '' THEN
    RAISE EXCEPTION 'Company phone number is required.';
  END IF;
  IF length(v_digits) < 7 OR length(v_digits) > 15 THEN
    RAISE EXCEPTION 'Please enter a valid phone number (7 to 15 digits).';
  END IF;

  IF v_country_code !~ '^[A-Z][A-Z]$' THEN
    RAISE EXCEPTION 'Please select a country.';
  END IF;

  -- 4. Slug taken by another user org.
  IF EXISTS (SELECT 1 FROM organizations WHERE slug = p_slug) THEN
    RAISE EXCEPTION
      'An organization with this URL already exists. Please try a different company name.';
  END IF;

  -- 5. Create new org + membership atomically -- START THE 45-DAY TRIAL.
  INSERT INTO organizations
         (name,   slug,   country,   country_code,   phone,   email,   logo_url,
          plan,     status,     trial_ends_at)
  VALUES (p_name, p_slug, v_country, v_country_code, v_phone, v_email, p_logo_url,
          'growth', 'trialing', now() + interval '45 days')
  RETURNING id INTO v_org_id;

  INSERT INTO organization_members (org_id, user_id, role)
  VALUES (v_org_id, v_user_id, 'owner');

  RETURN QUERY SELECT * FROM organizations WHERE id = v_org_id;
END;
$fn$;

REVOKE ALL     ON FUNCTION create_or_recover_organization(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION create_or_recover_organization(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
