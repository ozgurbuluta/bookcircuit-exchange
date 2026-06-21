-- Mark book interest function
CREATE OR REPLACE FUNCTION mark_book_interest(
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
  v_interest_id UUID;
  v_book_exists BOOLEAN;
BEGIN
  -- Get the current user ID
  v_user_id := auth.uid();
  
  -- Check if user is authenticated
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  
  -- Check if book exists
  SELECT EXISTS(SELECT 1 FROM books WHERE id = p_book_id) INTO v_book_exists;
  
  IF NOT v_book_exists THEN
    RAISE EXCEPTION 'Book not found';
  END IF;
  
  -- Check if user already has interest in this book
  SELECT id INTO v_interest_id FROM book_interests 
  WHERE user_id = v_user_id AND book_id = p_book_id;
  
  -- If interest exists, update it
  IF v_interest_id IS NOT NULL THEN
    UPDATE book_interests
    SET note = COALESCE(p_note, note),
        status = 'active', -- Reactivate if it was fulfilled
        updated_at = NOW()
    WHERE id = v_interest_id;
  -- Otherwise, create a new interest record
  ELSE
    INSERT INTO book_interests (
      user_id,
      book_id,
      note,
      status
    ) VALUES (
      v_user_id,
      p_book_id,
      p_note,
      'active'
    )
    RETURNING id INTO v_interest_id;
  END IF;
  
  RETURN v_interest_id;
END;
$$;

-- Remove book interest function
CREATE OR REPLACE FUNCTION remove_book_interest(
  p_interest_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_exists BOOLEAN;
BEGIN
  -- Get the current user ID
  v_user_id := auth.uid();
  
  -- Check if user is authenticated
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  
  -- Verify interest exists and belongs to user
  SELECT EXISTS(
    SELECT 1 FROM book_interests
    WHERE id = p_interest_id AND user_id = v_user_id
  ) INTO v_exists;
  
  IF NOT v_exists THEN
    RAISE EXCEPTION 'Interest not found or does not belong to you';
  END IF;
  
  -- Delete the interest record
  DELETE FROM book_interests WHERE id = p_interest_id;
  
  RETURN TRUE;
END;
$$;

-- Get user interests function
CREATE OR REPLACE FUNCTION get_user_interests(
)
RETURNS TABLE (
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
    b.cover_img_url,
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