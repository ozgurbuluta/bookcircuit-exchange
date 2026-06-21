-- Migration to create the get_user_email function for chat displays
-- This function securely retrieves a user's email from auth.users

-- Drop any previous versions of the function for clean installation
DROP FUNCTION IF EXISTS get_user_details(uuid);
DROP FUNCTION IF EXISTS get_user_email(uuid);

-- Create function to securely get user email from auth schema
CREATE OR REPLACE FUNCTION get_user_email(user_id_input uuid)
RETURNS TABLE (email text) -- Only returns email
LANGUAGE sql
SECURITY DEFINER -- Allows the function to access auth.users with elevated privileges
SET search_path = public -- Security: prevents search_path injection
AS $$
  SELECT
    u.email
  FROM auth.users u
  WHERE u.id = user_id_input;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_user_email(uuid) TO authenticated;

-- Revoke from public for extra security (optional)
REVOKE EXECUTE ON FUNCTION get_user_email(uuid) FROM public; 