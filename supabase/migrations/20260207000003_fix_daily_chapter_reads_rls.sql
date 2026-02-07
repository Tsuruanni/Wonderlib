-- Fix: upsert requires UPDATE policy (INSERT only was insufficient)
-- Without this, re-reading the same chapter on the same day silently fails
-- because ON CONFLICT DO UPDATE is denied by RLS.
CREATE POLICY "Users can update own reads" ON daily_chapter_reads
    FOR UPDATE USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
