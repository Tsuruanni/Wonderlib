-- Create public storage bucket for avatar assets
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('avatars', 'avatars', true, 2097152)
ON CONFLICT (id) DO NOTHING;

-- Allow public read access
CREATE POLICY "avatars_public_read" ON storage.objects
    FOR SELECT TO public
    USING (bucket_id = 'avatars');

-- Allow authenticated users to read
CREATE POLICY "avatars_authenticated_read" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'avatars');
