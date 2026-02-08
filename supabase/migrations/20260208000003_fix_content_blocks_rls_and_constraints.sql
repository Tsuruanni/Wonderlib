-- Fix content_blocks RLS to only allow reading published book content
-- Fix missing constraints on xp_logs and activity_results

-- =============================================
-- 1. CONTENT BLOCKS: Restrict SELECT to published books
-- =============================================

-- Drop the overly permissive read policy
DROP POLICY IF EXISTS "content_blocks_read_authenticated" ON content_blocks;

-- Allow reading only content from published books (or if user is teacher/admin)
CREATE POLICY "content_blocks_read_published"
    ON content_blocks FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM chapters c
            JOIN books b ON c.book_id = b.id
            WHERE c.id = content_blocks.chapter_id
            AND b.status = 'published'
        )
        OR EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.id = auth.uid()
            AND p.role IN ('teacher', 'head', 'admin')
        )
    );

-- =============================================
-- 2. XP_LOGS: Prevent negative XP amounts
-- =============================================

ALTER TABLE xp_logs ADD CONSTRAINT xp_logs_amount_positive CHECK (amount > 0);

-- =============================================
-- 3. ACTIVITY_RESULTS: Prevent duplicate attempts
-- =============================================

ALTER TABLE activity_results
    ADD CONSTRAINT activity_results_unique_attempt
    UNIQUE (user_id, activity_id, attempt_number);

-- =============================================
-- 4. MISSING INDEXES for badge eligibility queries
-- =============================================

CREATE INDEX IF NOT EXISTS idx_badges_condition_type ON badges(condition_type);
CREATE INDEX IF NOT EXISTS idx_schools_status ON schools(status);
