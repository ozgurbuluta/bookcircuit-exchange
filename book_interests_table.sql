-- Create book_interests table to track user interest in books
CREATE TABLE IF NOT EXISTS public.book_interests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  book_id UUID REFERENCES public.books(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  note TEXT,
  notification_sent BOOLEAN DEFAULT false NOT NULL,
  status VARCHAR(20) DEFAULT 'active' NOT NULL,
  
  -- Ensure a user can only mark interest in a book once
  CONSTRAINT unique_book_interest UNIQUE (book_id, user_id)
);

-- Enable RLS on book_interests
ALTER TABLE public.book_interests ENABLE ROW LEVEL SECURITY;

-- Create policies for book_interests

-- Users can view their own interests
CREATE POLICY "Users can view their own interests"
ON public.book_interests
FOR SELECT
USING (
  user_id = auth.uid()
);

-- Users can view interests in their books
CREATE POLICY "Users can view interests in their books"
ON public.book_interests
FOR SELECT
USING (
  book_id IN (
    SELECT id FROM public.books WHERE user_id = auth.uid()
  )
);

-- Users can insert their own interests
CREATE POLICY "Users can insert their own interests"
ON public.book_interests
FOR INSERT
WITH CHECK (
  user_id = auth.uid()
);

-- Users can update their own interests
CREATE POLICY "Users can update their own interests"
ON public.book_interests
FOR UPDATE
USING (
  user_id = auth.uid()
);

-- Users can delete their own interests
CREATE POLICY "Users can delete their own interests"
ON public.book_interests
FOR DELETE
USING (
  user_id = auth.uid()
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS book_interests_user_id_idx ON public.book_interests(user_id);
CREATE INDEX IF NOT EXISTS book_interests_book_id_idx ON public.book_interests(book_id);
CREATE INDEX IF NOT EXISTS book_interests_status_idx ON public.book_interests(status);

-- Create trigger to create notification when interest is added
CREATE OR REPLACE FUNCTION notify_book_owner_of_interest()
RETURNS TRIGGER AS $$
DECLARE
  owner_id UUID;
  book_title TEXT;
BEGIN
  -- Get the book's owner ID and title
  SELECT books.user_id, books.title INTO owner_id, book_title
  FROM public.books
  WHERE id = NEW.book_id;

  -- Don't create notification if user is marking interest in their own book
  IF owner_id = NEW.user_id THEN
    RETURN NEW;
  END IF;

  -- Create notification for book owner
  INSERT INTO public.notifications (
    user_id,
    type,
    message,
    related_id,
    read
  ) VALUES (
    owner_id,
    'book_interest',
    'Someone is interested in your book "' || book_title || '"',
    NEW.book_id,
    false
  );

  -- Mark notification as sent
  NEW.notification_sent = true;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER book_interest_notification_trigger
BEFORE INSERT ON public.book_interests
FOR EACH ROW
EXECUTE FUNCTION notify_book_owner_of_interest(); 