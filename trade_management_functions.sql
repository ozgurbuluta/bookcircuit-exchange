-- Create a complete trade proposal
CREATE OR REPLACE FUNCTION create_trade(
  p_recipient_id UUID,
  p_requested_book_ids UUID[],
  p_offered_book_ids UUID[],
  p_completion_method VARCHAR DEFAULT NULL,
  p_meeting_location TEXT DEFAULT NULL,
  p_meeting_time TIMESTAMPTZ DEFAULT NULL,
  p_note TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_trade_id UUID;
  v_requested_book RECORD;
  v_offered_book RECORD;
  v_interest_id UUID;
BEGIN
  -- Get the current user ID
  v_user_id := auth.uid();
  
  -- Check if user is authenticated
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  
  -- Don't allow creating a trade with yourself
  IF p_recipient_id = v_user_id THEN
    RAISE EXCEPTION 'You cannot create a trade with yourself';
  END IF;
  
  -- Validate that requested books belong to recipient and are available
  FOR v_requested_book IN 
    SELECT id, user_id, title, status FROM books 
    WHERE id = ANY(p_requested_book_ids) 
  LOOP
    -- Check ownership
    IF v_requested_book.user_id != p_recipient_id THEN
      RAISE EXCEPTION 'Book % does not belong to the recipient', v_requested_book.id;
    END IF;
    
    -- Check availability
    IF v_requested_book.status != 'available' THEN
      RAISE EXCEPTION 'Book "%" is not available for trading', v_requested_book.title;
    END IF;
  END LOOP;
  
  -- Validate that offered books belong to the user and are available
  FOR v_offered_book IN 
    SELECT id, user_id, title, status FROM books 
    WHERE id = ANY(p_offered_book_ids) 
  LOOP
    -- Check ownership
    IF v_offered_book.user_id != v_user_id THEN
      RAISE EXCEPTION 'Book % does not belong to you', v_offered_book.id;
    END IF;
    
    -- Check availability
    IF v_offered_book.status != 'available' THEN
      RAISE EXCEPTION 'Book "%" is not available for trading', v_offered_book.title;
    END IF;
  END LOOP;
  
  -- Create the trade record
  INSERT INTO trades (
    initiator_id,
    recipient_id,
    status,
    completion_method,
    meeting_location,
    meeting_time,
    notes,
    trade_type,
    last_modified_by
  ) VALUES (
    v_user_id,
    p_recipient_id,
    'proposed',
    p_completion_method,
    p_meeting_location,
    p_meeting_time,
    p_note,
    'complete_trade',
    v_user_id
  )
  RETURNING id INTO v_trade_id;
  
  -- Add requested books to trade items
  FOR v_requested_book IN 
    SELECT id, user_id FROM books 
    WHERE id = ANY(p_requested_book_ids) 
  LOOP
    -- Mark interest in the requested book
    SELECT mark_book_interest(v_requested_book.id) INTO v_interest_id;
    
    INSERT INTO trade_items (
      trade_id,
      book_id,
      owner_id,
      recipient_id,
      interest_id,
      item_type
    ) VALUES (
      v_trade_id,
      v_requested_book.id,
      v_requested_book.user_id,
      v_user_id,
      v_interest_id,
      'requested'
    );
    
    -- Update book status to trading
    UPDATE books
    SET status = 'trading',
        current_trade_id = v_trade_id
    WHERE id = v_requested_book.id;
  END LOOP;
  
  -- Add offered books to trade items
  FOR v_offered_book IN 
    SELECT id, user_id FROM books 
    WHERE id = ANY(p_offered_book_ids) 
  LOOP
    INSERT INTO trade_items (
      trade_id,
      book_id,
      owner_id,
      recipient_id,
      item_type
    ) VALUES (
      v_trade_id,
      v_offered_book.id,
      v_offered_book.user_id,
      p_recipient_id,
      'offered'
    );
    
    -- Update book status to trading
    UPDATE books
    SET status = 'trading',
        current_trade_id = v_trade_id
    WHERE id = v_offered_book.id;
  END LOOP;
  
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
      'trade_type', 'complete_trade',
      'requested_book_count', array_length(p_requested_book_ids, 1),
      'offered_book_count', array_length(p_offered_book_ids, 1),
      'completion_method', p_completion_method
    )
  );
  
  -- Create notification for recipient
  INSERT INTO notifications (
    user_id,
    type,
    message,
    related_id,
    read
  ) VALUES (
    p_recipient_id,
    'trade_proposed',
    'You received a new trade proposal',
    v_trade_id,
    false
  );
  
  RETURN v_trade_id;
