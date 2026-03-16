-- Add composite indexes for high-frequency query patterns

-- 1. Leaderboard: xp_logs scanned by created_at range, grouped by user_id
CREATE INDEX IF NOT EXISTS idx_xp_logs_created_user
    ON xp_logs (created_at DESC, user_id);

-- 2. Class + role queries (get_students_in_class, league_reset)
CREATE INDEX IF NOT EXISTS idx_profiles_class_role
    ON profiles (class_id, role);

-- 3. Completed reading progress (badge checks, stats)
CREATE INDEX IF NOT EXISTS idx_reading_progress_user_completed
    ON reading_progress (user_id) WHERE is_completed = TRUE;

-- 4. coin_logs by user + created_at (wallet history queries)
CREATE INDEX IF NOT EXISTS idx_coin_logs_user_created
    ON coin_logs (user_id, created_at DESC);
