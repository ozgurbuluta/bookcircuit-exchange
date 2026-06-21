-- Create the blog_posts table
CREATE TABLE IF NOT EXISTS blog_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  summary TEXT NOT NULL,
  content TEXT NOT NULL,
  featured_image_url TEXT,
  author TEXT NOT NULL,
  author_id UUID REFERENCES auth.users(id),
  published_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create an index on slug for faster lookups
CREATE INDEX IF NOT EXISTS blog_posts_slug_idx ON blog_posts(slug);

-- Create an index on published_at for sorting
CREATE INDEX IF NOT EXISTS blog_posts_published_at_idx ON blog_posts(published_at);

-- Set up Row Level Security (RLS)
ALTER TABLE blog_posts ENABLE ROW LEVEL SECURITY;

-- Create policies
-- Anyone can view published blog posts
CREATE POLICY "Blog posts are viewable by everyone"
  ON blog_posts
  FOR SELECT
  USING (true);

-- Only authenticated users with specific permissions can insert blog posts
CREATE POLICY "Only admins can insert blog posts"
  ON blog_posts
  FOR INSERT
  WITH CHECK (
    auth.uid() IN (
      SELECT id FROM auth.users 
      WHERE id = auth.uid() AND raw_user_meta_data->>'is_admin' = 'true'
    )
  );

-- Only authenticated users with specific permissions can update blog posts
CREATE POLICY "Only admins can update blog posts"
  ON blog_posts
  FOR UPDATE
  USING (
    auth.uid() IN (
      SELECT id FROM auth.users 
      WHERE id = auth.uid() AND raw_user_meta_data->>'is_admin' = 'true'
    )
  );

-- Only authenticated users with specific permissions can delete blog posts
CREATE POLICY "Only admins can delete blog posts"
  ON blog_posts
  FOR DELETE
  USING (
    auth.uid() IN (
      SELECT id FROM auth.users 
      WHERE id = auth.uid() AND raw_user_meta_data->>'is_admin' = 'true'
    )
  );

-- Create a trigger to update the updated_at column
CREATE OR REPLACE FUNCTION update_blog_posts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_blog_posts_updated_at
BEFORE UPDATE ON blog_posts
FOR EACH ROW
EXECUTE FUNCTION update_blog_posts_updated_at();

-- Create storage bucket for blog images if not exists
INSERT INTO storage.buckets (id, name, public, avif_autodetection)
VALUES ('blog-images', 'blog-images', true, false)
ON CONFLICT (id) DO NOTHING;

-- Set up RLS for blog images storage
CREATE POLICY "Blog images are viewable by everyone"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'blog-images');

CREATE POLICY "Only admins can insert blog images"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'blog-images' AND
    auth.uid() IN (
      SELECT id FROM auth.users 
      WHERE id = auth.uid() AND raw_user_meta_data->>'is_admin' = 'true'
    )
  );

CREATE POLICY "Only admins can update blog images"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'blog-images' AND
    auth.uid() IN (
      SELECT id FROM auth.users 
      WHERE id = auth.uid() AND raw_user_meta_data->>'is_admin' = 'true'
    )
  );

CREATE POLICY "Only admins can delete blog images"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'blog-images' AND
    auth.uid() IN (
      SELECT id FROM auth.users 
      WHERE id = auth.uid() AND raw_user_meta_data->>'is_admin' = 'true'
    )
  ); 