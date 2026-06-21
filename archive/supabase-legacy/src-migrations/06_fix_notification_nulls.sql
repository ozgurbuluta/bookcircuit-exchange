-- Fix the notify_direct_request function to handle NULL values
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
  
  -- Default values if book not found
  IF v_book_id IS NULL THEN
    v_book_title := 'Unknown Book';
    v_book_author := 'Unknown Author';
    v_book_cover := NULL;
    v_book_condition := 'Unknown';
  ELSE
    -- Get book and user details
    SELECT 
      COALESCE(b.title, 'Unknown Book'),
      COALESCE(b.author, 'Unknown Author'),
      b.cover_img_url,
      COALESCE(b.condition, 'Unknown'),
      COALESCE(p.full_name, 'A User'),
      p.avatar_url
    INTO 
      v_book_title, 
      v_book_author, 
      v_book_cover, 
      v_book_condition, 
      v_user_name, 
      v_user_avatar
    FROM books b
    JOIN profiles p ON p.id = NEW.initiator_id
    WHERE b.id = v_book_id;
  END IF;
  
  -- Ensure we have valid user name even if the JOIN didn't work
  IF v_user_name IS NULL THEN
    SELECT COALESCE(full_name, 'A User') 
    INTO v_user_name 
    FROM profiles 
    WHERE id = NEW.initiator_id;
    
    -- If still null after direct query, use a default
    IF v_user_name IS NULL THEN
      v_user_name := 'A User';
    END IF;
  END IF;
  
  -- Ensure we have a notification title that's never NULL
  -- The notification title must be constructed with non-NULL values now
  
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
    v_user_name || ' requested your book', -- This is now guaranteed to be non-NULL
    COALESCE(NEW.notes, 'No message provided'),
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