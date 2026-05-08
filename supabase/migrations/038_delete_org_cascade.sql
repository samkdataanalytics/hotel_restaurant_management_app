-- Permanently deletes an organization and ALL associated data.
-- Restricted to superadmins only.
-- Deletion order: hotels (cascades all hotel-scoped data) → org (cascades members) → auth users

CREATE OR REPLACE FUNCTION delete_organization_cascade(p_org_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_ids UUID[];
BEGIN
  -- Superadmin guard
  IF NOT is_superadmin() THEN
    RAISE EXCEPTION 'Permission denied: superadmin only';
  END IF;

  -- Capture member user IDs before rows are deleted
  SELECT ARRAY(
    SELECT user_id FROM organization_members WHERE org_id = p_org_id
  ) INTO v_user_ids;

  -- Delete all hotels for this org.
  -- This cascades to: rooms, bookings, check_ins, guests, restaurant_orders,
  -- restaurant_tables, menu_items, menu_item_cost_records, ingredients,
  -- ingredient_prices, inventory, expenses, hotel_settings, hotel_users,
  -- staff_shifts, staff_time_records, notifications, property_staff,
  -- property_staff_permissions, property_staff_usernames, staff_invites.
  DELETE FROM hotels WHERE org_id = p_org_id;

  -- Delete the organization itself.
  -- This cascades to: organization_members.
  DELETE FROM organizations WHERE id = p_org_id;

  -- Delete auth users who belonged to this org and have no other org.
  IF v_user_ids IS NOT NULL AND array_length(v_user_ids, 1) > 0 THEN
    DELETE FROM auth.users
    WHERE id = ANY(v_user_ids)
      AND id NOT IN (
        SELECT DISTINCT user_id FROM organization_members
      );
  END IF;
END;
$$;

COMMENT ON FUNCTION delete_organization_cascade IS
  'Permanently deletes an org and all its data. Superadmin only. Irreversible.';

-- Only the authenticated role (filtered by is_superadmin() inside) can call this.
REVOKE ALL ON FUNCTION delete_organization_cascade(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION delete_organization_cascade(UUID) TO authenticated;
