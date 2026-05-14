-- RPC: cancel_guest_order
-- Called by anon (guest QR) or authenticated (staff) clients.
-- Returns: 'cancelled' | 'not_cancellable' | 'already_cancelled' | 'not_found'
-- Only pending orders have inventory restored; preparing/ready/served orders return 'not_cancellable'.

CREATE OR REPLACE FUNCTION cancel_guest_order(p_order_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status      text;
  v_hotel_id    uuid;
  v_items       jsonb;
  v_num_items   int;
  v_item        jsonb;
  v_menu_id     text;
  v_active_qty  int;
  v_ingredients jsonb;
  v_num_ings    int;
  v_ing         jsonb;
  idx           int;
  jdx           int;
BEGIN
  -- ── 1. Fetch current order state ──────────────────────────────────────────
  SELECT status, hotel_id, COALESCE(items, '[]'::jsonb)
  INTO   v_status, v_hotel_id, v_items
  FROM   restaurant_orders
  WHERE  id = p_order_id;

  IF NOT FOUND               THEN RETURN 'not_found';         END IF;
  IF v_status = 'cancelled'  THEN RETURN 'already_cancelled'; END IF;
  IF v_status != 'pending'   THEN RETURN 'not_cancellable';   END IF;

  -- ── 2. Mark as cancelled ─────────────────────────────────────────────────
  UPDATE restaurant_orders
  SET    status = 'cancelled',
         inventory_restored = true
  WHERE  id = p_order_id;

  -- ── 3. Restore inventory item by item ────────────────────────────────────
  v_num_items := jsonb_array_length(v_items);

  FOR idx IN 0 .. v_num_items - 1 LOOP
    v_item := v_items -> idx;

    -- Skip items that were already fully refunded
    IF COALESCE((v_item ->> 'isRefunded')::boolean, false) THEN
      CONTINUE;
    END IF;

    v_active_qty := GREATEST(
      0,
      COALESCE((v_item ->> 'quantity')::int, 0)
      - COALESCE((v_item ->> 'refundedQuantity')::int, 0)
    );

    IF v_active_qty <= 0 THEN CONTINUE; END IF;

    v_menu_id := v_item -> 'menuItem' ->> 'id';
    IF v_menu_id IS NULL THEN CONTINUE; END IF;

    -- Get ingredient list for this menu item
    SELECT COALESCE(ingredients, '[]'::jsonb)
    INTO   v_ingredients
    FROM   menu_items
    WHERE  id = v_menu_id::uuid;

    IF NOT FOUND THEN CONTINUE; END IF;

    v_num_ings := jsonb_array_length(v_ingredients);

    FOR jdx IN 0 .. v_num_ings - 1 LOOP
      v_ing := v_ingredients -> jdx;

      UPDATE inventory
      SET    current_stock = GREATEST(
               0,
               current_stock
               + (v_ing ->> 'quantity')::numeric * v_active_qty
             ),
             updated_at = now()
      WHERE  ingredient_id = (v_ing ->> 'ingredientId')::uuid;
    END LOOP;
  END LOOP;

  RETURN 'cancelled';
END;
$$;

-- Allow both anon guests (QR ordering) and authenticated staff to call this.
GRANT EXECUTE ON FUNCTION cancel_guest_order(uuid) TO anon, authenticated;
