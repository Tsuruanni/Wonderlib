-- Allow authenticated users to upload to avatars bucket
CREATE POLICY "avatars_authenticated_insert" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'avatars');

-- Allow authenticated users to update (upsert) in avatars bucket
CREATE POLICY "avatars_authenticated_update" ON storage.objects
    FOR UPDATE TO authenticated
    USING (bucket_id = 'avatars');
