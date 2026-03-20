-- Add UPDATE policy so path_position can be saved after DR completion
CREATE POLICY daily_review_sessions_update ON daily_review_sessions
    FOR UPDATE USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
