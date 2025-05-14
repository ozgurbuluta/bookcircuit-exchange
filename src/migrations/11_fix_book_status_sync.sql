-- Enhance update_trade_status to ensure books are properly released after cancellation
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
  v_book_ids UUID[];
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

  -- Get all book IDs in this trade
  SELECT array_agg(book_id) INTO v_book_ids
  FROM trade_items
  WHERE trade_id = p_trade_id;

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
    
    -- Update the status of all books in this trade to available
    -- First, update books that have this trade as current_trade_id
    UPDATE books
    SET 
      status = 'available',
      current_trade_id = NULL
    WHERE current_trade_id = p_trade_id;
    
    -- Then ensure all books associated with this trade in trade_items are also updated
    UPDATE books
    SET 
      status = 'available',
      current_trade_id = NULL
    WHERE id = ANY(v_book_ids);

    -- Log action in trade history
    INSERT INTO trade_history (
      trade_id,
      action,
      actor_id,
      details
    ) VALUES (
      p_trade_id,
      'status_update',
      v_current_user_id,
      jsonb_build_object(
        'previous_status', v_current_status,
        'new_status', p_new_status,
        'reason', 'cancelled_by_initiator'
      )
    );

    -- Return success response
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
    
    -- If rejected, update the status of all books in this trade to available
    IF p_new_status = 'rejected' THEN
      -- Update books that have this trade as current_trade_id
      UPDATE books
      SET 
        status = 'available',
        current_trade_id = NULL
      WHERE current_trade_id = p_trade_id;
      
      -- Also ensure all books associated with this trade in trade_items are updated
      UPDATE books
      SET 
        status = 'available',
        current_trade_id = NULL
      WHERE id = ANY(v_book_ids);
    END IF;

    -- Log action in trade history
    INSERT INTO trade_history (
      trade_id,
      action,
      actor_id,
      details
    ) VALUES (
      p_trade_id,
      'status_update',
      v_current_user_id,
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

    -- Return success response
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
      action,
      actor_id,
      details
    ) VALUES (
      p_trade_id,
      'status_update',
      v_current_user_id,
      jsonb_build_object(
        'previous_status', v_current_status,
        'new_status', p_new_status,
        'reason', 'marked_complete'
      )
    );

    -- Return success response
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

-- Fix the RequestableBookCard to check book status as well
CREATE OR REPLACE FUNCTION check_book_trade_status(
  p_book_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_active_trade_id UUID;
  v_trade_status TEXT;
  v_result JSONB;
BEGIN
  -- Check if user is authenticated
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  
  -- Find active trades for this book where user is the initiator
  SELECT t.id, t.status
  INTO v_active_trade_id, v_trade_status
  FROM trades t
  JOIN trade_items ti ON t.id = ti.trade_id
  WHERE ti.book_id = p_book_id
    AND t.initiator_id = v_user_id
    AND t.status IN ('request_pending', 'pending', 'proposed', 'accepted')
  LIMIT 1;
  
  IF v_active_trade_id IS NOT NULL THEN
    -- Return active trade info
    v_result := jsonb_build_object(
      'has_active_request', true,
      'trade_id', v_active_trade_id,
      'status', v_trade_status
    );
  ELSE
    -- No active trade found
    v_result := jsonb_build_object(
      'has_active_request', false
    );
  END IF;
  
  RETURN v_result;
END;
$$;

-- Add a function to fix book status directly
CREATE OR REPLACE FUNCTION fix_book_status(
  p_book_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_book_owner_id UUID;
  v_active_trade_id UUID;
BEGIN
  -- Check if user is authenticated
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  
  -- Get the book owner ID
  SELECT user_id INTO v_book_owner_id
  FROM books
  WHERE id = p_book_id;
  
  -- Check if book exists
  IF v_book_owner_id IS NULL THEN
    RAISE EXCEPTION 'Book not found';
  END IF;
  
  -- Find active trades for this book
  SELECT t.id
  INTO v_active_trade_id
  FROM trades t
  JOIN trade_items ti ON t.id = ti.trade_id
  WHERE ti.book_id = p_book_id
    AND t.status IN ('request_pending', 'pending', 'proposed', 'accepted')
  LIMIT 1;
  
  -- If no active trade exists, make sure the book is available
  IF v_active_trade_id IS NULL THEN
    UPDATE books
    SET 
      status = 'available',
      current_trade_id = NULL
    WHERE id = p_book_id;
    
    RETURN TRUE;
  ELSE
    -- If active trade exists, make sure book has correct trade_id
    UPDATE books
    SET 
      status = 'trading',
      current_trade_id = v_active_trade_id
    WHERE id = p_book_id;
    
    RETURN TRUE;
  END IF;
  
  RETURN FALSE;
END;
$$; 