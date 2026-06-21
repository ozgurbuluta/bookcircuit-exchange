-- Fix the notify_direct_request function to use the correct column name
CREATE OR REPLACE FUNCTION notify_direct_request()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_book_title TEXT;
  v_user_name TEXT;
  v_user_avatar TEXT;
  v_book_author TEXT;
  v_book_cover TEXT;
  v_book_condition TEXT;
  v_book_id UUID;
BEGIN
  -- Get the first trade item for this trade
  SELECT book_id INTO v_book_id
  FROM trade_items
  WHERE trade_id = NEW.id AND item_type = 'requested'
  LIMIT 1;
  
  -- Get book and user details - Fix: Changed b.cover_url to b.cover_img_url
  SELECT b.title, b.author, b.cover_img_url, b.condition, p.full_name, p.avatar_url 
  INTO v_book_title, v_book_author, v_book_cover, v_book_condition, v_user_name, v_user_avatar
  FROM books b
  JOIN profiles p ON p.id = NEW.initiator_id
  WHERE b.id = v_book_id;
  
  -- Insert notification for book owner
  INSERT INTO user_notifications (
    user_id,
    type,
    title,
    description,
    trade_id,
    book_id,
    source_user_id,
    user_name,
    user_avatar,
    book_title,
    book_author,
    book_cover_url,
    book_condition
  ) VALUES (
    NEW.recipient_id,
    'direct_request',
    v_user_name || ' requested your book',
    COALESCE(NEW.notes, ''),
    NEW.id,
    v_book_id,
    NEW.initiator_id::TEXT,
    v_user_name,
    v_user_avatar,
    v_book_title,
    v_book_author,
    v_book_cover,
    v_book_condition
  );
  
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION notify_direct_request IS 'Trigger function to send notifications for direct book requests';

-- Fix the get_user_interests function to use the correct column name
CREATE OR REPLACE FUNCTION get_user_interests()
RETURNS TABLE(
  interest_id UUID,
  book_id UUID,
  title TEXT,
  author TEXT,
  cover_img_url TEXT,
  condition TEXT,
  owner_id UUID,
  owner_name TEXT,
  owner_avatar TEXT,
  note TEXT,
  status TEXT,
  created_at TIMESTAMPTZ
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
    bi.id AS interest_id,
    b.id AS book_id,
    b.title,
    b.author,
    b.cover_img_url, -- Fixed: Using correct column name directly
    b.condition,
    b.user_id AS owner_id,
    p.full_name AS owner_name,
    p.avatar_url AS owner_avatar,
    bi.note,
    bi.status,
    bi.created_at
  FROM book_interests bi
  JOIN books b ON bi.book_id = b.id
  JOIN profiles p ON b.user_id = p.id
  WHERE bi.user_id = v_user_id
  ORDER BY bi.created_at DESC;
END;
$$;

COMMENT ON FUNCTION get_user_interests IS 'Get all book interests for the current user'; 