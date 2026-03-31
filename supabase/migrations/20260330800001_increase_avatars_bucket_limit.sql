-- Increase avatars bucket file size limit from 2MB to 50MB
-- to support large tile theme images
UPDATE storage.buckets
SET file_size_limit = 52428800  -- 50MB
WHERE id = 'avatars';
