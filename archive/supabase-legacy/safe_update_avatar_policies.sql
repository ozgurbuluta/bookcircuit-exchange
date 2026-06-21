-- Safely create policy to allow authenticated users to upload their own avatar if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'objects' 
        AND schemaname = 'storage' 
        AND policyname = 'Users can upload their own avatar'
    ) THEN
        EXECUTE 'CREATE POLICY "Users can upload their own avatar" ON storage.objects
                FOR INSERT TO public
                WITH CHECK (
                  auth.uid() = (storage.foldername(name))[1]::uuid
                  AND bucket_id = ''avatars''
                )';
        RAISE NOTICE 'Created upload policy';
    ELSE
        RAISE NOTICE 'Upload policy already exists, skipping';
    END IF;
END
$$;

-- Safely create policy to allow users to update their own avatar if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'objects' 
        AND schemaname = 'storage' 
        AND policyname = 'Users can update their own avatar'
    ) THEN
        EXECUTE 'CREATE POLICY "Users can update their own avatar" ON storage.objects
                FOR UPDATE TO public
                USING (
                  auth.uid() = (storage.foldername(name))[1]::uuid
                  AND bucket_id = ''avatars''
                )';
        RAISE NOTICE 'Created update policy';
    ELSE
        RAISE NOTICE 'Update policy already exists, skipping';
    END IF;
END
$$;

-- Safely create policy to allow public to view avatars if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'objects' 
        AND schemaname = 'storage' 
        AND policyname = 'Avatars are publicly accessible'
    ) THEN
        EXECUTE 'CREATE POLICY "Avatars are publicly accessible" ON storage.objects
                FOR SELECT TO public
                USING (
                  bucket_id = ''avatars''
                )';
        RAISE NOTICE 'Created select policy';
    ELSE
        RAISE NOTICE 'Select policy already exists, skipping';
    END IF;
END
$$;

-- Safely create policy to allow users to delete their own avatar if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'objects' 
        AND schemaname = 'storage' 
        AND policyname = 'Users can delete their own avatar'
    ) THEN
        EXECUTE 'CREATE POLICY "Users can delete their own avatar" ON storage.objects
                FOR DELETE TO public
                USING (
                  auth.uid() = (storage.foldername(name))[1]::uuid
                  AND bucket_id = ''avatars''
                )';
        RAISE NOTICE 'Created delete policy';
    ELSE
        RAISE NOTICE 'Delete policy already exists, skipping';
    END IF;
END
$$; 