END;
$$;

-- Accept a trade
CREATE OR REPLACE FUNCTION accept_trade(
  p_trade_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_initiator_id UUID;
  v_trade_exists BOOLEAN;
  v_trade_status TEXT;
BEGIN
  -- Get the current user ID
  v_user_id := auth.uid();
  
  -- Check if user is authenticated
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  
  -- Check if trade exists and user is the recipient
  SELECT 
    EXISTS(SELECT 1 FROM trades WHERE id = p_trade_id),
    initiator_id,
    status
  INTO 
    v_trade_exists,
    v_initiator_id,
    v_trade_status
  FROM trades 
  WHERE id = p_trade_id AND recipient_id = v_user_id;
  
  IF NOT v_trade_exists THEN
    RAISE EXCEPTION 'Trade not found or you are not the recipient';
  END IF;
  
  -- Check if trade is in proposed status
  IF v_trade_status != 'proposed' THEN
    RAISE EXCEPTION 'Trade is not in proposed status';
  END IF;
  
  -- Update the trade to accepted status
  UPDATE trades
  SET status = 'accepted',
      last_modified_by = v_user_id
  WHERE id = p_trade_id;
  
  -- Log the action in trade history
  INSERT INTO trade_history (
    trade_id,
    action,
    actor_id,
    details
  ) VALUES (
    p_trade_id,
    'accepted',
    v_user_id,
    jsonb_build_object('timestamp', now())
  );
  
  -- Create notification for initiator
  INSERT INTO notifications (
    user_id,
    type,
    message,
    related_id,
    read
  ) VALUES (
    v_initiator_id,
    'trade_accepted',
    'Your trade proposal has been accepted',
    p_trade_id,
    false
  );
  
  RETURN TRUE;
END;
$$;

-- Reject a trade
CREATE OR REPLACE FUNCTION reject_trade(
  p_trade_id UUID,
  p_reason TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_initiator_id UUID;
  v_trade_exists BOOLEAN;
  v_trade_status TEXT;
BEGIN
  -- Get the current user ID
  v_user_id := auth.uid();
  
  -- Check if user is authenticated
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  
  -- Check if trade exists and user is the recipient
  SELECT 
    EXISTS(SELECT 1 FROM trades WHERE id = p_trade_id),
    initiator_id,
    status
  INTO 
    v_trade_exists,
    v_initiator_id,
    v_trade_status
  FROM trades 
  WHERE id = p_trade_id AND recipient_id = v_user_id;
  
  IF NOT v_trade_exists THEN
    RAISE EXCEPTION 'Trade not found or you are not the recipient';
  END IF;
  
  -- Check if trade is in proposed status
  IF v_trade_status != 'proposed' THEN
    RAISE EXCEPTION 'Trade is not in proposed status';
  END IF;
  
  -- Reset status of all books in the trade
  UPDATE books
  SET status = 'available',
      current_trade_id = NULL
  WHERE current_trade_id = p_trade_id;
  
  -- Update the trade to rejected status
  UPDATE trades
  SET status = 'rejected',
      notes = CASE 
                WHEN p_reason IS NOT NULL THEN 
                  COALESCE(notes, '') || E'\n\nRejection reason: ' || p_reason
                ELSE 
                  notes
              END,
      last_modified_by = v_user_id
  WHERE id = p_trade_id;
  
  -- Log the action in trade history
  INSERT INTO trade_history (
    trade_id,
    action,
    actor_id,
    details
  ) VALUES (
    p_trade_id,
    'rejected',
    v_user_id,
    jsonb_build_object(
      'timestamp', now(),
      'reason', p_reason
    )
  );
  
  -- Create notification for initiator
  INSERT INTO notifications (
    user_id,
    type,
    message,
    related_id,
    read
  ) VALUES (
    v_initiator_id,
    'trade_rejected',
    'Your trade proposal has been rejected',
    p_trade_id,
    false
  );
  
  RETURN TRUE;
END;
$$;

-- Complete a trade
CREATE OR REPLACE FUNCTION complete_trade(
  p_trade_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_initiator_id UUID;
  v_recipient_id UUID;
  v_trade_exists BOOLEAN;
  v_trade_status TEXT;
  v_is_participant BOOLEAN;
  v_trade_item RECORD;
BEGIN
  -- Get the current user ID
  v_user_id := auth.uid();
  
  -- Check if user is authenticated
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  
  -- Check if trade exists and user is a participant
  SELECT 
    EXISTS(SELECT 1 FROM trades WHERE id = p_trade_id),
    initiator_id,
    recipient_id,
    status,
    (initiator_id = v_user_id OR recipient_id = v_user_id) AS is_participant
  INTO 
    v_trade_exists,
    v_initiator_id,
    v_recipient_id,
    v_trade_status,
    v_is_participant
  FROM trades 
  WHERE id = p_trade_id;
  
  IF NOT v_trade_exists OR NOT v_is_participant THEN
    RAISE EXCEPTION 'Trade not found or you are not a participant';
  END IF;
  
  -- Check if trade is in accepted status
  IF v_trade_status != 'accepted' THEN
    RAISE EXCEPTION 'Trade is not in accepted status';
  END IF;
  
  -- Process all books in the trade
  FOR v_trade_item IN 
    SELECT ti.book_id, ti.owner_id, ti.recipient_id, ti.item_type, b.title
    FROM trade_items ti
    JOIN books b ON ti.book_id = b.id
    WHERE ti.trade_id = p_trade_id
  LOOP
    -- Transfer book ownership
    UPDATE books
    SET user_id = v_trade_item.recipient_id,
        status = 'available',
        current_trade_id = NULL,
        trade_count = trade_count + 1
    WHERE id = v_trade_item.book_id;
    
    -- Mark related interests as fulfilled
    UPDATE book_interests
    SET status = 'fulfilled'
    WHERE book_id = v_trade_item.book_id 
    AND user_id = v_trade_item.recipient_id
    AND status = 'active';
    
    -- Create notification for new book owner
    INSERT INTO notifications (
      user_id,
      type,
      message,
      related_id,
      read
    ) VALUES (
      v_trade_item.recipient_id,
      'book_acquired',
      'You have acquired the book "' || v_trade_item.title || '" through a trade',
      v_trade_item.book_id,
      false
    );
  END LOOP;
  
  -- Update the trade to completed status
  UPDATE trades
  SET status = 'completed',
      last_modified_by = v_user_id
  WHERE id = p_trade_id;
  
  -- Log the action in trade history
  INSERT INTO trade_history (
    trade_id,
    action,
    actor_id,
    details
  ) VALUES (
    p_trade_id,
    'completed',
    v_user_id,
    jsonb_build_object('timestamp', now())
  );
  
  -- Create notifications for both participants
  INSERT INTO notifications (
    user_id,
    type,
    message,
    related_id,
    read
  ) VALUES (
    v_initiator_id,
    'trade_completed',
    'A trade has been marked as completed',
    p_trade_id,
    false
  );
  
  -- Only send to recipient if they're not the one completing the trade
  IF v_recipient_id != v_user_id THEN
    INSERT INTO notifications (
      user_id,
      type,
      message,
      related_id,
      read
    ) VALUES (
      v_recipient_id,
      'trade_completed',
      'A trade has been marked as completed',
      p_trade_id,
      false
    );
  END IF;
  
  RETURN TRUE;
END;
$$;

-- Cancel a trade
CREATE OR REPLACE FUNCTION cancel_trade(
  p_trade_id UUID,
  p_reason TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_initiator_id UUID;
  v_recipient_id UUID;
  v_trade_exists BOOLEAN;
  v_trade_status TEXT;
  v_is_participant BOOLEAN;
  v_other_user_id UUID;
BEGIN
  -- Get the current user ID
  v_user_id := auth.uid();
  
  -- Check if user is authenticated
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  
  -- Check if trade exists and user is a participant
  SELECT 
    EXISTS(SELECT 1 FROM trades WHERE id = p_trade_id),
    initiator_id,
    recipient_id,
    status,
    (initiator_id = v_user_id OR recipient_id = v_user_id) AS is_participant
  INTO 
    v_trade_exists,
    v_initiator_id,
    v_recipient_id,
    v_trade_status,
    v_is_participant
  FROM trades 
  WHERE id = p_trade_id;
  
  IF NOT v_trade_exists OR NOT v_is_participant THEN
    RAISE EXCEPTION 'Trade not found or you are not a participant';
  END IF;
  
  -- Determine the other user for notification
  IF v_user_id = v_initiator_id THEN
    v_other_user_id := v_recipient_id;
  ELSE
    v_other_user_id := v_initiator_id;
  END IF;
  
  -- Check if trade is in an appropriate status for cancellation
  IF v_trade_status NOT IN ('request_pending', 'proposed', 'accepted') THEN
    RAISE EXCEPTION 'Trade cannot be cancelled in its current status';
  END IF;
  
  -- Reset status of all books in the trade
  UPDATE books
  SET status = 'available',
      current_trade_id = NULL
  WHERE current_trade_id = p_trade_id;
  
  -- Update the trade to cancelled status
  UPDATE trades
  SET status = 'cancelled',
      notes = CASE 
                WHEN p_reason IS NOT NULL THEN 
                  COALESCE(notes, '') || E'\n\nCancellation reason: ' || p_reason
                ELSE 
                  notes
              END,
      last_modified_by = v_user_id
  WHERE id = p_trade_id;
  
  -- Log the action in trade history
  INSERT INTO trade_history (
    trade_id,
    action,
    actor_id,
    details
  ) VALUES (
    p_trade_id,
    'cancelled',
    v_user_id,
    jsonb_build_object(
      'timestamp', now(),
      'reason', p_reason
    )
  );
  
  -- Create notification for the other user
  INSERT INTO notifications (
    user_id,
    type,
    message,
    related_id,
    read
  ) VALUES (
    v_other_user_id,
    'trade_cancelled',
    'A trade has been cancelled',
    p_trade_id,
    false
  );
  
  RETURN TRUE;
END;
$$;

-- Create a counteroffer
CREATE OR REPLACE FUNCTION create_counteroffer(
  p_original_trade_id UUID,
  p_requested_book_ids UUID[],
  p_offered_book_ids UUID[],
  p_note TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_original_trade RECORD;
  v_trade_exists BOOLEAN;
  v_is_participant BOOLEAN;
  v_counterparty_id UUID;
  v_new_trade_id UUID;
  v_requested_book RECORD;
  v_offered_book RECORD;
  v_interest_id UUID;
BEGIN
  -- Get the current user ID
  v_user_id := auth.uid();
  
  -- Check if user is authenticated
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  
  -- Check if original trade exists and user is a participant
  SELECT 
    EXISTS(SELECT 1 FROM trades WHERE id = p_original_trade_id) AS exists,
    t.*,
    (t.initiator_id = v_user_id OR t.recipient_id = v_user_id) AS is_participant
  INTO 
    v_trade_exists,
    v_original_trade,
    v_is_participant
  FROM trades t
  WHERE t.id = p_original_trade_id;
  
  IF NOT v_trade_exists OR NOT v_is_participant THEN
    RAISE EXCEPTION 'Trade not found or you are not a participant';
  END IF;
  
  -- Check if trade is in an appropriate status for counteroffering
  IF v_original_trade.status NOT IN ('request_pending', 'proposed') THEN
    RAISE EXCEPTION 'Cannot create counteroffer for a trade in its current status';
  END IF;
  
  -- Determine the counterparty
  IF v_user_id = v_original_trade.initiator_id THEN
    v_counterparty_id := v_original_trade.recipient_id;
  ELSE
    v_counterparty_id := v_original_trade.initiator_id;
  END IF;
  
  -- Reset books in the original trade
  UPDATE books
  SET status = 'available',
      current_trade_id = NULL
  WHERE current_trade_id = p_original_trade_id;
  
  -- Update the original trade to countered status
  UPDATE trades
  SET status = 'countered',
      last_modified_by = v_user_id
  WHERE id = p_original_trade_id;
  
  -- Create the new trade as a counteroffer
  INSERT INTO trades (
    initiator_id,
    recipient_id,
    status,
    completion_method,
    meeting_location,
    meeting_time,
    notes,
    trade_type,
    is_counteroffer,
    original_trade_id,
    last_modified_by
  ) VALUES (
    v_user_id,
    v_counterparty_id,
    'proposed',
    v_original_trade.completion_method,
    v_original_trade.meeting_location,
    v_original_trade.meeting_time,
    p_note,
    v_original_trade.trade_type,
    TRUE,
    p_original_trade_id,
    v_user_id
  )
  RETURNING id INTO v_new_trade_id;
  
  -- Add requested books to trade items
  FOR v_requested_book IN 
    SELECT id, user_id FROM books 
    WHERE id = ANY(p_requested_book_ids) 
  LOOP
    -- Check ownership
    IF v_requested_book.user_id != v_counterparty_id THEN
      RAISE EXCEPTION 'Book % does not belong to the counterparty', v_requested_book.id;
    END IF;
    
    -- Mark interest in the requested book
    SELECT mark_book_interest(v_requested_book.id) INTO v_interest_id;
    
    INSERT INTO trade_items (
      trade_id,
      book_id,
      owner_id,
      recipient_id,
      interest_id,
      item_type
    ) VALUES (
      v_new_trade_id,
      v_requested_book.id,
      v_requested_book.user_id,
      v_user_id,
      v_interest_id,
      'requested'
    );
    
    -- Update book status to trading
    UPDATE books
    SET status = 'trading',
        current_trade_id = v_new_trade_id
    WHERE id = v_requested_book.id;
  END LOOP;
  
  -- Add offered books to trade items
  FOR v_offered_book IN 
    SELECT id, user_id FROM books 
    WHERE id = ANY(p_offered_book_ids) 
  LOOP
    -- Check ownership
    IF v_offered_book.user_id != v_user_id THEN
      RAISE EXCEPTION 'Book % does not belong to you', v_offered_book.id;
    END IF;
    
    INSERT INTO trade_items (
      trade_id,
      book_id,
      owner_id,
      recipient_id,
      item_type
    ) VALUES (
      v_new_trade_id,
      v_offered_book.id,
      v_offered_book.user_id,
      v_counterparty_id,
      'offered'
    );
    
    -- Update book status to trading
    UPDATE books
    SET status = 'trading',
        current_trade_id = v_new_trade_id
    WHERE id = v_offered_book.id;
  END LOOP;
  
  -- Log actions in trade history for both trades
  -- For the original trade
  INSERT INTO trade_history (
    trade_id,
    action,
    actor_id,
    details
  ) VALUES (
    p_original_trade_id,
    'countered',
    v_user_id,
    jsonb_build_object(
      'new_trade_id', v_new_trade_id
    )
  );
  
  -- For the new counteroffer
  INSERT INTO trade_history (
    trade_id,
    action,
    actor_id,
    details
  ) VALUES (
    v_new_trade_id,
    'created',
    v_user_id,
    jsonb_build_object(
      'trade_type', 'counteroffer',
      'original_trade_id', p_original_trade_id,
      'requested_book_count', array_length(p_requested_book_ids, 1),
      'offered_book_count', array_length(p_offered_book_ids, 1)
    )
  );
  
  -- Create notification for counterparty
  INSERT INTO notifications (
    user_id,
    type,
    message,
    related_id,
    read
  ) VALUES (
    v_counterparty_id,
    'trade_countered',
    'You received a counteroffer for a trade',
    v_new_trade_id,
    false
  );
  
  RETURN v_new_trade_id;
END;
$$; 