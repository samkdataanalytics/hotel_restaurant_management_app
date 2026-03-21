-- ============================================================
-- Migration 008: Per-Property Unique Username System
--
-- Problem this solves:
--   Migration 005 added a GLOBAL unique index on profiles.username.
--   That prevents two properties from both having a "manager"
--   account, which breaks multi-tenant staff management.
--
-- This migration:
--   1. Creates property_staff_usernames — tracks requested vs.
--      final (auto-suffixed) username per property.
--      (Named per project convention: property_staff_*
--       This is the equivalent of the requested "user_profiles"
--       table, scoped to match existing naming patterns.)
--   2. BEFORE INSERT trigger auto-assigns the next available
--      suffix: "manager" → "manager_1" → "manager_2" etc.
--   3. Drops the global profiles_username_idx (005) — replaced
--      by the per-property composite unique index here.
--   4. Adds resolve_staff_username() — a read-only helper for
--      edge functions to pre-compute the final username before
--      creating the auth.users row.
--   5. Adds get_email_by_username(username, property_id) — a
--      property-scoped overload alongside the old global one.
--   6. Updates create_staff_member() to populate this table and
--      return the final_username (changed from VOID → TEXT).
--
-- Email uniqueness note:
--   Because the same username can now exist across properties,
--   the synthetic email must encode both. New format:
--     {final_username}@{property_id_no_hyphens}.staff.internal
--   The edge function create-staff-account must be updated to
--   call resolve_staff_username() first, build this email, then
--   create the auth user — see comments at the bottom of this
--   file.
--
-- Run in Supabase SQL editor after 007_create_staff_member_fn.sql
-- ============================================================


-- ============================================================
-- PART 1 — property_staff_usernames table
-- ============================================================

CREATE TABLE IF NOT EXISTS property_staff_usernames (
  id                 UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id            UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  property_id        UUID        NOT NULL REFERENCES hotels(id)     ON DELETE CASCADE,
  requested_username TEXT        NOT NULL,   -- what the admin typed
  final_username     TEXT        NOT NULL,   -- assigned by trigger (may have suffix)
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- One username record per user per property
  UNIQUE (property_id, user_id)
);

COMMENT ON TABLE property_staff_usernames IS
  'Tracks the requested and trigger-assigned final username for each staff '
  'member within a property. Uniqueness is scoped per-property, not global.';

COMMENT ON COLUMN property_staff_usernames.requested_username IS
  'The username the admin originally requested (e.g. "manager").';

COMMENT ON COLUMN property_staff_usernames.final_username IS
  'The unique-within-property username actually assigned '
  '(e.g. "manager", "manager_1", "manager_2"). Set by trigger.';


-- ============================================================
-- PART 2 — Uniqueness: case-insensitive, per property
--
-- PostgreSQL does not support expressions in UNIQUE constraints,
-- so we use a functional unique index instead.
-- This is the authoritative uniqueness enforcement — the trigger
-- avoids duplicates, this index is the hard guarantee.
-- ============================================================

CREATE UNIQUE INDEX IF NOT EXISTS psn_property_username_uniq
  ON property_staff_usernames (property_id, lower(final_username));

-- Fast lookup by user_id (e.g. "what is this user's username?")
CREATE INDEX IF NOT EXISTS psn_user_idx
  ON property_staff_usernames (user_id);


-- ============================================================
-- PART 3 — Trigger: auto-assign unique final_username on INSERT
--
-- Logic:
--   base = sanitize(lower(trim(requested_username)))
--   Try: base → base_1 → base_2 → ... until not taken
--   Sets NEW.final_username before the row is written.
--
-- SECURITY DEFINER: needed so the trigger can query the table
--   during INSERT without hitting RLS (which would block the
--   service_role edge function path).
-- SET search_path = public: prevents search_path injection.
-- ============================================================

CREATE OR REPLACE FUNCTION generate_unique_staff_username()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_base    TEXT;
  v_final   TEXT;
  v_counter INT := 0;
