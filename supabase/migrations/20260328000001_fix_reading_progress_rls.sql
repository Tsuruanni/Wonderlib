-- Fix: reading_progress FOR ALL policy allows students to DELETE their own progress.
-- Split into granular SELECT/INSERT/UPDATE policies (no DELETE).
-- Ref: docs/specs/01-book-system.md finding #9

-- Drop the overly permissive FOR ALL policy
DROP POLICY IF EXISTS "Users can manage own reading progress" ON reading_progress;

-- Granular student policies
CREATE POLICY "Users can read own reading progress"
    ON reading_progress FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Users can insert own reading progress"
    ON reading_progress FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own reading progress"
    ON reading_progress FOR UPDATE
    USING (user_id = auth.uid());

-- Note: No DELETE policy for students.
-- Existing teacher SELECT policy (from separate migration) is unaffected.
