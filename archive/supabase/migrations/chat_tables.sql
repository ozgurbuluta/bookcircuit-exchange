-- Create tables for chat functionality
-- Tables needed: conversations, messages, conversation_participants

-- Create conversations table
CREATE TABLE IF NOT EXISTS public.conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  last_message TEXT,
  last_message_at TIMESTAMPTZ DEFAULT now(),
  last_message_sender UUID REFERENCES auth.users(id),
  book_id UUID REFERENCES public.books(id) ON DELETE SET NULL
);

-- Enable RLS on conversations
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

-- Create messages table
CREATE TABLE IF NOT EXISTS public.messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID REFERENCES public.conversations(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now(),
  is_edited BOOLEAN DEFAULT false,
  attachments JSONB
);

-- Enable RLS on messages
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Create conversation_participants table
CREATE TABLE IF NOT EXISTS public.conversation_participants (
  conversation_id UUID REFERENCES public.conversations(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  joined_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  last_read_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (conversation_id, user_id)
);

-- Enable RLS on conversation_participants
ALTER TABLE public.conversation_participants ENABLE ROW LEVEL SECURITY;

-- Create function to start a conversation
CREATE OR REPLACE FUNCTION public.start_conversation(
  other_user_id UUID,
  initial_message TEXT DEFAULT NULL,
  book_id UUID DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  conversation_id UUID;
  current_user_id UUID := auth.uid();
BEGIN
  -- Check if a conversation exists between these users for this book (if book_id is provided)
  IF book_id IS NOT NULL THEN
    SELECT c.id INTO conversation_id
    FROM conversations c
    JOIN conversation_participants cp1 ON c.id = cp1.conversation_id
    JOIN conversation_participants cp2 ON c.id = cp2.conversation_id
    WHERE cp1.user_id = current_user_id
    AND cp2.user_id = other_user_id
    AND c.book_id = start_conversation.book_id
    LIMIT 1;
  END IF;
  
  -- If no book-specific conversation exists, check if any conversation exists between these users
  IF conversation_id IS NULL THEN
    SELECT c.id INTO conversation_id
    FROM conversations c
    JOIN conversation_participants cp1 ON c.id = cp1.conversation_id
    JOIN conversation_participants cp2 ON c.id = cp2.conversation_id
    WHERE cp1.user_id = current_user_id
    AND cp2.user_id = other_user_id
    LIMIT 1;
  END IF;
  
  -- If no conversation exists, create a new one
  IF conversation_id IS NULL THEN
    -- Insert new conversation
    INSERT INTO conversations (book_id)
    VALUES (start_conversation.book_id)
    RETURNING id INTO conversation_id;
    
    -- Add participants
    INSERT INTO conversation_participants (conversation_id, user_id)
    VALUES (conversation_id, current_user_id),
           (conversation_id, other_user_id);
  END IF;
  
  -- If an initial message was provided, add it
  IF initial_message IS NOT NULL AND initial_message <> '' THEN
    INSERT INTO messages (conversation_id, user_id, content)
    VALUES (conversation_id, current_user_id, initial_message);
  END IF;
  
  RETURN conversation_id;
END;
$$;

-- Create trigger to update last_message and last_message_at in conversations
CREATE OR REPLACE FUNCTION update_conversation_last_message()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE conversations
  SET 
    last_message = NEW.content,
    last_message_at = NEW.created_at,
    last_message_sender = NEW.user_id,
    updated_at = now()
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add trigger to messages table
DROP TRIGGER IF EXISTS trigger_update_conversation_last_message ON messages;
CREATE TRIGGER trigger_update_conversation_last_message
AFTER INSERT ON messages
FOR EACH ROW
EXECUTE FUNCTION update_conversation_last_message();

-- RLS Policies

-- Conversations: Users can only access conversations they're participants in
CREATE POLICY "Users can view their own conversations"
ON public.conversations
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM conversation_participants
    WHERE conversation_id = id
    AND user_id = auth.uid()
  )
);

-- Messages: Users can only access messages from conversations they're in
CREATE POLICY "Users can view messages in their conversations"
ON public.messages
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM conversation_participants
    WHERE conversation_id = messages.conversation_id
    AND user_id = auth.uid()
  )
);

CREATE POLICY "Users can insert messages in their conversations"
ON public.messages
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM conversation_participants
    WHERE conversation_id = messages.conversation_id
    AND user_id = auth.uid()
  )
  AND user_id = auth.uid()
);

CREATE POLICY "Users can update their own messages"
ON public.messages
FOR UPDATE
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Conversation Participants: Users can see who is in their conversations
CREATE POLICY "Users can view participants in their conversations"
ON public.conversation_participants
FOR SELECT
USING (
  user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM conversation_participants
    WHERE conversation_id = conversation_participants.conversation_id
    AND user_id = auth.uid()
  )
);

CREATE POLICY "Users can update their own participant status"
ON public.conversation_participants
FOR UPDATE
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid()); 