BEGIN
  -- Normalize: lowercase, trim whitespace
  v_base := lower(trim(NEW.requested_username));

  -- Sanitize: replace any character that is not a-z, 0-9, or _
  -- with an underscore (keeps usernames URL/login-safe)
  v_base := regexp_replace(v_base, '[^a-z0-9_]', '_', 'g');

  -- Collapse multiple consecutive underscores into one
  v_base := regexp_replace(v_base, '_+', '_', 'g');

  -- Strip leading/trailing underscores that sanitization may have created
  v_base := trim(BOTH '_' FROM v_base);

  -- Fallback if the base becomes empty after sanitization
  IF v_base = '' THEN
    v_base := 'user';
  END IF;

  -- ── Suffix loop ──────────────────────────────────────────
  -- Iteration 0 → try "manager"
  -- Iteration 1 → try "manager_1"
  -- Iteration 2 → try "manager_2"  ...etc.
  LOOP
    IF v_counter = 0 THEN
      v_final := v_base;
    ELSE
      v_final := v_base || '_' || v_counter::TEXT;
    END IF;

    -- Check for case-insensitive match within this property only
    EXIT WHEN NOT EXISTS (
      SELECT 1
      FROM   property_staff_usernames
      WHERE  property_id         = NEW.property_id
        AND  lower(final_username) = v_final
    );

    v_counter := v_counter + 1;

    -- Safety valve: no property should ever need 1000 variants
    -- of the same username.
    IF v_counter > 999 THEN
      RAISE EXCEPTION
        'generate_unique_staff_username: exceeded 999 variants for base '
        'username "%" in property %. Clean up unused accounts first.',
        v_base, NEW.property_id;
    END IF;
  END LOOP;

  NEW.final_username := v_final;
  RETURN NEW;
END;
$$;

-- Fire BEFORE INSERT so the unique index sees the corrected value.
-- BEFORE UPDATE is intentionally omitted — final_username must not
-- change after creation (auth email depends on it).
DROP TRIGGER IF EXISTS trg_generate_staff_username
  ON property_staff_usernames;

CREATE TRIGGER trg_generate_staff_username
  BEFORE INSERT ON property_staff_usernames
  FOR EACH ROW
  EXECUTE FUNCTION generate_unique_staff_username();


-- ============================================================
-- PART 4 — Drop the global username unique index from 005
--
-- profiles_username_idx enforced global uniqueness, which
-- prevents multi-property staff with the same requested name.
-- Per-property uniqueness is now enforced by psn_property_username_uniq.
-- ============================================================

DROP INDEX IF EXISTS profiles_username_idx;


-- ============================================================
-- PART 5 — resolve_staff_username()
--
-- READ-ONLY helper. Runs the same suffix logic as the trigger
-- but does NOT insert. Used by the create-staff-account edge
-- function to pre-compute the final username BEFORE creating
-- the auth.users row (so the synthetic email can be built
-- correctly without a round-trip after the fact).
--
-- Race-condition note: there is a narrow window between this
-- call and the actual INSERT where another request could claim
-- the same name. For a hotel SaaS where staff creation is a
-- manual admin action this is acceptable. If strict atomicity
-- is needed, wrap auth-user creation + create_staff_member()
-- inside a database transaction via a single edge function call.
-- ============================================================

CREATE OR REPLACE FUNCTION resolve_staff_username(
  p_username    TEXT,
  p_property_id UUID
)
RETURNS TEXT
LANGUAGE plpgsql
STABLE          -- read-only; Postgres can cache within a statement
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_base    TEXT;
  v_final   TEXT;
  v_counter INT := 0;
BEGIN
  v_base := lower(trim(p_username));
  v_base := regexp_replace(v_base, '[^a-z0-9_]', '_', 'g');
  v_base := regexp_replace(v_base, '_+', '_', 'g');
  v_base := trim(BOTH '_' FROM v_base);

  IF v_base = '' THEN
    v_base := 'user';
  END IF;

  LOOP
    IF v_counter = 0 THEN
      v_final := v_base;
    ELSE
      v_final := v_base || '_' || v_counter::TEXT;
    END IF;

    EXIT WHEN NOT EXISTS (
      SELECT 1
      FROM   property_staff_usernames
      WHERE  property_id         = p_property_id
        AND  lower(final_username) = v_final
    );

    v_counter := v_counter + 1;

    IF v_counter > 999 THEN
      RAISE EXCEPTION
        'resolve_staff_username: exceeded 999 variants for "%".', v_base;
    END IF;
  END LOOP;

  RETURN v_final;
