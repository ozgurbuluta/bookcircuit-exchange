-- Create book_requests table to track book requests
CREATE TABLE IF NOT EXISTS public.book_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  book_id UUID REFERENCES public.books(id) ON DELETE CASCADE NOT NULL,
  requester_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'pending',
  message TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  
  -- Ensure a user can only request a book once
  CONSTRAINT unique_book_request UNIQUE (book_id, requester_id)
);

-- Enable RLS on book_requests
ALTER TABLE public.book_requests ENABLE ROW LEVEL SECURITY;

-- Create notifications table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  type VARCHAR(50) NOT NULL,
  message TEXT NOT NULL,
  related_id UUID,
  read BOOLEAN DEFAULT false NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Enable RLS on notifications
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Create trigger to update updated_at on book_requests
CREATE OR REPLACE FUNCTION update_book_request_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_book_request_updated_at ON book_requests;
CREATE TRIGGER trigger_update_book_request_updated_at
BEFORE UPDATE ON book_requests
FOR EACH ROW
EXECUTE FUNCTION update_book_request_updated_at();

-- RLS Policies for book_requests

-- Users can view their own book requests (either as requester or owner)
CREATE POLICY "Users can view their own book requests"
ON public.book_requests
FOR SELECT
USING (
  requester_id = auth.uid() OR owner_id = auth.uid()
);

-- Users can insert their own book requests
CREATE POLICY "Users can insert their own book requests"
ON public.book_requests
FOR INSERT
WITH CHECK (
  requester_id = auth.uid()
);

-- Users can update their own book requests
CREATE POLICY "Users can update their own book requests"
ON public.book_requests
FOR UPDATE
USING (
  requester_id = auth.uid() OR owner_id = auth.uid()
);

-- RLS Policies for notifications

-- Users can view their own notifications
CREATE POLICY "Users can view their own notifications"
ON public.notifications
FOR SELECT
USING (
  user_id = auth.uid()
);

-- Users can update their own notifications (to mark as read)
CREATE POLICY "Users can update their own notifications"
ON public.notifications
FOR UPDATE
USING (
  user_id = auth.uid()
);

-- Update seed data for testing if needed
-- INSERT INTO public.book_requests (book_id, requester_id, owner_id, status)
-- SELECT 
--   b.id, 
--   (SELECT id FROM auth.users WHERE email != u.email LIMIT 1), 
--   b.user_id, 
--   'pending'
-- FROM public.books b
-- JOIN auth.users u ON b.user_id = u.id
-- LIMIT 5; 