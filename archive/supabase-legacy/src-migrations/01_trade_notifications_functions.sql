-- Create notifications functions for trading system

-- Function to get user notifications related to trading
CREATE OR REPLACE FUNCTION get_user_trade_notifications(
  p_limit INT DEFAULT 20
) RETURNS SETOF user_notifications AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM user_notifications
  WHERE user_id = auth.uid()
  AND (
    type = 'new_trade' OR
    type = 'trade_accepted' OR
    type = 'trade_rejected' OR
    type = 'trade_completed' OR
    type = 'direct_request' OR
    type = 'interest_marked'
  )
  ORDER BY created_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to mark notifications as read
CREATE OR REPLACE FUNCTION mark_notifications_as_read(
  p_notification_ids UUID[]
) RETURNS void AS $$
BEGIN
  UPDATE user_notifications
  SET read = true
  WHERE id = ANY(p_notification_ids)
  AND user_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to clear user notifications
CREATE OR REPLACE FUNCTION clear_user_notifications() RETURNS void AS $$
BEGIN
  DELETE FROM user_notifications
  WHERE user_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a function to send notification about a new direct book request
CREATE OR REPLACE FUNCTION notify_direct_request() RETURNS TRIGGER AS $$
DECLARE
  v_book_title TEXT;
  v_user_name TEXT;
  v_user_avatar TEXT;
  v_book_author TEXT;
  v_book_cover TEXT;
  v_book_condition TEXT;
BEGIN
  -- Get book and user details
  SELECT b.title, b.author, b.cover_url, b.condition, p.full_name, p.avatar_url 
  INTO v_book_title, v_book_author, v_book_cover, v_book_condition, v_user_name, v_user_avatar
  FROM books b
  JOIN profiles p ON p.id = NEW.initiator_id
  WHERE b.id = NEW.trade_items[1].book_id;
  
  -- Insert notification for book owner
  INSERT INTO user_notifications (
    user_id,
    type,
    title,
    description,
    trade_id,
    book_id,
    user_id,
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
    COALESCE(NEW.initiator_message, ''),
    NEW.id,
    NEW.trade_items[1].book_id,
    NEW.initiator_id,
    v_user_name,
    v_user_avatar,
    v_book_title,
    v_book_author,
    v_book_cover,
    v_book_condition
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for direct book requests
CREATE TRIGGER trigger_notify_direct_request
AFTER INSERT ON trades
FOR EACH ROW 
WHEN (NEW.is_direct_request = true)
EXECUTE FUNCTION notify_direct_request();

-- Create a function to send notification about trade status changes
CREATE OR REPLACE FUNCTION notify_trade_status_change() RETURNS TRIGGER AS $$
DECLARE
  v_title TEXT;
  v_description TEXT;
  v_notification_type TEXT;
  v_target_user_id UUID;
  v_actor_name TEXT;
BEGIN
  -- Get actor name
  SELECT full_name INTO v_actor_name FROM profiles WHERE id = auth.uid();
  
  -- Determine notification type and target user
  IF NEW.status = 'pending' AND OLD.status IS NULL THEN
    -- New trade created (except for direct requests which have their own trigger)
    IF NEW.is_direct_request = false THEN
      v_notification_type := 'new_trade';
      v_title := v_actor_name || ' proposed a new trade';
      v_description := COALESCE(NEW.initiator_message, 'No message provided');
      v_target_user_id := NEW.recipient_id;
    ELSE
      -- Skip direct requests as they are handled by another trigger
      RETURN NEW;
    END IF;
  ELSIF NEW.status = 'accepted' AND OLD.status = 'pending' THEN
    v_notification_type := 'trade_accepted';
    v_title := v_actor_name || ' accepted your trade proposal';
    v_description := COALESCE(NEW.recipient_message, 'No message provided');
    v_target_user_id := NEW.initiator_id;
  ELSIF NEW.status = 'rejected' AND OLD.status = 'pending' THEN
    v_notification_type := 'trade_rejected';
    v_title := v_actor_name || ' rejected your trade proposal';
    v_description := COALESCE(NEW.recipient_message, 'No message provided');
    v_target_user_id := NEW.initiator_id;
  ELSIF NEW.status = 'completed' AND OLD.status = 'accepted' THEN
    v_notification_type := 'trade_completed';
    v_title := 'Trade completed';
    v_description := 'Your trade has been marked as completed';
    
    -- Notify both users
    -- First, notify the initiator if the recipient completed it
    IF auth.uid() = NEW.recipient_id THEN
      v_target_user_id := NEW.initiator_id;
      
      INSERT INTO user_notifications (
        user_id,
        type,
        title,
        description,
        trade_id
      ) VALUES (
        v_target_user_id,
        v_notification_type,
        v_title,
        v_description,
        NEW.id
      );
    END IF;
    
    -- Then, notify the recipient if the initiator completed it
    IF auth.uid() = NEW.initiator_id THEN
      v_target_user_id := NEW.recipient_id;
    ELSE
      -- Skip inserting twice if we already notified
      RETURN NEW;
    END IF;
  ELSIF NEW.status = 'cancelled' AND OLD.status = 'pending' THEN
    v_notification_type := 'trade_cancelled';
    v_title := v_actor_name || ' cancelled the trade proposal';
    v_description := COALESCE(NEW.initiator_message, 'No message provided');
    v_target_user_id := NEW.recipient_id;
  ELSE
    -- Skip other status changes
    RETURN NEW;
  END IF;
  
  -- Insert notification
  INSERT INTO user_notifications (
    user_id,
    type,
    title,
    description,
    trade_id
  ) VALUES (
    v_target_user_id,
    v_notification_type,
    v_title,
    v_description,
    NEW.id
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for trade status changes
CREATE TRIGGER trigger_notify_trade_status_change
AFTER UPDATE ON trades
FOR EACH ROW 
WHEN (NEW.status IS DISTINCT FROM OLD.status)
EXECUTE FUNCTION notify_trade_status_change();

-- Create a function to send notification about book interest
CREATE OR REPLACE FUNCTION notify_book_interest() RETURNS TRIGGER AS $$
DECLARE
  v_book_title TEXT;
  v_user_name TEXT;
  v_book_owner_id UUID;
BEGIN
  -- Get book title and owner
  SELECT b.title, b.user_id, p.full_name 
  INTO v_book_title, v_book_owner_id, v_user_name
  FROM books b
  JOIN profiles p ON p.id = NEW.user_id
  WHERE b.id = NEW.book_id;
  
  -- Insert notification for book owner
  INSERT INTO user_notifications (
    user_id,
    type,
    title,
    description,
    book_id,
    user_id,
    user_name
  ) VALUES (
    v_book_owner_id,
    'interest_marked',
    v_user_name || ' is interested in your book',
    'Someone marked interest in your book "' || v_book_title || '"',
    NEW.book_id,
    NEW.user_id,
    v_user_name
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for book interest
CREATE TRIGGER trigger_notify_book_interest
AFTER INSERT ON book_interests
FOR EACH ROW 
EXECUTE FUNCTION notify_book_interest(); 