END;
$$;

-- Callable by authenticated users (managers) and anon (edge functions
-- using the service role key present via Authorization header).
GRANT EXECUTE ON FUNCTION resolve_staff_username(TEXT, UUID)
  TO anon, authenticated;


-- ============================================================
-- PART 6 — get_email_by_username(username, property_id)
--
-- Property-scoped overload. Replaces the global version from
-- migration 005 for username-based staff accounts.
--
-- Resolves: (final_username, property_id) → email stored in
-- profiles, which is the synthetic auth email.
-- ============================================================

CREATE OR REPLACE FUNCTION get_email_by_username(
  p_username    TEXT,
  p_property_id UUID
)
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p.email
  FROM   property_staff_usernames psn
  JOIN   profiles p ON p.id = psn.user_id
  WHERE  psn.property_id         = p_property_id
    AND  lower(psn.final_username) = lower(p_username)
  LIMIT  1;
$$;

GRANT EXECUTE ON FUNCTION get_email_by_username(TEXT, UUID)
  TO anon, authenticated;


-- ============================================================
-- PART 7 — Update create_staff_member()
--
-- Changes from 007:
--   • Inserts into property_staff_usernames FIRST; the trigger
--     assigns final_username.
--   • Reads back the final_username (may differ from input).
--   • Stores final_username (not raw input) in profiles.username.
--   • Return type changed from VOID → TEXT so the edge function
--     can read back the final username to update auth.users email.
--
-- DROP required: PostgreSQL does not allow CREATE OR REPLACE to
-- change a function's return type (007 declared it VOID).
-- ============================================================

DROP FUNCTION IF EXISTS create_staff_member(UUID, TEXT, TEXT, UUID, UUID, JSONB);

CREATE OR REPLACE FUNCTION create_staff_member(
  p_user_id     UUID,
  p_username    TEXT,
  p_email       TEXT,
  p_property_id UUID,
  p_org_id      UUID,
  p_permissions JSONB DEFAULT '{}'
)
RETURNS TEXT     -- returns the final_username actually assigned
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_final_username TEXT;
BEGIN
  -- ── Step 1: Register username (trigger assigns final_username) ──
  -- Pass empty string for final_username — the trigger overwrites it.
  INSERT INTO property_staff_usernames
    (user_id, property_id, requested_username, final_username)
  VALUES
    (p_user_id, p_property_id, lower(trim(p_username)), '')
  ON CONFLICT (property_id, user_id) DO NOTHING;

  -- Read back what the trigger assigned
  SELECT final_username
  INTO   v_final_username
  FROM   property_staff_usernames
  WHERE  user_id      = p_user_id
    AND  property_id  = p_property_id;

  -- Fallback: if the row already existed (DO NOTHING), use the
  -- pre-existing final_username (staff re-added to same property).
  IF v_final_username IS NULL THEN
    v_final_username := lower(trim(p_username));
  END IF;

  -- ── Step 2: Upsert profile with the resolved username ──────────
  INSERT INTO profiles (id, full_name, username, email)
  VALUES (p_user_id, v_final_username, v_final_username, p_email)
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    username  = EXCLUDED.username,
    email     = EXCLUDED.email;

  -- ── Step 3: Organization membership ────────────────────────────
  INSERT INTO organization_members (org_id, user_id, role)
  VALUES (p_org_id, p_user_id, 'member')
  ON CONFLICT (org_id, user_id) DO NOTHING;

  -- ── Step 4: Property staff membership ──────────────────────────
  INSERT INTO property_staff (property_id, user_id, role)
  VALUES (p_property_id, p_user_id, 'staff')
  ON CONFLICT (property_id, user_id) DO NOTHING;

  -- ── Step 5: Per-section permissions ────────────────────────────
  INSERT INTO property_staff_permissions (property_id, user_id, section, privilege)
  SELECT p_property_id, p_user_id, key, value
  FROM   jsonb_each_text(p_permissions)
  ON CONFLICT (property_id, user_id, section)
    DO UPDATE SET privilege = EXCLUDED.privilege;

  RETURN v_final_username;
