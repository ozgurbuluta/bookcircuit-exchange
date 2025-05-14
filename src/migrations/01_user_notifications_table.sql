-- Create user notifications table for the trading system
CREATE TABLE user_notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Related entities references (can be null depending on notification type)
  trade_id UUID REFERENCES trades(id) ON DELETE CASCADE,
  book_id UUID REFERENCES books(id) ON DELETE CASCADE,
  conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
  
  -- Additional contextual data
  user_id TEXT, -- ID of the user who triggered the notification
  user_name TEXT, -- Name of the user who triggered the notification
  user_avatar TEXT, -- Avatar of the user who triggered the notification
  book_title TEXT, -- Title of the book related to the notification
  book_author TEXT, -- Author of the book related to the notification
  book_cover_url TEXT, -- Cover URL of the book related to the notification
  book_condition TEXT -- Condition of the book related to the notification
);

-- Create index on user_id for faster lookups
CREATE INDEX user_notifications_user_id_idx ON user_notifications(user_id);

-- Create index on created_at for faster sorting
CREATE INDEX user_notifications_created_at_idx ON user_notifications(created_at);

-- Row Level Security
ALTER TABLE user_notifications ENABLE ROW LEVEL SECURITY;

-- RLS policies
CREATE POLICY user_notifications_select ON user_notifications 
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY user_notifications_delete ON user_notifications
  FOR DELETE USING (user_id = auth.uid()); 