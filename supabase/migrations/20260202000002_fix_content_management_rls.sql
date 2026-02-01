-- Fix RLS policies for content management
-- Allow teachers to manage books, chapters, activities, and content_blocks
-- Previously only 'admin' role could manage content, now 'teacher' can too

-- =============================================
-- UPDATE HELPER FUNCTION
-- =============================================
-- Add function to check if user can manage content (teacher or admin)
CREATE OR REPLACE FUNCTION can_manage_content()
RETURNS BOOLEAN AS $$
    SELECT EXISTS(
        SELECT 1 FROM profiles
        WHERE id = auth.uid()
        AND role IN ('teacher', 'head', 'admin')
    );
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- =============================================
-- BOOKS POLICIES
-- =============================================
DROP POLICY IF EXISTS "Admins can manage all books" ON books;

CREATE POLICY "Teachers and admins can manage all books"
    ON books FOR ALL
    TO authenticated
    USING (can_manage_content())
    WITH CHECK (can_manage_content());

-- =============================================
-- CHAPTERS POLICIES
-- =============================================
DROP POLICY IF EXISTS "Admins can manage chapters" ON chapters;

CREATE POLICY "Teachers and admins can manage chapters"
    ON chapters FOR ALL
    TO authenticated
    USING (can_manage_content())
    WITH CHECK (can_manage_content());

-- =============================================
-- ACTIVITIES POLICIES
-- =============================================
DROP POLICY IF EXISTS "Admins can manage activities" ON activities;

CREATE POLICY "Teachers and admins can manage activities"
    ON activities FOR ALL
    TO authenticated
    USING (can_manage_content())
    WITH CHECK (can_manage_content());

-- =============================================
-- INLINE ACTIVITIES POLICIES
-- =============================================
DROP POLICY IF EXISTS "Admins can manage inline activities" ON inline_activities;

CREATE POLICY "Teachers and admins can manage inline activities"
    ON inline_activities FOR ALL
    TO authenticated
    USING (can_manage_content())
    WITH CHECK (can_manage_content());

-- =============================================
-- CHAPTER VOCABULARY POLICIES
-- =============================================
DROP POLICY IF EXISTS "Admins can manage chapter vocabulary" ON chapter_vocabulary;

CREATE POLICY "Teachers and admins can manage chapter vocabulary"
    ON chapter_vocabulary FOR ALL
    TO authenticated
    USING (can_manage_content())
    WITH CHECK (can_manage_content());

-- =============================================
-- VOCABULARY WORDS POLICIES (if exists)
-- =============================================
DROP POLICY IF EXISTS "Admins can manage vocabulary" ON vocabulary_words;

CREATE POLICY "Teachers and admins can manage vocabulary"
    ON vocabulary_words FOR ALL
    TO authenticated
    USING (can_manage_content())
    WITH CHECK (can_manage_content());
