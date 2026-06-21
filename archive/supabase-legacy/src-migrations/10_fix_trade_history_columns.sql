-- Fix trade_history column mismatch
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
    
    -- Update the status of all books in this trade to available
    UPDATE books
    SET 
      status = 'available',
      current_trade_id = NULL
    WHERE current_trade_id = p_trade_id;

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
      UPDATE books
      SET 
        status = 'available',
        current_trade_id = NULL
      WHERE current_trade_id = p_trade_id;
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

-- Also fix create_direct_request to use actor_id
CREATE OR REPLACE FUNCTION create_direct_request(
  p_book_id UUID,
  p_note TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_book_owner_id UUID;
  v_book_title TEXT;
  v_trade_id UUID;
  v_interest_id UUID;
  v_legacy_request_exists BOOLEAN;
  v_existing_trade UUID;
  v_existing_cancelled_trade UUID;
  v_user_full_name TEXT;
BEGIN
  -- Get the current user ID
  v_user_id := auth.uid();
  
  -- Check if user is authenticated
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  
  -- Get book owner ID and title, check existence implicitly
  SELECT 
    user_id,
    title
  INTO 
    v_book_owner_id,
    v_book_title
  FROM books 
  WHERE id = p_book_id
  LIMIT 1;
  
  -- If owner ID is null, book doesn't exist
  IF v_book_owner_id IS NULL THEN
    RAISE EXCEPTION 'Book not found';
  END IF;
  
  -- Don't allow requesting your own book
  IF v_book_owner_id = v_user_id THEN
    RAISE EXCEPTION 'You cannot request your own book';
  END IF;
  
  -- Check if book is available
  IF EXISTS(
    SELECT 1 FROM books 
    WHERE id = p_book_id AND status != 'available'
  ) THEN
    RAISE EXCEPTION 'Book is not available for trading';
  END IF;
  
  -- Check if an active trade already exists for this book and user
  SELECT t.id
  INTO v_existing_trade
  FROM trades t
  JOIN trade_items ti ON t.id = ti.trade_id
  WHERE t.initiator_id = v_user_id
    AND ti.book_id = p_book_id
    AND t.status IN ('request_pending', 'pending', 'proposed', 'accepted')
  LIMIT 1;
  
  IF v_existing_trade IS NOT NULL THEN
    RETURN v_existing_trade;
  END IF;
  
  -- Check if a cancelled trade already exists for this book and user from the last 24 hours
  -- If so, reuse that trade by updating its status back to request_pending
  SELECT t.id
  INTO v_existing_cancelled_trade
  FROM trades t
  JOIN trade_items ti ON t.id = ti.trade_id
  WHERE t.initiator_id = v_user_id
    AND ti.book_id = p_book_id
    AND t.status = 'cancelled'
    AND t.updated_at > NOW() - INTERVAL '24 hours'
  ORDER BY t.updated_at DESC
  LIMIT 1;
  
  IF v_existing_cancelled_trade IS NOT NULL THEN
    -- Get the requester's full name for the notification
    SELECT full_name INTO v_user_full_name FROM profiles WHERE id = v_user_id;
    
    -- Update existing cancelled trade to request_pending
    UPDATE trades
    SET 
      status = 'request_pending',
      updated_at = NOW(),
      notes = COALESCE(p_note, notes)
    WHERE id = v_existing_cancelled_trade;
    
    -- Log the reactivation in trade history
    INSERT INTO trade_history (
      trade_id,
      action,
      actor_id,
      details
    ) VALUES (
      v_existing_cancelled_trade,
      'reactivated',
      v_user_id,
      jsonb_build_object(
        'previous_status', 'cancelled',
        'new_status', 'request_pending',
        'book_id', p_book_id,
        'book_title', v_book_title
      )
    );
    
    -- Create notification for book owner about the reactivated request
    INSERT INTO user_notifications (
      user_id,
      type,
      title,
      description,
      trade_id,
      book_id,
      source_user_id,
      user_name
    ) VALUES (
      v_book_owner_id,
      'book_requested',
      'Book request received',
      'Someone has requested your book "' || v_book_title || '"',
      v_existing_cancelled_trade,
      p_book_id,
      v_user_id::TEXT,
      v_user_full_name
    );
    
    RETURN v_existing_cancelled_trade;
  END IF;
  
  -- Check if a legacy book request exists for this book and user
  SELECT EXISTS(
    SELECT 1 FROM book_requests WHERE book_id = p_book_id AND requester_id = v_user_id
  ) INTO v_legacy_request_exists;
  
  -- If no legacy request exists, then ensure the book is available
  IF NOT v_legacy_request_exists THEN
    IF EXISTS(
      SELECT 1 FROM books 
      WHERE id = p_book_id AND status != 'available'
    ) THEN
      RAISE EXCEPTION 'Book is not available for trading';
    END IF;
  END IF;
  
  -- Also mark interest in the book
  SELECT mark_book_interest(p_book_id, p_note) INTO v_interest_id;
  
  -- Get the requester's full name for the notification
  SELECT full_name INTO v_user_full_name FROM profiles WHERE id = v_user_id;
  
  -- Create the trade record with request_pending status
  INSERT INTO trades (
    initiator_id,
    recipient_id,
    status,
    notes,
    trade_type,
    last_modified_by
  ) VALUES (
    v_user_id,
    v_book_owner_id,
    'request_pending',
    p_note,
    'direct_request',
    v_user_id
  )
  RETURNING id INTO v_trade_id;
  
  -- Create a trade item for the requested book
  INSERT INTO trade_items (
    trade_id,
    book_id,
    owner_id,
    recipient_id,
    interest_id,
    item_type
  ) VALUES (
    v_trade_id,
    p_book_id,
    v_book_owner_id,
    v_user_id,
    v_interest_id,
    'requested'
  );
  
  -- Log the action in trade history
  INSERT INTO trade_history (
    trade_id,
    action,
    actor_id,
    details
  ) VALUES (
    v_trade_id,
    'created',
    v_user_id,
    jsonb_build_object(
      'trade_type', 'direct_request',
      'book_id', p_book_id,
      'book_title', v_book_title
    )
  );
  
  -- Create notification for book owner
  INSERT INTO user_notifications (
    user_id,
    type,
    title,
    description,
    trade_id,
    book_id,
    source_user_id,
    user_name
  ) VALUES (
    v_book_owner_id,
    'book_requested',
    'Book request received',
    'Someone has requested your book "' || v_book_title || '"',
    v_trade_id,
    p_book_id,
    v_user_id::TEXT,
    v_user_full_name
  );
  
  RETURN v_trade_id;
END;
$$; 