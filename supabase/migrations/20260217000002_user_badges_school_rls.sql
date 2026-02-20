-- Allow students to view badges of other students in the same school
-- Needed for the student profile popup on the leaderboard
CREATE POLICY "Users can view schoolmate badges"
    ON user_badges FOR SELECT
    USING (
        user_id IN (
            SELECT id FROM profiles
            WHERE school_id = get_user_school_id()
        )
    );
