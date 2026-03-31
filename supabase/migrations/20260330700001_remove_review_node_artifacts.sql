-- Remove learning path review node artifacts
-- The daily review node is no longer rendered in the learning path.
-- Gating behavior is preserved via dailyReviewNeededProvider (client-side).

-- Drop the daily review completions table (never read from client code)
DROP TABLE IF EXISTS path_daily_review_completions;

-- Drop the path_position column from daily_review_sessions
ALTER TABLE daily_review_sessions DROP COLUMN IF EXISTS path_position;

-- Drop the dead RPC (already unused per audit finding #9)
DROP FUNCTION IF EXISTS get_path_daily_reviews(UUID);

-- Drop the UPDATE policy that was only needed for path_position writes
DROP POLICY IF EXISTS "daily_review_sessions_update" ON daily_review_sessions;
