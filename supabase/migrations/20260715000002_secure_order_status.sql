-- H-1: Narrow the restaurant_orders anon read path.
--
-- The existing restaurant_orders_guest_read RLS policy exposes all dineIn /
-- roomService orders across all active hotels to any anonymous client.
--
-- Fix:
--   1. Add SECURITY DEFINER RPC for the REST query path (fetchOrderStatus).
--      The RPC requires both orderId AND hotelId, preventing cross-hotel reads.
--   2. The Realtime stream path still needs an RLS policy; keep it but the
--      Flutter side now also passes .eq('hotel_id', propertyId) to each
--      subscription so the stream is scoped to the specific hotel.

CREATE OR REPLACE FUNCTION get_order_status(p_order_id UUID, p_hotel_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row restaurant_orders%ROWTYPE;
BEGIN
  SELECT * INTO v_row
  FROM   restaurant_orders
  WHERE  id       = p_order_id
    AND  hotel_id = p_hotel_id
    AND  type IN ('dineIn', 'roomService')
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  RETURN jsonb_build_object(
    'status',         v_row.status,
    'payment_status', v_row.payment_status
  );
END;
$$;

GRANT EXECUTE ON FUNCTION get_order_status(UUID, UUID) TO anon;
