-- Drop existing policies if they exist
DO $$
BEGIN
    BEGIN
        EXECUTE 'DROP POLICY IF EXISTS "Users can upload their own avatar" ON storage.objects';
        RAISE NOTICE 'Dropped upload policy';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Error dropping upload policy: %', SQLERRM;
    END;

    BEGIN
        EXECUTE 'DROP POLICY IF EXISTS "Users can update their own avatar" ON storage.objects';
        RAISE NOTICE 'Dropped update policy';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Error dropping update policy: %', SQLERRM;
    END;

    BEGIN
        EXECUTE 'DROP POLICY IF EXISTS "Avatars are publicly accessible" ON storage.objects';
        RAISE NOTICE 'Dropped select policy';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Error dropping select policy: %', SQLERRM;
    END;

    BEGIN
        EXECUTE 'DROP POLICY IF EXISTS "Users can delete their own avatar" ON storage.objects';
        RAISE NOTICE 'Dropped delete policy';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Error dropping delete policy: %', SQLERRM;
    END;
END
$$;

-- Create new policies
-- Create policy to allow authenticated users to upload their own avatar
CREATE POLICY "Users can upload their own avatar" ON storage.objects
FOR INSERT TO public
WITH CHECK (
  auth.uid() = (storage.foldername(name))[1]::uuid
  AND bucket_id = 'avatars'
);

-- Create policy to allow users to update their own avatar
CREATE POLICY "Users can update their own avatar" ON storage.objects
FOR UPDATE TO public
USING (
  auth.uid() = (storage.foldername(name))[1]::uuid
  AND bucket_id = 'avatars'
);

-- Create policy to allow public to view avatars
CREATE POLICY "Avatars are publicly accessible" ON storage.objects
FOR SELECT TO public
USING (
  bucket_id = 'avatars'
);

-- Create policy to allow users to delete their own avatar
CREATE POLICY "Users can delete their own avatar" ON storage.objects
FOR DELETE TO public
USING (
  auth.uid() = (storage.foldername(name))[1]::uuid
  AND bucket_id = 'avatars'
); 