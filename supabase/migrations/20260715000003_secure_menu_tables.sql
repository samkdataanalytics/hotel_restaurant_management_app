-- L-3: Replace the broad anon SELECT policies on menu_items and
-- restaurant_tables with SECURITY DEFINER RPCs scoped to a specific hotel_id.
--
-- Both policies previously allowed reading all active-hotel data without
-- a hotel_id constraint enforced by the DB (only by the client query).

-- ─── 1. Menu items RPC ───────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION get_available_menu_items(p_hotel_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN (
    SELECT jsonb_agg(row_to_json(mi)::jsonb ORDER BY mi.category, mi.name)
    FROM menu_items mi
    JOIN hotels h ON h.id = mi.hotel_id
    WHERE mi.hotel_id    = p_hotel_id
      AND mi.is_available = true
      AND h.status        = 'active'
      AND (h.is_deleted = false OR h.is_deleted IS NULL)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION get_available_menu_items(UUID) TO anon;

-- ─── 2. Restaurant table RPC ─────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION get_restaurant_table(p_hotel_id UUID, p_table_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row restaurant_tables%ROWTYPE;
BEGIN
  SELECT rt.* INTO v_row
  FROM   restaurant_tables rt
  JOIN   hotels h ON h.id = rt.hotel_id
  WHERE  rt.id       = p_table_id
    AND  rt.hotel_id = p_hotel_id
    AND  h.status    = 'active'
    AND  (h.is_deleted = false OR h.is_deleted IS NULL)
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  RETURN to_jsonb(v_row);
END;
$$;

GRANT EXECUTE ON FUNCTION get_restaurant_table(UUID, UUID) TO anon;

-- ─── 3. Drop the broad anon policies ─────────────────────────────────────────

DROP POLICY IF EXISTS menu_items_guest_read       ON menu_items;
DROP POLICY IF EXISTS restaurant_tables_guest_read ON restaurant_tables;
