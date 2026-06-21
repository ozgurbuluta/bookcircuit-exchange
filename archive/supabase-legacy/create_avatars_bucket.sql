-- Create the avatars bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true);

-- Create policy to allow authenticated users to upload their own avatar
CREATE POLICY "Users can upload their own avatar" ON storage.objects
FOR INSERT WITH CHECK (
  auth.uid() = (storage.foldername(name))[1]::uuid
  AND bucket_id = 'avatars'
);

-- Create policy to allow public to view avatars
CREATE POLICY "Avatars are publicly accessible" ON storage.objects
FOR SELECT USING (
  bucket_id = 'avatars'
);

-- Create policy to allow users to update their own avatar
CREATE POLICY "Users can update their own avatar" ON storage.objects
FOR UPDATE WITH CHECK (
  auth.uid() = (storage.foldername(name))[1]::uuid
  AND bucket_id = 'avatars'
);

-- Create policy to allow users to delete their own avatar
CREATE POLICY "Users can delete their own avatar" ON storage.objects
FOR DELETE USING (
  auth.uid() = (storage.foldername(name))[1]::uuid
  AND bucket_id = 'avatars'
); 