-- Get user trades
CREATE OR REPLACE FUNCTION get_user_trades(
  p_status_filter TEXT DEFAULT NULL
)
RETURNS TABLE (
  trade_id UUID,
  initiator_id UUID,
  initiator_name TEXT,
  initiator_avatar TEXT,
  recipient_id UUID,
  recipient_name TEXT,
  recipient_avatar TEXT,
  status TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  completion_method TEXT,
  meeting_location TEXT,
  meeting_time TIMESTAMPTZ,
  notes TEXT,
  trade_type TEXT,
  is_counteroffer BOOLEAN,
  original_trade_id UUID,
  last_modified_by UUID,
  requested_books JSONB,
  offered_books JSONB,
  requested_count INT,
  offered_count INT,
  is_initiator BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- Get the current user ID
  v_user_id := auth.uid();
  
  -- Check if user is authenticated
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  
  RETURN QUERY
  WITH requested_items AS (
    SELECT 
      ti.trade_id,
      jsonb_agg(
        jsonb_build_object(
          'id', b.id,
          'title', b.title,
          'author', b.author,
          'cover_img_url', b.cover_img_url,
          'condition', b.condition,
          'owner_id', ti.owner_id,
          'recipient_id', ti.recipient_id
        )
      ) AS books,
      COUNT(*) AS count
    FROM trade_items ti
    JOIN books b ON ti.book_id = b.id
    WHERE ti.item_type = 'requested'
    GROUP BY ti.trade_id
  ),
  offered_items AS (
    SELECT 
      ti.trade_id,
      jsonb_agg(
        jsonb_build_object(
          'id', b.id,
          'title', b.title,
          'author', b.author,
          'cover_img_url', b.cover_img_url,
          'condition', b.condition,
          'owner_id', ti.owner_id,
          'recipient_id', ti.recipient_id
        )
      ) AS books,
      COUNT(*) AS count
    FROM trade_items ti
    JOIN books b ON ti.book_id = b.id
    WHERE ti.item_type = 'offered'
    GROUP BY ti.trade_id
  )
  SELECT
    t.id AS trade_id,
    t.initiator_id,
    p_init.full_name AS initiator_name,
    p_init.avatar_url AS initiator_avatar,
    t.recipient_id,
    p_recip.full_name AS recipient_name,
    p_recip.avatar_url AS recipient_avatar,
    t.status,
    t.created_at,
    t.updated_at,
    t.completion_method,
    t.meeting_location,
    t.meeting_time,
    t.notes,
    t.trade_type,
    t.is_counteroffer,
    t.original_trade_id,
    t.last_modified_by,
    COALESCE(ri.books, '[]'::jsonb) AS requested_books,
    COALESCE(oi.books, '[]'::jsonb) AS offered_books,
    COALESCE(ri.count, 0) AS requested_count,
    COALESCE(oi.count, 0) AS offered_count,
    t.initiator_id = v_user_id AS is_initiator
  FROM trades t
  LEFT JOIN profiles p_init ON t.initiator_id = p_init.id
  LEFT JOIN profiles p_recip ON t.recipient_id = p_recip.id
  LEFT JOIN requested_items ri ON t.id = ri.trade_id
  LEFT JOIN offered_items oi ON t.id = oi.trade_id
  WHERE (t.initiator_id = v_user_id OR t.recipient_id = v_user_id)
  AND (p_status_filter IS NULL OR t.status = p_status_filter)
  ORDER BY t.updated_at DESC;
END;
$$;

-- Get trade details
CREATE OR REPLACE FUNCTION get_trade_details(
  p_trade_id UUID
)
RETURNS TABLE (
  trade_id UUID,
  initiator_id UUID,
  initiator_name TEXT,
  initiator_avatar TEXT,
  recipient_id UUID,
  recipient_name TEXT,
  recipient_avatar TEXT,
  status TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  completion_method TEXT,
  meeting_location TEXT,
  meeting_time TIMESTAMPTZ,
  notes TEXT,
  trade_type TEXT,
  is_counteroffer BOOLEAN,
  original_trade_id UUID,
  last_modified_by UUID,
  requested_books JSONB,
  offered_books JSONB,
  history JSONB,
  is_initiator BOOLEAN,
  can_accept BOOLEAN,
  can_reject BOOLEAN,
  can_cancel BOOLEAN,
  can_complete BOOLEAN,
  can_counter BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_is_participant BOOLEAN;
  v_is_initiator BOOLEAN;
  v_is_recipient BOOLEAN;
  v_trade_status TEXT;
BEGIN
  -- Get the current user ID
  v_user_id := auth.uid();
  
  -- Check if user is authenticated
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  
  -- Check if trade exists and user is a participant
  SELECT 
    (initiator_id = v_user_id OR recipient_id = v_user_id) AS is_participant,
    initiator_id = v_user_id AS is_initiator,
    recipient_id = v_user_id AS is_recipient,
    status
  INTO 
    v_is_participant,
    v_is_initiator,
    v_is_recipient,
    v_trade_status
  FROM trades 
  WHERE id = p_trade_id;
  
  IF NOT v_is_participant THEN
    RAISE EXCEPTION 'Trade not found or you are not a participant';
  END IF;
  
  RETURN QUERY
  WITH requested_items AS (
    SELECT 
      ti.trade_id,
      jsonb_agg(
        jsonb_build_object(
          'id', b.id,
          'title', b.title,
          'author', b.author,
          'cover_img_url', b.cover_img_url,
          'condition', b.condition,
          'owner_id', ti.owner_id,
          'recipient_id', ti.recipient_id,
          'owner_name', p.full_name,
          'owner_avatar', p.avatar_url
        )
      ) AS books
    FROM trade_items ti
    JOIN books b ON ti.book_id = b.id
    JOIN profiles p ON ti.owner_id = p.id
    WHERE ti.trade_id = p_trade_id AND ti.item_type = 'requested'
    GROUP BY ti.trade_id
  ),
  offered_items AS (
    SELECT 
      ti.trade_id,
      jsonb_agg(
        jsonb_build_object(
          'id', b.id,
          'title', b.title,
          'author', b.author,
          'cover_img_url', b.cover_img_url,
          'condition', b.condition,
          'owner_id', ti.owner_id,
          'recipient_id', ti.recipient_id,
          'owner_name', p.full_name,
          'owner_avatar', p.avatar_url
        )
      ) AS books
    FROM trade_items ti
    JOIN books b ON ti.book_id = b.id
    JOIN profiles p ON ti.owner_id = p.id
    WHERE ti.trade_id = p_trade_id AND ti.item_type = 'offered'
    GROUP BY ti.trade_id
  ),
  history_items AS (
    SELECT 
      th.trade_id,
      jsonb_agg(
        jsonb_build_object(
          'id', th.id,
          'action', th.action,
          'actor_id', th.actor_id,
          'actor_name', p.full_name,
          'created_at', th.created_at,
          'details', th.details
        ) ORDER BY th.created_at
      ) AS history
    FROM trade_history th
    JOIN profiles p ON th.actor_id = p.id
    WHERE th.trade_id = p_trade_id
    GROUP BY th.trade_id
  )
  SELECT
    t.id AS trade_id,
    t.initiator_id,
    p_init.full_name AS initiator_name,
    p_init.avatar_url AS initiator_avatar,
    t.recipient_id,
    p_recip.full_name AS recipient_name,
    p_recip.avatar_url AS recipient_avatar,
    t.status,
    t.created_at,
    t.updated_at,
    t.completion_method,
    t.meeting_location,
    t.meeting_time,
    t.notes,
    t.trade_type,
    t.is_counteroffer,
    t.original_trade_id,
    t.last_modified_by,
    COALESCE(ri.books, '[]'::jsonb) AS requested_books,
    COALESCE(oi.books, '[]'::jsonb) AS offered_books,
    COALESCE(hi.history, '[]'::jsonb) AS history,
    v_is_initiator AS is_initiator,
    -- Permission flags
    (v_is_recipient AND t.status = 'proposed') AS can_accept,
    (v_is_recipient AND t.status = 'proposed') AS can_reject,
    ((v_is_initiator OR v_is_recipient) AND t.status IN ('request_pending', 'proposed', 'accepted')) AS can_cancel,
    ((v_is_initiator OR v_is_recipient) AND t.status = 'accepted') AS can_complete,
    ((v_is_initiator OR v_is_recipient) AND t.status IN ('request_pending', 'proposed')) AS can_counter
  FROM trades t
  LEFT JOIN profiles p_init ON t.initiator_id = p_init.id
  LEFT JOIN profiles p_recip ON t.recipient_id = p_recip.id
  LEFT JOIN requested_items ri ON t.id = ri.trade_id
  LEFT JOIN offered_items oi ON t.id = oi.trade_id
  LEFT JOIN history_items hi ON t.id = hi.trade_id
  WHERE t.id = p_trade_id;
END;
$$;

-- Get pending requests
CREATE OR REPLACE FUNCTION get_pending_requests()
RETURNS TABLE (
  trade_id UUID,
  requester_id UUID,
  requester_name TEXT,
  requester_avatar TEXT,
  created_at TIMESTAMPTZ,
  notes TEXT,
  book_id UUID,
  book_title TEXT,
  book_author TEXT,
  book_cover_url TEXT,
  book_condition TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- Get the current user ID
  v_user_id := auth.uid();
  
  -- Check if user is authenticated
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  
  RETURN QUERY
  SELECT
    t.id AS trade_id,
    t.initiator_id AS requester_id,
    p.full_name AS requester_name,
    p.avatar_url AS requester_avatar,
    t.created_at,
    t.notes,
    b.id AS book_id,
    b.title AS book_title,
    b.author AS book_author,
    b.cover_img_url AS book_cover_url,
    b.condition AS book_condition
  FROM trades t
  JOIN profiles p ON t.initiator_id = p.id
  JOIN trade_items ti ON t.id = ti.trade_id AND ti.item_type = 'requested'
  JOIN books b ON ti.book_id = b.id
  WHERE t.recipient_id = v_user_id
  AND t.status = 'request_pending'
  AND t.trade_type = 'direct_request'
  ORDER BY t.created_at DESC;
END;
$$;

-- Get available books for a specific user
CREATE OR REPLACE FUNCTION get_user_available_books(
  p_user_id UUID
)
RETURNS TABLE (
  book_id UUID,
  title TEXT,
  author TEXT,
  cover_img_url TEXT,
  condition TEXT,
  interested BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- Get the current user ID
  v_user_id := auth.uid();
  
  -- Check if user is authenticated
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  
  RETURN QUERY
  SELECT
    b.id AS book_id,
    b.title,
    b.author,
    b.cover_img_url,
    b.condition,
    EXISTS(
      SELECT 1 FROM book_interests
      WHERE book_id = b.id AND user_id = v_user_id
    ) AS interested
  FROM books b
  WHERE b.user_id = p_user_id
  AND b.status = 'available'
  ORDER BY interested DESC, b.title;
END;
$$; 