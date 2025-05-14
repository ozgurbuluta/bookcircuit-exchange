-- Fix the mark_book_interest function by removing the non-existent updated_at column reference
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
  
  -- If interest exists, update it - Fix: removed updated_at = NOW()
  IF v_interest_id IS NOT NULL THEN
    UPDATE book_interests
    SET note = COALESCE(p_note, note),
        status = 'active' -- Reactivate if it was fulfilled
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

COMMENT ON FUNCTION mark_book_interest IS 'Mark a user''s interest in a book or update an existing interest'; 