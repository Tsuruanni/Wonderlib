-- =============================================
-- FIX: user_badges and xp_logs INSERT RLS policies
--
-- Problem: Both tables had WITH CHECK (true) INSERT policies,
-- allowing any authenticated user to directly insert rows for ANY user.
-- The check_and_award_badges() and award_xp_transaction() functions
-- are SECURITY DEFINER and bypass RLS entirely, so permissive
-- INSERT policies are unnecessary and create a security hole.
-- =============================================

-- Fix user_badges: restrict INSERT to own user_id
DROP POLICY IF EXISTS "System can award badges" ON user_badges;

CREATE POLICY "Users can only insert own badges"
  ON user_badges FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- Fix xp_logs: restrict INSERT to own user_id
DROP POLICY IF EXISTS "System can log XP" ON xp_logs;

CREATE POLICY "Users can only insert own xp logs"
  ON xp_logs FOR INSERT
  WITH CHECK (user_id = auth.uid());
