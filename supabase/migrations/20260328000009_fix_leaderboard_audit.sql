-- =============================================
-- Leaderboard audit fixes:
--   1a. Fix process_weekly_league_reset() — use app_now() + tier-based + temp table
--   1b. Auth checks on all 8 read RPCs + NOW() → app_now() in weekly RPCs
--   1c. Add total_count to get_weekly_school_leaderboard
--   1d. Drop stale RLS policy
-- =============================================

-- ===================
-- 1a. Fix process_weekly_league_reset()
-- ===================
CREATE OR REPLACE FUNCTION process_weekly_league_reset()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_last_week_start DATE := (date_trunc('week', app_now()) - INTERVAL '7 days')::DATE;
    v_last_week_ts TIMESTAMPTZ := date_trunc('week', app_now()) - INTERVAL '7 days';
    v_this_week_ts TIMESTAMPTZ := date_trunc('week', app_now());
    v_tier_order TEXT[] := ARRAY['bronze', 'silver', 'gold', 'platinum', 'diamond'];
    v_school RECORD;
    v_tier TEXT;
    v_student RECORD;
    v_group_size INTEGER;
    v_zone_size INTEGER;
    v_current_idx INTEGER;
    v_new_tier VARCHAR(20);
    v_result VARCHAR(20);
BEGIN
    IF EXISTS (SELECT 1 FROM league_history WHERE week_start = v_last_week_start LIMIT 1) THEN
        RAISE NOTICE 'Week % already processed', v_last_week_start;
        RETURN;
    END IF;

    CREATE TEMP TABLE IF NOT EXISTS tmp_weekly_xp AS
    SELECT
        xl.user_id,
        COALESCE(SUM(xl.amount), 0)::BIGINT AS week_xp
    FROM xp_logs xl
    WHERE xl.created_at >= v_last_week_ts
    AND xl.created_at < v_this_week_ts
    GROUP BY xl.user_id;

    CREATE INDEX IF NOT EXISTS idx_tmp_weekly_xp_user ON tmp_weekly_xp(user_id);

    FOR v_school IN
        SELECT DISTINCT p.school_id
        FROM profiles p
        WHERE p.role = 'student' AND p.school_id IS NOT NULL
    LOOP
        FOREACH v_tier IN ARRAY v_tier_order LOOP
            SELECT COUNT(*) INTO v_group_size
            FROM profiles
            WHERE school_id = v_school.school_id AND role = 'student' AND league_tier = v_tier;

            IF v_group_size = 0 THEN CONTINUE; END IF;

            IF v_group_size < 10 THEN v_zone_size := 1;
            ELSIF v_group_size <= 25 THEN v_zone_size := 2;
            ELSIF v_group_size <= 50 THEN v_zone_size := 3;
            ELSE v_zone_size := 5;
            END IF;

            v_current_idx := array_position(v_tier_order, v_tier);

            FOR v_student IN
                SELECT
                    p.id AS student_id,
                    p.class_id AS student_class_id,
                    p.league_tier AS current_tier,
                    COALESCE(wxc.week_xp, 0) AS weekly_xp,
                    RANK() OVER (ORDER BY COALESCE(wxc.week_xp, 0) DESC, p.xp DESC)::INTEGER AS rank
                FROM profiles p
                LEFT JOIN tmp_weekly_xp wxc ON p.id = wxc.user_id
                WHERE p.school_id = v_school.school_id
                AND p.role = 'student'
                AND p.league_tier = v_tier
                ORDER BY rank
            LOOP
                v_result := 'stayed';
                v_new_tier := v_student.current_tier;

                IF v_student.rank <= v_zone_size AND v_current_idx < 5 THEN
                    v_new_tier := v_tier_order[v_current_idx + 1];
                    v_result := 'promoted';
                ELSIF v_student.rank > (v_group_size - v_zone_size) AND v_current_idx > 1 THEN
                    v_new_tier := v_tier_order[v_current_idx - 1];
                    v_result := 'demoted';
                END IF;

                INSERT INTO league_history (user_id, class_id, school_id, week_start, league_tier, rank, weekly_xp, result)
                VALUES (v_student.student_id, v_student.student_class_id, v_school.school_id,
                        v_last_week_start, v_new_tier, v_student.rank, v_student.weekly_xp, v_result);

                IF v_new_tier != v_student.current_tier THEN
                    UPDATE profiles SET league_tier = v_new_tier WHERE id = v_student.student_id;
                END IF;
            END LOOP;
        END LOOP;
    END LOOP;

    DROP TABLE IF EXISTS tmp_weekly_xp;
END;
$$;

COMMENT ON FUNCTION process_weekly_league_reset IS 'Process weekly league promotion/demotion per school*tier. Zone thresholds must match leagueZoneSize() in owlio_shared. Call every Monday 00:00 UTC.';

-- ===================
-- 1b + 1c. Redefine all 8 leaderboard RPCs with auth checks + app_now()
-- ===================