END;
$$;

-- Callable by edge functions (service_role) and property managers
GRANT EXECUTE ON FUNCTION create_staff_member(UUID, TEXT, TEXT, UUID, UUID, JSONB)
  TO service_role, authenticated;


-- ============================================================
-- PART 8 — Grants
-- ============================================================

-- authenticated role: managers can INSERT when creating staff;
-- SELECT is needed to show the username list in Users Management.
-- UPDATE and DELETE are intentionally omitted — usernames are
-- immutable after creation (changing them would break auth email).
GRANT SELECT, INSERT ON property_staff_usernames TO authenticated;

-- service_role: full access for edge functions
GRANT ALL ON TABLE property_staff_usernames TO service_role;


-- ============================================================
-- PART 9 — RLS
-- ============================================================

ALTER TABLE property_staff_usernames ENABLE ROW LEVEL SECURITY;

-- SELECT: own row, or any member of the same property (managers
-- need to see all usernames in their property's staff list).
DROP POLICY IF EXISTS psn_select ON property_staff_usernames;
CREATE POLICY psn_select ON property_staff_usernames
  FOR SELECT USING (
    user_id = auth.uid()
    OR is_hotel_member(property_id)
    OR is_superadmin()
  );

-- INSERT: only property members (i.e. managers) or superadmins.
-- In practice this goes through the create_staff_member()
-- SECURITY DEFINER function, so this policy is a backstop.
DROP POLICY IF EXISTS psn_insert ON property_staff_usernames;
CREATE POLICY psn_insert ON property_staff_usernames
  FOR INSERT WITH CHECK (
    is_hotel_member(property_id) OR is_superadmin()
  );

-- UPDATE / DELETE: not exposed to clients.
-- Deleting a staff member deletes their property_staff row, which
-- cascades. Username records are kept for audit history.


-- ============================================================
-- PART 10 — Backfill existing staff accounts
--
-- Any staff created before this migration have a username in
-- profiles.username but no row in property_staff_usernames.
-- Back-fill them so get_email_by_username(TEXT, UUID) works.
-- Final username = existing profiles.username (already unique
-- because the old global index enforced it).
-- ============================================================

INSERT INTO property_staff_usernames
  (user_id, property_id, requested_username, final_username)
SELECT
  ps.user_id,
  ps.property_id,
  COALESCE(p.username, ''),
  COALESCE(p.username, '')
FROM property_staff ps
JOIN profiles       p  ON p.id = ps.user_id
WHERE p.username IS NOT NULL
  AND p.email LIKE '%@staff.internal'       -- only username-based accounts
  AND NOT EXISTS (                           -- skip if already migrated
    SELECT 1 FROM property_staff_usernames psn
    WHERE psn.user_id     = ps.user_id
      AND psn.property_id = ps.property_id
  );


-- ============================================================
-- Done.
--
-- ── Edge function update required ───────────────────────────
-- The create-staff-account edge function must be updated:
--
--   OLD flow:
--     1. email = `${username}@staff.internal`
--     2. adminClient.auth.admin.createUser({ email, password })
--     3. adminClient.rpc('create_staff_member', { ..., username })
--
--   NEW flow:
--     1. finalUsername = await adminClient
--          .rpc('resolve_staff_username', { p_username: username,
--                                          p_property_id: propertyId })
--     2. email = `${finalUsername}@${propertyId.replace(/-/g,'')}.staff.internal`
--     3. adminClient.auth.admin.createUser({ email, password })
--     4. finalUsername = await adminClient.rpc('create_staff_member',
--            { p_user_id: userId, p_username: username, p_email: email,
--              p_property_id: propertyId, p_org_id: orgId,
--              p_permissions: permissions })
--        // create_staff_member now returns TEXT (the final_username)
--     5. If step 4 throws, roll back: adminClient.auth.admin.deleteUser(userId)
--
--   The property-encoded email ensures auth.users.email stays
--   globally unique even when two properties share a username.
--
-- ── Login screen update required ────────────────────────────
-- The login screen must be updated to pass property_id alongside
-- username. Use the two-argument overload:
--   supabase.rpc('get_email_by_username',
--     { p_username: username, p_property_id: propertyId })
-- ============================================================
