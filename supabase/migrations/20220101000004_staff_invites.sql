-- ============================================================
-- 004_staff_invites.sql
-- Invite-link based staff onboarding
-- Run this in the Supabase SQL editor.
-- ============================================================


-- ─── 1. staff_invites table ──────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS staff_invites (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id    UUID        NOT NULL REFERENCES hotels(id) ON DELETE CASCADE,
  org_id         UUID        NOT NULL,
  invited_email  TEXT        NOT NULL,
  permissions    JSONB       NOT NULL DEFAULT '{}',
  invited_by     UUID        REFERENCES auth.users(id),
  token          TEXT        NOT NULL UNIQUE DEFAULT encode(gen_random_bytes(32), 'hex'),
  status         TEXT        NOT NULL DEFAULT 'pending'
                 CHECK (status IN ('pending', 'accepted', 'expired')),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at     TIMESTAMPTZ NOT NULL DEFAULT now() + interval '7 days'
);

CREATE INDEX IF NOT EXISTS si_property_idx ON staff_invites(property_id);
CREATE INDEX IF NOT EXISTS si_token_idx    ON staff_invites(token);


-- ─── 2. Grants ────────────────────────────────────────────────────────────────

GRANT SELECT, INSERT, UPDATE ON staff_invites TO authenticated;
GRANT SELECT               ON staff_invites TO anon;  -- preview only (by token)


-- ─── 3. RLS ───────────────────────────────────────────────────────────────────

ALTER TABLE staff_invites ENABLE ROW LEVEL SECURITY;

-- Property managers can create + read invites for their property
DROP POLICY IF EXISTS si_select ON staff_invites;
CREATE POLICY si_select ON staff_invites
  FOR SELECT USING (
    is_hotel_member(property_id)
    OR is_superadmin()
    -- Allow reading a specific invite row by token without auth (for preview)
    -- Achieved by the separate anon function below
  );

DROP POLICY IF EXISTS si_insert ON staff_invites;
CREATE POLICY si_insert ON staff_invites
  FOR INSERT WITH CHECK (is_hotel_member(property_id) OR is_superadmin());

DROP POLICY IF EXISTS si_update ON staff_invites;
CREATE POLICY si_update ON staff_invites
  FOR UPDATE USING (true); -- accept_staff_invite RPC updates status (SECURITY DEFINER)


-- ─── 4. get_invite_preview — readable without auth ───────────────────────────
-- Called by AcceptInviteScreen before the user logs in or signs up.
-- Returns safe, non-sensitive info: property name + invited email + status.

CREATE OR REPLACE FUNCTION get_invite_preview(p_token TEXT)
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT jsonb_build_object(
    'property_name',  h.name,
    'invited_email',  si.invited_email,
    'status',         si.status,
    'expired',        si.expires_at < now()
  )
  FROM   staff_invites si
  JOIN   hotels h ON h.id = si.property_id
  WHERE  si.token = p_token
  LIMIT  1;
$$;

GRANT EXECUTE ON FUNCTION get_invite_preview TO anon, authenticated;


-- ─── 5. accept_staff_invite — processes the invite after the user is authed ──

CREATE OR REPLACE FUNCTION accept_staff_invite(p_token TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_invite    staff_invites%ROWTYPE;
  v_user_id   UUID := auth.uid();
BEGIN
  -- Validate: must be logged in
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Fetch and lock the invite row
  SELECT * INTO v_invite
  FROM   staff_invites
  WHERE  token    = p_token
    AND  status   = 'pending'
    AND  expires_at > now()
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'This invite link is invalid or has already been used.';
  END IF;

  -- Add to organization_members (role 'member' — no org admin rights)
  INSERT INTO organization_members (org_id, user_id, role)
  VALUES (v_invite.org_id, v_user_id, 'member')
  ON CONFLICT (org_id, user_id) DO NOTHING;

  -- Add to property_staff (role 'staff')
  INSERT INTO property_staff (property_id, user_id, role)
  VALUES (v_invite.property_id, v_user_id, 'staff')
  ON CONFLICT (property_id, user_id) DO NOTHING;

  -- Insert per-section permissions from the stored JSONB
  INSERT INTO property_staff_permissions (property_id, user_id, section, privilege)
  SELECT v_invite.property_id, v_user_id, key, value
  FROM   jsonb_each_text(v_invite.permissions)
  ON CONFLICT (property_id, user_id, section)
    DO UPDATE SET privilege = EXCLUDED.privilege;

  -- Mark invite as accepted
  UPDATE staff_invites SET status = 'accepted' WHERE id = v_invite.id;

  RETURN jsonb_build_object('property_id', v_invite.property_id);
END;
$$;

GRANT EXECUTE ON FUNCTION accept_staff_invite TO authenticated;


-- ─── Done ─────────────────────────────────────────────────────────────────────
-- Flow:
--   1. Admin fills invite form → creates staff_invites row → gets link
--   2. Admin shares the link (copy/paste, WhatsApp, email, etc.)
--   3. Invited person visits /accept-invite?token=XXX
--   4. App shows property name + invited email
--   5. Person signs up (new) or logs in (existing)
--   6. accept_staff_invite() RPC is called → adds them to org + property + permissions
--   7. App reloads auth state → router sends them to /app
-- ─────────────────────────────────────────────────────────────────────────────
