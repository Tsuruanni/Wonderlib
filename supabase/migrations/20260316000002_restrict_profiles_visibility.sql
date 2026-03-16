-- Restrict profile visibility for student-facing queries
-- Students can still see school profiles via RLS (needed for leaderboard JOINs)
-- but this view hides sensitive fields for student-facing UI queries

CREATE OR REPLACE VIEW safe_profiles AS
SELECT
    id,
    school_id,
    class_id,
    role,
    first_name,
    last_name,
    avatar_url,
    xp,
    level,
    current_streak,
    longest_streak,
    league_tier,
    last_activity_date,
    created_at
    -- Deliberately omits: email, student_number, coins, settings
FROM profiles;

GRANT SELECT ON safe_profiles TO authenticated;

COMMENT ON VIEW safe_profiles IS 'Student-safe profile view. Omits email, student_number, coins, settings. Use for leaderboard and peer displays.';
