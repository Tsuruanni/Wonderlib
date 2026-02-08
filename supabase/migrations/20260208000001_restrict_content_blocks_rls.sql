-- Restrict content_blocks RLS to teacher/admin roles only
-- Previously all authenticated users could CRUD content blocks

-- Drop the overly permissive policy
DROP POLICY IF EXISTS "content_blocks_manage_authenticated" ON content_blocks;

-- Allow all authenticated users to READ published content
CREATE POLICY "content_blocks_read_authenticated"
    ON content_blocks FOR SELECT
    TO authenticated
    USING (true);

-- Only teachers, heads, and admins can INSERT/UPDATE/DELETE
CREATE POLICY "content_blocks_manage_teachers"
    ON content_blocks FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.id = auth.uid()
            AND p.role IN ('teacher', 'head', 'admin')
        )
    );

CREATE POLICY "content_blocks_update_teachers"
    ON content_blocks FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.id = auth.uid()
            AND p.role IN ('teacher', 'head', 'admin')
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.id = auth.uid()
            AND p.role IN ('teacher', 'head', 'admin')
        )
    );

CREATE POLICY "content_blocks_delete_teachers"
    ON content_blocks FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.id = auth.uid()
            AND p.role IN ('teacher', 'head', 'admin')
        )
    );
