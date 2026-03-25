-- =============================================
-- Add avatar_equipped_cache to all 8 leaderboard RPCs + safe_profiles view
-- avatar_equipped_cache column was added to profiles in 20260326000001
-- =============================================

-- =============================================
-- 1. get_weekly_class_leaderboard
-- =============================================
DROP FUNCTION IF EXISTS get_weekly_class_leaderboard(UUID, INTEGER);

CREATE OR REPLACE FUNCTION get_weekly_class_leaderboard(
    p_class_id UUID,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE(
    user_id UUID,
    first_name VARCHAR,
    last_name VARCHAR,
    avatar_url VARCHAR,
    avatar_equipped_cache JSONB,
    total_xp INTEGER,
    weekly_xp BIGINT,
    level INTEGER,
    rank BIGINT,
    previous_rank INTEGER,
    league_tier VARCHAR
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    v_week_start TIMESTAMPTZ := date_trunc('week', NOW());
    v_prev_week_start DATE := (date_trunc('week', NOW()) - INTERVAL '7 days')::DATE;
BEGIN
    RETURN QUERY
    WITH weekly_xp_calc AS (
        SELECT
            xl.user_id AS uid,
            COALESCE(SUM(xl.amount), 0) AS week_xp
        FROM xp_logs xl
        WHERE xl.created_at >= v_week_start
        GROUP BY xl.user_id
    ),
    prev_week AS (
        SELECT
            lh.user_id AS uid,
            lh.rank AS prev_rank
        FROM league_history lh
        WHERE lh.week_start = v_prev_week_start
        AND lh.class_id = p_class_id
    )
    SELECT
        p.id,
        p.first_name,
        p.last_name,
        p.avatar_url,
        p.avatar_equipped_cache,
        p.xp,
        COALESCE(wxc.week_xp, 0),
        p.level,
        RANK() OVER (ORDER BY COALESCE(wxc.week_xp, 0) DESC, p.xp DESC),
        pw.prev_rank,
        p.league_tier
    FROM profiles p
    LEFT JOIN weekly_xp_calc wxc ON p.id = wxc.uid
    LEFT JOIN prev_week pw ON p.id = pw.uid
    WHERE p.class_id = p_class_id
    AND p.role = 'student'
    ORDER BY COALESCE(wxc.week_xp, 0) DESC, p.xp DESC
    LIMIT p_limit;
END;
$$;

COMMENT ON FUNCTION get_weekly_class_leaderboard IS 'Get top students in a class by weekly XP (since Monday)';

-- =============================================
-- 2. get_weekly_school_leaderboard
-- =============================================
DROP FUNCTION IF EXISTS get_weekly_school_leaderboard(UUID, INTEGER, VARCHAR);

CREATE OR REPLACE FUNCTION get_weekly_school_leaderboard(
    p_school_id UUID,
    p_limit INTEGER DEFAULT 10,
    p_league_tier VARCHAR DEFAULT NULL
)
RETURNS TABLE(
    user_id UUID,
    first_name VARCHAR,
    last_name VARCHAR,
    class_name VARCHAR,
    avatar_url VARCHAR,
    avatar_equipped_cache JSONB,
    total_xp INTEGER,
    weekly_xp BIGINT,
    level INTEGER,
    rank BIGINT,
    previous_rank INTEGER,
    league_tier VARCHAR
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    v_week_start TIMESTAMPTZ := date_trunc('week', NOW());
    v_prev_week_start DATE := (date_trunc('week', NOW()) - INTERVAL '7 days')::DATE;
BEGIN
    RETURN QUERY
    WITH weekly_xp_calc AS (
        SELECT
            xl.user_id AS uid,
            COALESCE(SUM(xl.amount), 0) AS week_xp
        FROM xp_logs xl
        WHERE xl.created_at >= v_week_start
        GROUP BY xl.user_id
    ),
    prev_week AS (
        SELECT
            lh.user_id AS uid,
            lh.rank AS prev_rank
        FROM league_history lh
        WHERE lh.week_start = v_prev_week_start
        AND lh.school_id = p_school_id
        -- No tier filter: previous rank is from last week regardless of tier changes
    )
    SELECT
        p.id,
        p.first_name,
        p.last_name,
        c.name,
        p.avatar_url,
        p.avatar_equipped_cache,
        p.xp,
        COALESCE(wxc.week_xp, 0),
        p.level,
        RANK() OVER (ORDER BY COALESCE(wxc.week_xp, 0) DESC, p.xp DESC),
        pw.prev_rank,
        p.league_tier
    FROM profiles p
    LEFT JOIN weekly_xp_calc wxc ON p.id = wxc.uid
    LEFT JOIN prev_week pw ON p.id = pw.uid
    LEFT JOIN classes c ON p.class_id = c.id
    WHERE p.school_id = p_school_id
    AND p.role = 'student'
    AND (p_league_tier IS NULL OR p.league_tier = p_league_tier)
    ORDER BY COALESCE(wxc.week_xp, 0) DESC, p.xp DESC
    LIMIT p_limit;
END;
$$;

COMMENT ON FUNCTION get_weekly_school_leaderboard IS 'Get top students in a school by weekly XP. When p_league_tier is provided, ranks within that tier only.';

-- =============================================
-- 3. get_user_weekly_class_position
-- =============================================
DROP FUNCTION IF EXISTS get_user_weekly_class_position(UUID, UUID);

CREATE OR REPLACE FUNCTION get_user_weekly_class_position(
    p_user_id UUID,
    p_class_id UUID
)
RETURNS TABLE(
    user_id UUID,
    first_name VARCHAR,
    last_name VARCHAR,
    avatar_url VARCHAR,
    avatar_equipped_cache JSONB,
    total_xp INTEGER,
    weekly_xp BIGINT,
    level INTEGER,
    rank BIGINT,
    previous_rank INTEGER,
    league_tier VARCHAR
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    v_week_start TIMESTAMPTZ := date_trunc('week', NOW());
    v_prev_week_start DATE := (date_trunc('week', NOW()) - INTERVAL '7 days')::DATE;
BEGIN
    RETURN QUERY
    WITH weekly_xp_calc AS (
        SELECT
            xl.user_id AS uid,
            COALESCE(SUM(xl.amount), 0) AS week_xp
        FROM xp_logs xl
        WHERE xl.created_at >= v_week_start
        GROUP BY xl.user_id
    ),
    prev_week AS (
        SELECT
            lh.user_id AS uid,
            lh.rank AS prev_rank
        FROM league_history lh
        WHERE lh.week_start = v_prev_week_start
        AND lh.class_id = p_class_id
    ),
    ranked AS (
        SELECT
            p.id,
            p.first_name,
            p.last_name,
            p.avatar_url,
            p.avatar_equipped_cache,
            p.xp,
            COALESCE(wxc.week_xp, 0) AS week_xp,
            p.level,
            RANK() OVER (ORDER BY COALESCE(wxc.week_xp, 0) DESC, p.xp DESC) AS rnk,
            pw.prev_rank,
            p.league_tier
        FROM profiles p
        LEFT JOIN weekly_xp_calc wxc ON p.id = wxc.uid
        LEFT JOIN prev_week pw ON p.id = pw.uid
        WHERE p.class_id = p_class_id
        AND p.role = 'student'
    )
    SELECT r.id, r.first_name, r.last_name, r.avatar_url, r.avatar_equipped_cache,
           r.xp, r.week_xp, r.level, r.rnk, r.prev_rank, r.league_tier
    FROM ranked r
    WHERE r.id = p_user_id;
END;
$$;

COMMENT ON FUNCTION get_user_weekly_class_position IS 'Get a user''s position in weekly class leaderboard';

-- =============================================
-- 4. get_user_weekly_school_position
-- =============================================
DROP FUNCTION IF EXISTS get_user_weekly_school_position(UUID, UUID, VARCHAR);

CREATE OR REPLACE FUNCTION get_user_weekly_school_position(
    p_user_id UUID,
    p_school_id UUID,
    p_league_tier VARCHAR DEFAULT NULL
)
RETURNS TABLE(
    user_id UUID,
    first_name VARCHAR,
    last_name VARCHAR,
    class_name VARCHAR,
    avatar_url VARCHAR,
    avatar_equipped_cache JSONB,
    total_xp INTEGER,
    weekly_xp BIGINT,
    level INTEGER,
    rank BIGINT,
    previous_rank INTEGER,
    league_tier VARCHAR
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    v_week_start TIMESTAMPTZ := date_trunc('week', NOW());
    v_prev_week_start DATE := (date_trunc('week', NOW()) - INTERVAL '7 days')::DATE;
BEGIN
    RETURN QUERY
    WITH weekly_xp_calc AS (
        SELECT
            xl.user_id AS uid,
            COALESCE(SUM(xl.amount), 0) AS week_xp
        FROM xp_logs xl
        WHERE xl.created_at >= v_week_start
        GROUP BY xl.user_id
    ),
    prev_week AS (
        SELECT
            lh.user_id AS uid,
            lh.rank AS prev_rank
        FROM league_history lh
        WHERE lh.week_start = v_prev_week_start
        AND lh.school_id = p_school_id
        -- No tier filter: previous rank is from last week regardless of tier changes
    ),
    ranked AS (
        SELECT
            p.id,
            p.first_name,
            p.last_name,
            c.name AS class_name,
            p.avatar_url,
            p.avatar_equipped_cache,
            p.xp,
            COALESCE(wxc.week_xp, 0) AS week_xp,
            p.level,
            RANK() OVER (ORDER BY COALESCE(wxc.week_xp, 0) DESC, p.xp DESC) AS rnk,
            pw.prev_rank,
            p.league_tier
        FROM profiles p
        LEFT JOIN weekly_xp_calc wxc ON p.id = wxc.uid
        LEFT JOIN prev_week pw ON p.id = pw.uid
        LEFT JOIN classes c ON p.class_id = c.id
        WHERE p.school_id = p_school_id
        AND p.role = 'student'
        AND (p_league_tier IS NULL OR p.league_tier = p_league_tier)
    )
    SELECT r.id, r.first_name, r.last_name, r.class_name, r.avatar_url, r.avatar_equipped_cache,
           r.xp, r.week_xp, r.level, r.rnk, r.prev_rank, r.league_tier
    FROM ranked r
    WHERE r.id = p_user_id;
END;
$$;

COMMENT ON FUNCTION get_user_weekly_school_position IS 'Get a user''s position in weekly school leaderboard. When p_league_tier is provided, ranks within that tier only.';

-- =============================================
-- 5. get_class_leaderboard
-- =============================================
DROP FUNCTION IF EXISTS get_class_leaderboard(UUID, INTEGER);

CREATE OR REPLACE FUNCTION get_class_leaderboard(
    p_class_id UUID,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE(
    user_id UUID,
    first_name VARCHAR,
    last_name VARCHAR,
    avatar_url VARCHAR,
    avatar_equipped_cache JSONB,
    xp INTEGER,
    level INTEGER,
    rank BIGINT,
    league_tier VARCHAR
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.id,
        p.first_name,
        p.last_name,
        p.avatar_url,
        p.avatar_equipped_cache,
        p.xp,
        p.level,
        RANK() OVER (ORDER BY p.xp DESC),
        p.league_tier
    FROM profiles p
    WHERE p.class_id = p_class_id
    AND p.role = 'student'
    ORDER BY p.xp DESC
    LIMIT p_limit;
END;
$$;

-- =============================================
-- 6. get_school_leaderboard
-- =============================================
DROP FUNCTION IF EXISTS get_school_leaderboard(UUID, INTEGER);

CREATE OR REPLACE FUNCTION get_school_leaderboard(
    p_school_id UUID,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE(
    user_id UUID,
    first_name VARCHAR,
    last_name VARCHAR,
    class_name VARCHAR,
    avatar_url VARCHAR,
    avatar_equipped_cache JSONB,
    xp INTEGER,
    level INTEGER,
    rank BIGINT,
    league_tier VARCHAR
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.id,
        p.first_name,
        p.last_name,
        c.name,
        p.avatar_url,
        p.avatar_equipped_cache,
        p.xp,
        p.level,
        RANK() OVER (ORDER BY p.xp DESC),
        p.league_tier
    FROM profiles p
    LEFT JOIN classes c ON p.class_id = c.id
    WHERE p.school_id = p_school_id
    AND p.role = 'student'
    ORDER BY p.xp DESC
    LIMIT p_limit;
END;
$$;

-- =============================================
-- 7. get_user_class_position
-- =============================================
DROP FUNCTION IF EXISTS get_user_class_position(UUID, UUID);

CREATE OR REPLACE FUNCTION get_user_class_position(
    p_user_id UUID,
    p_class_id UUID
)
RETURNS TABLE(
    user_id UUID,
    first_name VARCHAR,
    last_name VARCHAR,
    avatar_url VARCHAR,
    avatar_equipped_cache JSONB,
    xp INTEGER,
    level INTEGER,
    rank BIGINT,
    league_tier VARCHAR
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
    RETURN QUERY
    WITH ranked AS (
        SELECT
            p.id,
            p.first_name,
            p.last_name,
            p.avatar_url,
            p.avatar_equipped_cache,
            p.xp,
            p.level,
            RANK() OVER (ORDER BY p.xp DESC) AS rnk,
            p.league_tier
        FROM profiles p
        WHERE p.class_id = p_class_id
        AND p.role = 'student'
    )
    SELECT r.id, r.first_name, r.last_name, r.avatar_url, r.avatar_equipped_cache,
           r.xp, r.level, r.rnk, r.league_tier
    FROM ranked r
    WHERE r.id = p_user_id;
END;
$$;

-- =============================================
-- 8. get_user_school_position
-- =============================================
DROP FUNCTION IF EXISTS get_user_school_position(UUID, UUID);

CREATE OR REPLACE FUNCTION get_user_school_position(
    p_user_id UUID,
    p_school_id UUID
)
RETURNS TABLE(
    user_id UUID,
    first_name VARCHAR,
    last_name VARCHAR,
    class_name VARCHAR,
    avatar_url VARCHAR,
    avatar_equipped_cache JSONB,
    xp INTEGER,
    level INTEGER,
    rank BIGINT,
    league_tier VARCHAR
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
    RETURN QUERY
    WITH ranked AS (
        SELECT
            p.id,
            p.first_name,
            p.last_name,
            c.name AS class_name,
            p.avatar_url,
            p.avatar_equipped_cache,
            p.xp,
            p.level,
            RANK() OVER (ORDER BY p.xp DESC) AS rnk,
            p.league_tier
        FROM profiles p
        LEFT JOIN classes c ON p.class_id = c.id
        WHERE p.school_id = p_school_id
        AND p.role = 'student'
    )
    SELECT r.id, r.first_name, r.last_name, r.class_name, r.avatar_url, r.avatar_equipped_cache,
           r.xp, r.level, r.rnk, r.league_tier
    FROM ranked r
    WHERE r.id = p_user_id;
END;
$$;

-- =============================================
-- safe_profiles view: add avatar_base_id + avatar_equipped_cache
-- =============================================
DROP VIEW IF EXISTS safe_profiles;

CREATE VIEW safe_profiles AS
SELECT
    id,
    school_id,
    class_id,
    role,
    first_name,
    last_name,
    avatar_url,
    username,
    avatar_base_id,
    avatar_equipped_cache,
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

COMMENT ON VIEW safe_profiles IS 'Student-safe profile view. Omits email, student_number, coins, settings. Includes username, avatar_base_id, avatar_equipped_cache for public display.';