-- =============================================
-- RPC 1. get_weekly_class_leaderboard
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
    v_week_start TIMESTAMPTZ := date_trunc('week', app_now());
    v_prev_week_start DATE := (date_trunc('week', app_now()) - INTERVAL '7 days')::DATE;
BEGIN
    -- Auth check: caller must belong to this class
    IF NOT EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND class_id = p_class_id
    ) THEN
        RAISE EXCEPTION 'Access denied: caller does not belong to this class';
    END IF;

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

COMMENT ON FUNCTION get_weekly_class_leaderboard IS 'Get top students in a class by weekly XP (since Monday). Auth: caller must belong to class.';

-- =============================================
-- RPC 2. get_weekly_school_leaderboard (+ total_count)
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
    league_tier VARCHAR,
    total_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    v_week_start TIMESTAMPTZ := date_trunc('week', app_now());
    v_prev_week_start DATE := (date_trunc('week', app_now()) - INTERVAL '7 days')::DATE;
    v_total_count BIGINT;
BEGIN
    -- Auth check: caller must belong to this school
    IF NOT EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND school_id = p_school_id
    ) THEN
        RAISE EXCEPTION 'Access denied: caller does not belong to this school';
    END IF;

    -- Compute total count of students matching filter
    SELECT COUNT(*) INTO v_total_count
    FROM profiles
    WHERE school_id = p_school_id AND role = 'student'
    AND (p_league_tier IS NULL OR league_tier = p_league_tier);

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
        p.league_tier,
        v_total_count
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

COMMENT ON FUNCTION get_weekly_school_leaderboard IS 'Get top students in a school by weekly XP. When p_league_tier is provided, ranks within that tier only. Returns total_count for pagination. Auth: caller must belong to school.';

-- =============================================
-- RPC 3. get_user_weekly_class_position
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
    v_week_start TIMESTAMPTZ := date_trunc('week', app_now());
    v_prev_week_start DATE := (date_trunc('week', app_now()) - INTERVAL '7 days')::DATE;
BEGIN
    -- Auth check: caller must belong to this class
    IF NOT EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND class_id = p_class_id
    ) THEN
        RAISE EXCEPTION 'Access denied: caller does not belong to this class';
    END IF;

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

COMMENT ON FUNCTION get_user_weekly_class_position IS 'Get a user''s position in weekly class leaderboard. Auth: caller must belong to class.';

-- =============================================
-- RPC 4. get_user_weekly_school_position
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
    v_week_start TIMESTAMPTZ := date_trunc('week', app_now());
    v_prev_week_start DATE := (date_trunc('week', app_now()) - INTERVAL '7 days')::DATE;
BEGIN
    -- Auth check: caller must belong to this school
    IF NOT EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND school_id = p_school_id
    ) THEN
        RAISE EXCEPTION 'Access denied: caller does not belong to this school';
    END IF;

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

COMMENT ON FUNCTION get_user_weekly_school_position IS 'Get a user''s position in weekly school leaderboard. When p_league_tier is provided, ranks within that tier only. Auth: caller must belong to school.';

-- =============================================
-- RPC 5. get_class_leaderboard (total XP, no time functions)
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
    -- Auth check: caller must belong to this class
    IF NOT EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND class_id = p_class_id
    ) THEN
        RAISE EXCEPTION 'Access denied: caller does not belong to this class';
    END IF;

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

COMMENT ON FUNCTION get_class_leaderboard IS 'Get top students in a class by total XP. Auth: caller must belong to class.';

-- =============================================
-- RPC 6. get_school_leaderboard (total XP, no time functions)
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
    -- Auth check: caller must belong to this school
    IF NOT EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND school_id = p_school_id
    ) THEN
        RAISE EXCEPTION 'Access denied: caller does not belong to this school';
    END IF;

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

COMMENT ON FUNCTION get_school_leaderboard IS 'Get top students in a school by total XP. Auth: caller must belong to school.';

-- =============================================
-- RPC 7. get_user_class_position (total XP, no time functions)
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
    -- Auth check: caller must belong to this class
    IF NOT EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND class_id = p_class_id
    ) THEN
        RAISE EXCEPTION 'Access denied: caller does not belong to this class';
    END IF;

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

COMMENT ON FUNCTION get_user_class_position IS 'Get a user''s position in class leaderboard by total XP. Auth: caller must belong to class.';

-- =============================================
-- RPC 8. get_user_school_position (total XP, no time functions)
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
    -- Auth check: caller must belong to this school
    IF NOT EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND school_id = p_school_id
    ) THEN
        RAISE EXCEPTION 'Access denied: caller does not belong to this school';
    END IF;

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

COMMENT ON FUNCTION get_user_school_position IS 'Get a user''s position in school leaderboard by total XP. Auth: caller must belong to school.';

-- ===================
-- 1d. Drop stale RLS policy
-- ===================
DROP POLICY IF EXISTS "Users can read classmates league history" ON league_history;
