-- Performance index for daily quest progress queries.
-- get_quest_progress RPC counts correct answers per day:
--   WHERE user_id = X AND is_correct = true AND answered_at >= today
CREATE INDEX idx_inline_activity_results_user_answered
  ON inline_activity_results (user_id, answered_at DESC)
  WHERE is_correct = true;
