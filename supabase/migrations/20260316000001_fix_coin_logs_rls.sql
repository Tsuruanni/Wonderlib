-- Fix coin_logs INSERT policy: restrict to own user_id
-- Previously: WITH CHECK (true) — allowed any authenticated user to insert for any user_id
-- Now: WITH CHECK (user_id = auth.uid()) — matches the fix applied to xp_logs and user_badges

DROP POLICY IF EXISTS "System can insert coin logs" ON coin_logs;

CREATE POLICY "Users can insert own coin logs"
    ON coin_logs FOR INSERT
    WITH CHECK (user_id = auth.uid());
