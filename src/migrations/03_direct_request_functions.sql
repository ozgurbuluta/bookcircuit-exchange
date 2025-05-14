-- Function to handle cleaning up old book_requests
CREATE OR REPLACE FUNCTION cleanup_book_requests(
  p_book_id UUID,
  p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSONB;
  v_found BOOLEAN := false;
  v_current_user_id UUID := auth.uid();
BEGIN
  -- Check if user is authenticated
  IF v_current_user_id IS NULL THEN
    RAISE EXCEPTION 'User must be authenticated';
  END IF;

  -- Ensure the user ID matches the authenticated user
  IF v_current_user_id != p_user_id THEN
    RAISE EXCEPTION 'Unauthorized action';
  END IF;

  -- Check if any book_requests exist for this book and user
  SELECT EXISTS(
    SELECT 1 
    FROM book_requests 
    WHERE book_id = p_book_id AND requester_id = p_user_id
  ) INTO v_found;

  -- If found, delete them
  IF v_found THEN
    DELETE FROM book_requests
    WHERE book_id = p_book_id AND requester_id = p_user_id;
    
    v_result := jsonb_build_object(
      'success', true,
      'message', 'Legacy book requests cleaned up successfully',
      'records_deleted', true
    );
  ELSE
    v_result := jsonb_build_object(
      'success', true,
      'message', 'No legacy book requests found to clean up',
      'records_deleted', false
    );
  END IF;

  RETURN v_result;
END;
$$;

COMMENT ON FUNCTION cleanup_book_requests IS 'Clean up legacy book_requests records for a book and user'; 