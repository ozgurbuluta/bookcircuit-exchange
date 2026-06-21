-- Create direct book request function
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

COMMENT ON FUNCTION create_direct_request IS 'Creates a direct trade request for a book in an idempotent way, migrating legacy requests if found';

-- Respond to direct book request function
CREATE OR REPLACE FUNCTION respond_to_direct_request(
  p_trade_id UUID,
  p_offered_book_ids UUID[],
  p_note TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_initiator_id UUID;
  v_trade_status TEXT;
  v_trade_exists BOOLEAN;
  v_trade_type TEXT;
  v_book_record RECORD;
  v_offered_book RECORD;
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
    status,
    trade_type
  INTO 
    v_trade_exists,
    v_initiator_id,
    v_trade_status,
    v_trade_type
  FROM trades 
  WHERE id = p_trade_id AND recipient_id = v_user_id;
  
  IF NOT v_trade_exists THEN
    RAISE EXCEPTION 'Trade not found or you are not the recipient';
  END IF;
  
  -- Check if trade is in request_pending status
  IF v_trade_status != 'request_pending' THEN
    RAISE EXCEPTION 'Trade is not in pending status';
  END IF;
  
  -- Check if trade is a direct request
  IF v_trade_type != 'direct_request' THEN
    RAISE EXCEPTION 'Trade is not a direct request';
  END IF;
  
  -- Verify that offered books belong to the user and are available
  FOR v_offered_book IN 
    SELECT id, title, status FROM books 
    WHERE id = ANY(p_offered_book_ids) 
  LOOP
    -- Check ownership
    IF NOT EXISTS(
      SELECT 1 FROM books 
      WHERE id = v_offered_book.id AND user_id = v_user_id
    ) THEN
      RAISE EXCEPTION 'Book % does not belong to you', v_offered_book.id;
    END IF;
    
    -- Check availability
    IF v_offered_book.status != 'available' THEN
      RAISE EXCEPTION 'Book "%" is not available for trading', v_offered_book.title;
    END IF;
    
    -- Update book status to trading
    UPDATE books
    SET status = 'trading',
        current_trade_id = p_trade_id
    WHERE id = v_offered_book.id;
    
    -- Add book to trade items
    INSERT INTO trade_items (
      trade_id,
      book_id,
      owner_id,
      recipient_id,
      item_type
    ) VALUES (
      p_trade_id,
      v_offered_book.id,
      v_user_id,
      v_initiator_id,
      'offered'
    );
  END LOOP;
  
  -- Update the requested book status to trading
  UPDATE books b
  SET status = 'trading',
      current_trade_id = p_trade_id
  FROM trade_items ti
  WHERE ti.trade_id = p_trade_id
  AND ti.book_id = b.id
  AND ti.item_type = 'requested';
  
  -- Update the trade to proposed status
  UPDATE trades
  SET status = 'proposed',
      notes = CASE WHEN p_note IS NULL THEN notes ELSE p_note END,
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
    'proposed',
    v_user_id,
    jsonb_build_object(
      'offered_book_count', array_length(p_offered_book_ids, 1),
      'note', p_note
    )
  );
  
  -- Create notification for trade initiator
  INSERT INTO notifications (
    user_id,
    type,
    message,
    related_id,
    read
  ) VALUES (
    v_initiator_id,
    'trade_proposed',
    'Your book request has received a trade proposal',
    p_trade_id,
    false
  );
  
  RETURN TRUE;
END;
$$; 