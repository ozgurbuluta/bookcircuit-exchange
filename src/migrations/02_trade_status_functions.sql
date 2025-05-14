-- Function to update a trade's status
CREATE OR REPLACE FUNCTION update_trade_status(
  p_trade_id UUID,
  p_new_status TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_initiator_id UUID;
  v_recipient_id UUID;
  v_current_status TEXT;
  v_current_user_id UUID := auth.uid();
  v_result JSONB;
BEGIN
  -- Check if user is authenticated
  IF v_current_user_id IS NULL THEN
    RAISE EXCEPTION 'User must be authenticated';
  END IF;

  -- Get the trade information
  SELECT 
    initiator_id, 
    recipient_id, 
    status
  INTO 
    v_initiator_id, 
    v_recipient_id, 
    v_current_status
  FROM trades
  WHERE id = p_trade_id;

  -- Check if trade exists
  IF v_initiator_id IS NULL THEN
    RAISE EXCEPTION 'Trade not found';
  END IF;

  -- Verify user is authorized to update this trade (must be initiator or recipient)
  IF v_current_user_id != v_initiator_id AND v_current_user_id != v_recipient_id THEN
    RAISE EXCEPTION 'Unauthorized to update this trade';
  END IF;

  -- Rule: Initiators can cancel their pending trades
  IF v_current_user_id = v_initiator_id AND 
     p_new_status = 'cancelled' AND 
     v_current_status IN ('request_pending', 'pending', 'proposed') THEN
    
    -- Update trade status
    UPDATE trades
    SET 
      status = p_new_status,
      updated_at = NOW()
    WHERE id = p_trade_id;

    -- Log action in trade history
    INSERT INTO trade_history (
      trade_id,
      user_id,
      action,
      details
    ) VALUES (
      p_trade_id,
      v_current_user_id,
      'status_update',
      jsonb_build_object(
        'previous_status', v_current_status,
        'new_status', p_new_status,
        'reason', 'cancelled_by_initiator'
      )
    );

    -- Add notification for the recipient
    PERFORM notify_trade_status_change(p_trade_id, p_new_status);
    
    v_result := jsonb_build_object(
      'success', true,
      'message', 'Trade cancelled successfully',
      'trade_id', p_trade_id,
      'status', p_new_status
    );
    
    RETURN v_result;
  
  -- Rule: Recipients can accept or reject pending trades
  ELSIF v_current_user_id = v_recipient_id AND 
        p_new_status IN ('accepted', 'rejected') AND 
        v_current_status IN ('request_pending', 'pending', 'proposed') THEN
    
    -- Update trade status
    UPDATE trades
    SET 
      status = p_new_status,
      updated_at = NOW()
    WHERE id = p_trade_id;

    -- Log action in trade history
    INSERT INTO trade_history (
      trade_id,
      user_id,
      action,
      details
    ) VALUES (
      p_trade_id,
      v_current_user_id,
      'status_update',
      jsonb_build_object(
        'previous_status', v_current_status,
        'new_status', p_new_status,
        'reason', CASE 
          WHEN p_new_status = 'accepted' THEN 'accepted_by_recipient'
          WHEN p_new_status = 'rejected' THEN 'rejected_by_recipient'
          ELSE 'other'
        END
      )
    );

    -- Add notification
    PERFORM notify_trade_status_change(p_trade_id, p_new_status);
    
    v_result := jsonb_build_object(
      'success', true,
      'message', 'Trade ' || p_new_status || ' successfully',
      'trade_id', p_trade_id,
      'status', p_new_status
    );
    
    RETURN v_result;

  -- Allow both parties to mark a trade as completed when it's accepted
  ELSIF (v_current_user_id = v_initiator_id OR v_current_user_id = v_recipient_id) AND
        p_new_status = 'completed' AND
        v_current_status = 'accepted' THEN
    
    -- Update trade status
    UPDATE trades
    SET 
      status = p_new_status,
      updated_at = NOW()
    WHERE id = p_trade_id;

    -- Log action in trade history
    INSERT INTO trade_history (
      trade_id,
      user_id,
      action,
      details
    ) VALUES (
      p_trade_id,
      v_current_user_id,
      'status_update',
      jsonb_build_object(
        'previous_status', v_current_status,
        'new_status', p_new_status,
        'reason', 'marked_complete'
      )
    );

    -- Add notification
    PERFORM notify_trade_status_change(p_trade_id, p_new_status);
    
    v_result := jsonb_build_object(
      'success', true,
      'message', 'Trade marked as completed',
      'trade_id', p_trade_id,
      'status', p_new_status
    );
    
    RETURN v_result;
    
  -- If not allowed, return error
  ELSE
    v_result := jsonb_build_object(
      'success', false,
      'message', 'Invalid status transition: Cannot change from ' || v_current_status || ' to ' || p_new_status || ' with your permissions'
    );
    
    RETURN v_result;
  END IF;
END;
$$;

COMMENT ON FUNCTION update_trade_status IS 'Update a trade status (cancel, reject, accept, complete) with appropriate permissions'; 