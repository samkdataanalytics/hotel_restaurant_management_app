-- ─────────────────────────────────────────────────────────────────────────────
-- 033_security_hardening_v2.sql
--
-- Findings from Security Audit:
-- 1. organization_members and property_staff had `FOR INSERT WITH CHECK (true)`.
--    This allowed any authenticated user to add themselves as an admin/owner to
--    ANY organization or property if they knew the ID, leading to massive privilege escalation.
-- 2. staff_invites had `FOR UPDATE USING (true)`.
--    This allowed any authenticated user to update arbitrary staff invites, potentially hijacking them.
--
-- Fixes:
-- 1. Restrict `org_members_insert` to either org creation (when empty) or invitation by existing admins/owners.
-- 2. Restrict `property_staff_insert` similarly.
-- 3. Scope `si_update` down to property members.
-- ─────────────────────────────────────────────────────────────────────────────

-- ═════════════════════════════════════════════════════════════════════════════
-- 1. Tighten organization_members INSERT
-- ═════════════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS org_members_insert ON organization_members;

CREATE POLICY org_members_insert ON organization_members
  FOR INSERT WITH CHECK (
    is_superadmin()
    OR (
        -- Case 1: Creator bootstrapping a new org (org has no active members yet)
        NOT EXISTS (
            SELECT 1 FROM organization_members om 
            WHERE om.org_id = org_id AND om.is_deleted = false
        )
        AND user_id = auth.uid()
    )
    OR (
        -- Case 2: Invited by an existing org owner/admin
        EXISTS (
            SELECT 1 FROM organization_members om 
            WHERE om.org_id = org_id 
              AND om.user_id = auth.uid() 
              AND om.role IN ('owner', 'admin') 
              AND om.is_deleted = false
        )
    )
  );

-- ═════════════════════════════════════════════════════════════════════════════
-- 2. Tighten property_staff INSERT
-- ═════════════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS property_staff_insert ON property_staff;

CREATE POLICY property_staff_insert ON property_staff
  FOR INSERT WITH CHECK (
    is_superadmin()
    OR (
        -- Case 1: Creator bootstrapping a new property (property has no active staff yet)
        NOT EXISTS (
            SELECT 1 FROM property_staff ps 
            WHERE ps.property_id = property_id AND ps.is_deleted = false
        )
        AND user_id = auth.uid()
    )
    OR (
        -- Case 2: Added by an existing org owner/admin
        EXISTS (
            SELECT 1 FROM hotels h
            JOIN organization_members om ON om.org_id = h.org_id
            WHERE h.id = property_id
              AND om.user_id = auth.uid()
              AND om.role IN ('owner', 'admin')
              AND om.is_deleted = false
        )
    )
    OR (
        -- Case 3: Added by an existing property owner/manager
        EXISTS (
            SELECT 1 FROM property_staff ps 
            WHERE ps.property_id = property_staff.property_id 
              AND ps.user_id = auth.uid() 
              AND ps.role IN ('owner', 'manager') 
              AND ps.is_deleted = false
        )
    )
  );

-- ═════════════════════════════════════════════════════════════════════════════
-- 3. Tighten staff_invites UPDATE (Commented out)
-- ═════════════════════════════════════════════════════════════════════════════
-- If you haven't run the 004_staff_invites migration, your DB doesn't have 
-- this table yet. 'DROP POLICY IF EXISTS' throws an error if the table is missing.
-- Uncomment this block only if/when you use the staff_invites table.

/*
DROP POLICY IF EXISTS si_update ON staff_invites;

-- The `accept_staff_invite` RPC is SECURITY DEFINER, so it circumvents this policy anyway.
-- This ensures UI-level updates (e.g., revoking an invite) are scoped to authorized members.
CREATE POLICY si_update ON staff_invites
  FOR UPDATE USING (
    is_hotel_member(property_id) OR is_superadmin()
  ) WITH CHECK (
    is_hotel_member(property_id) OR is_superadmin()
  );
*/
