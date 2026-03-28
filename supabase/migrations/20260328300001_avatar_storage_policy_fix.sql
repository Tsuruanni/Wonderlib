-- =============================================
-- FIX: Restrict avatars storage bucket to admins only
-- Previously any authenticated user (including students) could
-- upload/update files in the avatars bucket.
-- =============================================

-- Drop overly permissive policies
DROP POLICY IF EXISTS "avatars_authenticated_insert" ON storage.objects;
DROP POLICY IF EXISTS "avatars_authenticated_update" ON storage.objects;

-- Recreate with admin-only access using can_manage_content()
CREATE POLICY "avatars_admin_insert" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'avatars' AND can_manage_content());

CREATE POLICY "avatars_admin_update" ON storage.objects
    FOR UPDATE TO authenticated
    USING (bucket_id = 'avatars' AND can_manage_content());
