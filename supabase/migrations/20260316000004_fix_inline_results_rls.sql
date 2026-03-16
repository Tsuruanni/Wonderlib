-- Fix inline_activity_results: students should not be able to DELETE their results
-- Previously: FOR ALL (SELECT + INSERT + UPDATE + DELETE)
-- Now: SELECT + INSERT only for students, school-scoped read for teachers

-- Drop the old overly permissive policy
DROP POLICY IF EXISTS "Users can manage own inline activity results" ON inline_activity_results;

-- Also drop the old teacher policy if it exists (from 20260213000001)
DROP POLICY IF EXISTS "Teachers can read student inline activity results" ON inline_activity_results;

-- Students can view their own results
CREATE POLICY "Users can view own inline activity results"
    ON inline_activity_results FOR SELECT
    USING (user_id = auth.uid());

-- Students can insert their own results
CREATE POLICY "Users can insert own inline activity results"
    ON inline_activity_results FOR INSERT
    WITH CHECK (user_id = auth.uid());

-- Teachers can read results from students in their school (school-scoped)
CREATE POLICY "Teachers can read school inline activity results"
    ON inline_activity_results FOR SELECT
    USING (
        is_teacher_or_higher()
        AND EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.id = inline_activity_results.user_id
            AND p.school_id = get_user_school_id()
        )
    );
