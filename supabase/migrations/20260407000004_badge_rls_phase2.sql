-- Badge Security Phase 2: drop self-insert policy
-- All badge awarding goes through check_and_award_badges (SECURITY DEFINER).
-- The direct INSERT path (awardBadge in Flutter) was dead code and has been removed.

DROP POLICY IF EXISTS "Users can only insert own badges" ON user_badges;
