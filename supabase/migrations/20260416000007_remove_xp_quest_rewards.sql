-- Remove XP as a quest reward type.
-- All existing XP rewards are converted to coins 1:1 (aligns with the XP=coins 1:1 rule).
-- The CHECK constraint is tightened to disallow 'xp' going forward.

BEGIN;

-- Daily quests: convert XP rewards to coins
UPDATE daily_quests
SET reward_type = 'coins'
WHERE reward_type = 'xp';

-- Rename the "Review daily vocab" quest to "Daily Review" for a cleaner label.
UPDATE daily_quests
SET title = 'Daily Review'
WHERE quest_type = 'daily_review';

-- Monthly quests: convert XP rewards to coins (defensive; none seeded today)
UPDATE monthly_quests
SET reward_type = 'coins'
WHERE reward_type = 'xp';

-- Drop old CHECK constraints and recreate without 'xp'
ALTER TABLE daily_quests
  DROP CONSTRAINT IF EXISTS daily_quests_reward_type_check;

ALTER TABLE daily_quests
  ADD CONSTRAINT daily_quests_reward_type_check
  CHECK (reward_type IN ('coins', 'card_pack'));

ALTER TABLE monthly_quests
  DROP CONSTRAINT IF EXISTS monthly_quests_reward_type_check;

ALTER TABLE monthly_quests
  ADD CONSTRAINT monthly_quests_reward_type_check
  CHECK (reward_type IN ('coins', 'card_pack'));

COMMIT;
