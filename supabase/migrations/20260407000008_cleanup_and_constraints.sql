-- =============================================================================
-- Migration: Orphan Cleanup + Safety Constraints
-- FIX-14: Drop orphan daily_quest_pack tables & functions
-- FIX-15: Remove unused daily_login badge condition type
-- FIX-16: Add CHECK constraints on xp_logs.source and coin_logs.source
-- FIX-20: Unique attempt constraint on activity_results
-- FIX-21: Unique attempt constraint on book_quiz_results
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Section 1: Drop orphan daily_quest_pack tables & functions (FIX-14)
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS claim_daily_quest_pack(UUID);
DROP FUNCTION IF EXISTS has_daily_quest_pack_claimed(UUID);
DROP TABLE IF EXISTS daily_quest_pack_claims;

-- -----------------------------------------------------------------------------
-- Section 2: Tighten badge condition_type CHECK to known production values (FIX-15)
-- daily_login was removed by 20260325000003; this re-asserts the clean constraint.
-- Production values (from shared enum + 20260325000003):
--   xp_total, streak_days, books_completed, vocabulary_learned, perfect_scores, level_completed
-- -----------------------------------------------------------------------------
ALTER TABLE badges DROP CONSTRAINT IF EXISTS badges_condition_type_check;
ALTER TABLE badges ADD CONSTRAINT badges_condition_type_check
  CHECK (condition_type IN (
    'xp_total', 'streak_days', 'books_completed',
    'vocabulary_learned', 'perfect_scores', 'level_completed'
  ));

-- -----------------------------------------------------------------------------
-- Section 3: XP source CHECK constraint (FIX-16)
-- NOT VALID: applies to new rows only — legacy rows (e.g. 'activity', 'manual')
-- from early development are left intact. Use VALIDATE CONSTRAINT later once
-- legacy rows age out or are cleaned.
-- Current valid sources (all RPC call sites):
--   chapter_complete, inline_activity, quiz_pass, book_complete, badge,
--   streak_milestone, daily_review, vocabulary_session, daily_quest
-- -----------------------------------------------------------------------------
ALTER TABLE xp_logs ADD CONSTRAINT chk_xp_source CHECK (
  source IN (
    'chapter_complete', 'inline_activity', 'quiz_pass', 'book_complete',
    'badge', 'streak_milestone', 'daily_review', 'vocabulary_session',
    'daily_quest'
  )
) NOT VALID;

-- -----------------------------------------------------------------------------
-- Section 4: Coin source CHECK constraint (FIX-16)
-- NOT VALID: same rationale — protect new rows, don't break on any legacy coin rows.
-- Current valid sources (all RPC call sites):
--   pack_purchase, daily_quest, streak_freeze, vocabulary_session, daily_review,
--   card_trade, avatar_item, avatar_gender_change
-- -----------------------------------------------------------------------------
ALTER TABLE coin_logs ADD CONSTRAINT chk_coin_source CHECK (
  source IN (
    'pack_purchase', 'daily_quest', 'streak_freeze',
    'vocabulary_session', 'daily_review', 'card_trade',
    'avatar_item', 'avatar_gender_change'
  )
) NOT VALID;

-- -----------------------------------------------------------------------------
-- Section 5: UNIQUE attempt constraints (FIX-20, FIX-21)
-- Uses IF NOT EXISTS to handle gracefully if duplicates exist or already applied
-- -----------------------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS idx_activity_results_unique_attempt
  ON activity_results(user_id, activity_id, attempt_number);

CREATE UNIQUE INDEX IF NOT EXISTS idx_quiz_results_unique_attempt
  ON book_quiz_results(user_id, quiz_id, attempt_number);
