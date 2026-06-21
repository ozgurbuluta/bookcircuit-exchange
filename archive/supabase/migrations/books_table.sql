-- Create the books table
CREATE TABLE IF NOT EXISTS books (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  author TEXT,
  location_text TEXT NOT NULL,  -- Renamed from 'location' to avoid conflict
  condition TEXT NOT NULL,  -- e.g., 'New', 'Like New', 'Good', 'Fair', 'Poor'
  cover_img_url TEXT,
  isbn TEXT,  -- Optional ISBN for API lookups
  description TEXT,
  postal_code TEXT,
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  location GEOGRAPHY(POINT, 4326),  -- New geography column for spatial queries
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable PostGIS extension if not already enabled
CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA extensions;

-- Set up Row Level Security (RLS)
ALTER TABLE books ENABLE ROW LEVEL SECURITY;

-- Create policies
-- Anyone can view books
CREATE POLICY "Books are viewable by everyone"
  ON books
  FOR SELECT
  USING (true);

-- Users can only insert their own books
CREATE POLICY "Users can insert their own books"
  ON books
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can only update their own books
CREATE POLICY "Users can update their own books"
  ON books
  FOR UPDATE
  USING (auth.uid() = user_id);

-- Users can only delete their own books
CREATE POLICY "Users can delete their own books"
  ON books
  FOR DELETE
  USING (auth.uid() = user_id);

-- Create an index on user_id for faster queries
CREATE INDEX IF NOT EXISTS books_user_id_idx ON books(user_id);

-- Create a trigger to update the updated_at column
CREATE TRIGGER update_books_updated_at
BEFORE UPDATE ON books
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();