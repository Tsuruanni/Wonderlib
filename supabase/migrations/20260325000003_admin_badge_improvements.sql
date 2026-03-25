-- =============================================
-- Admin Badge Improvements
-- 1. Remove 'daily_login' from condition_type CHECK
-- 2. Insert 3 new streak badges (14, 60, 100 days)
-- =============================================

-- 1. Update CHECK constraint (remove daily_login)
ALTER TABLE badges DROP CONSTRAINT IF EXISTS badges_condition_type_check;
ALTER TABLE badges ADD CONSTRAINT badges_condition_type_check
  CHECK (condition_type IN (
    'xp_total', 'streak_days', 'books_completed',
    'vocabulary_learned', 'perfect_scores', 'level_completed'
  ));

-- 2. New streak badges aligned with milestones
INSERT INTO badges (name, slug, description, icon, category, condition_type, condition_value, xp_reward)
VALUES
  ('Streak Warrior', 'streak-warrior', 'Maintain a 14-day reading streak', '🔥', 'streak', 'streak_days', 14, 150),
  ('Streak Hero', 'streak-hero', 'Maintain a 60-day reading streak', '🔥', 'streak', 'streak_days', 60, 750),
  ('Streak Immortal', 'streak-immortal', 'Maintain a 100-day reading streak', '🔥', 'streak', 'streak_days', 100, 1500)
ON CONFLICT (slug) DO NOTHING;
