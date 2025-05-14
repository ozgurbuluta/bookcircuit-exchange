-- Function to check if a user has requested a specific book
CREATE OR REPLACE FUNCTION get_book_trade_status(
  p_book_id UUID,
  p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_user_id UUID := auth.uid();
  v_trade_id UUID;
  v_trade_status TEXT;
  v_result JSONB;
BEGIN
  -- Check if user is authenticated
  IF v_current_user_id IS NULL THEN
    RAISE EXCEPTION 'User must be authenticated';
  END IF;

  -- Ensure the user ID matches the authenticated user
  IF v_current_user_id != p_user_id THEN
    RAISE EXCEPTION 'Unauthorized action';
  END IF;

  -- Find a trade where this user is requesting this book
  -- Look through trade_items where the book is included and the user is the initiator
  SELECT 
    t.id,
    t.status
  INTO 
    v_trade_id,
    v_trade_status
  FROM 
    trades t
  JOIN 
    trade_items ti ON t.id = ti.trade_id
  WHERE 
    ti.book_id = p_book_id
    AND t.initiator_id = p_user_id
    AND t.status IN ('request_pending', 'pending', 'proposed', 'accepted')
  LIMIT 1;

  -- Build the result object
  IF v_trade_id IS NOT NULL THEN
    v_result := jsonb_build_object(
      'is_requested', true,
      'trade_id', v_trade_id,
      'status', v_trade_status
    );
  ELSE
    v_result := jsonb_build_object(
      'is_requested', false
    );
  END IF;

  RETURN v_result;
END;
$$;

COMMENT ON FUNCTION get_book_trade_status IS 'Check if a user has requested a specific book through the trades system'; 