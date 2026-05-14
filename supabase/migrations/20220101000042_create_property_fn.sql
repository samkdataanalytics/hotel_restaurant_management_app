-- SECURITY DEFINER function for creating a property.
-- Bypasses RLS on hotels, property_staff, hotel_users, hotel_settings.
-- Verifies the caller is owner/admin of the target org before inserting.

CREATE OR REPLACE FUNCTION create_property(
  p_org_id           UUID,
  p_name             TEXT,
  p_slug             TEXT,
  p_type             TEXT,
  p_address          TEXT,
  p_city             TEXT,
  p_country          TEXT,
  p_phone            TEXT,
  p_email            TEXT,
  p_timezone         TEXT,
  p_currency         TEXT,
  p_logo_url         TEXT     DEFAULT '',
  p_booking_channels TEXT[]   DEFAULT ARRAY['direct']::TEXT[]
)
RETURNS SETOF hotels
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_hotel_id UUID;
  v_user_id  UUID := auth.uid();
BEGIN
  -- Caller must be owner or admin of the org
  IF NOT EXISTS (
    SELECT 1 FROM organization_members
    WHERE org_id = p_org_id AND user_id = v_user_id AND role IN ('owner', 'admin')
  ) THEN
    RAISE EXCEPTION 'Permission denied: must be org owner or admin';
  END IF;

  -- Insert the hotel
  INSERT INTO hotels (
    name, slug, org_id, type, address, city, country,
    phone, email, timezone, currency, logo_url, status, booking_channels
  ) VALUES (
    p_name, p_slug, p_org_id, p_type, p_address, p_city, p_country,
    p_phone, p_email, p_timezone, p_currency, p_logo_url, 'active',
    to_jsonb(p_booking_channels)
  ) RETURNING id INTO v_hotel_id;

  -- Add caller as property staff owner
  INSERT INTO property_staff (property_id, user_id, role)
  VALUES (v_hotel_id, v_user_id, 'owner')
  ON CONFLICT DO NOTHING;

  -- Seed hotel_users for backwards compat with existing screens
  INSERT INTO hotel_users (hotel_id, user_id, role)
  VALUES (v_hotel_id, v_user_id, 'owner')
  ON CONFLICT DO NOTHING;

  -- Seed hotel_settings
  INSERT INTO hotel_settings (hotel_id, display_name, address, phone, email)
  VALUES (v_hotel_id, p_name, p_address, p_phone, p_email)
  ON CONFLICT (hotel_id) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    address      = EXCLUDED.address,
    phone        = EXCLUDED.phone,
    email        = EXCLUDED.email;

  RETURN QUERY SELECT * FROM hotels WHERE id = v_hotel_id;
END;
$$;

COMMENT ON FUNCTION create_property IS
  'Creates a property (hotel) for an org. Caller must be org owner/admin. SECURITY DEFINER bypasses hotel RLS.';

REVOKE ALL ON FUNCTION create_property(UUID,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION create_property(UUID,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT[]) TO authenticated;
