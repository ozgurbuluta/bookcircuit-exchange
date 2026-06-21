-- Migration to rename last_message_sender to last_message_sender_id in conversations table for clarity

-- Check if last_message_sender exists and last_message_sender_id does not exist
DO $$
BEGIN
    -- Check if the column needs to be renamed
    IF EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'conversations' 
        AND column_name = 'last_message_sender'
    ) AND NOT EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'conversations' 
        AND column_name = 'last_message_sender_id'
    ) THEN
        ALTER TABLE public.conversations 
        RENAME COLUMN last_message_sender TO last_message_sender_id;
    -- If the old column doesn't exist but new one also doesn't, create it
    ELSIF NOT EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'conversations' 
        AND column_name = 'last_message_sender_id'
    ) THEN
        ALTER TABLE public.conversations
        ADD COLUMN last_message_sender_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;
    END IF;
END
$$;

-- Also update the trigger function to use the new column name
CREATE OR REPLACE FUNCTION update_conversation_last_message()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE conversations
  SET 
    last_message = NEW.content,
    last_message_at = NEW.created_at,
    last_message_sender_id = NEW.user_id,
    updated_at = now()
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql; 