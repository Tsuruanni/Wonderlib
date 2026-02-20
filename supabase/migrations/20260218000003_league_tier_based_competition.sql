-- =============================================
-- LEAGUE SYSTEM: Tier-based competition (Duolingo model)
-- Students compete WITHIN their tier, not all together.
-- Top N in each tier get promoted, bottom N get demoted.
-- =============================================

-- 1. Indexes for tier-based queries
CREATE INDEX IF NOT EXISTS idx_profiles_school_tier
    ON profiles(school_id, league_tier) WHERE role = 'student';
CREATE INDEX IF NOT EXISTS idx_league_history_school_tier_week
    ON league_history(week_start, school_id, league_tier);

-- 2. Rewrite process_weekly_league_reset() — tier-based ranking
CREATE OR REPLACE FUNCTION process_weekly_league_reset()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_last_week_start DATE := (date_trunc('week', NOW()) - INTERVAL '7 days')::DATE;
    v_last_week_ts TIMESTAMPTZ := date_trunc('week', NOW()) - INTERVAL '7 days';
    v_this_week_ts TIMESTAMPTZ := date_trunc('week', NOW());
    v_school RECORD;
    v_tier TEXT;
    v_tier_order TEXT[] := ARRAY['bronze', 'silver', 'gold', 'platinum', 'diamond'];
    v_student RECORD;
    v_group_size INTEGER;
    v_zone_size INTEGER;
    v_current_idx INTEGER;
    v_new_tier VARCHAR(20);
    v_result VARCHAR(20);
BEGIN
    -- Skip if already processed this week
    IF EXISTS (SELECT 1 FROM league_history WHERE week_start = v_last_week_start LIMIT 1) THEN
        RAISE NOTICE 'Week % already processed', v_last_week_start;
        RETURN;
    END IF;

    -- Process each school
    FOR v_school IN
        SELECT DISTINCT p.school_id
        FROM profiles p
        WHERE p.role = 'student'
        AND p.school_id IS NOT NULL
    LOOP
        -- Process each tier within the school
        FOREACH v_tier IN ARRAY v_tier_order LOOP
            -- Count students in this school+tier
            SELECT COUNT(*) INTO v_group_size
            FROM profiles
            WHERE school_id = v_school.school_id
            AND role = 'student'
            AND league_tier = v_tier;

            -- Skip empty tier groups
            IF v_group_size = 0 THEN
                CONTINUE;
            END IF;

            -- Determine zone size based on tier group size
            IF v_group_size < 10 THEN
                v_zone_size := 1;
            ELSIF v_group_size <= 25 THEN
                v_zone_size := 2;
            ELSIF v_group_size <= 50 THEN
                v_zone_size := 3;
            ELSE
                v_zone_size := 5;
            END IF;

            -- Find current tier index
            v_current_idx := array_position(v_tier_order, v_tier);

            -- Rank students by weekly XP WITHIN this tier
            FOR v_student IN
                WITH weekly_xp_calc AS (
                    SELECT
                        xl.user_id AS uid,
                        COALESCE(SUM(xl.amount), 0) AS week_xp
                    FROM xp_logs xl
                    WHERE xl.created_at >= v_last_week_ts
                    AND xl.created_at < v_this_week_ts
                    GROUP BY xl.user_id
                )
                SELECT
                    p.id AS student_id,
                    p.class_id AS student_class_id,
                    p.league_tier AS current_tier,
                    COALESCE(wxc.week_xp, 0) AS weekly_xp,
                    RANK() OVER (ORDER BY COALESCE(wxc.week_xp, 0) DESC, p.xp DESC)::INTEGER AS rank
                FROM profiles p
                LEFT JOIN weekly_xp_calc wxc ON p.id = wxc.uid
                WHERE p.school_id = v_school.school_id
                AND p.role = 'student'
                AND p.league_tier = v_tier
                ORDER BY rank
            LOOP
                v_result := 'stayed';
                v_new_tier := v_student.current_tier;

                IF v_student.rank <= v_zone_size AND v_current_idx < 5 THEN
                    -- Promote (not already diamond)
                    v_new_tier := v_tier_order[v_current_idx + 1];
                    v_result := 'promoted';
                ELSIF v_student.rank > (v_group_size - v_zone_size) AND v_current_idx > 1 THEN
                    -- Demote (not already bronze)
                    v_new_tier := v_tier_order[v_current_idx - 1];
                    v_result := 'demoted';
                END IF;

                -- Insert history snapshot
                INSERT INTO league_history (user_id, class_id, school_id, week_start, league_tier, rank, weekly_xp, result)
                VALUES (v_student.student_id, v_student.student_class_id, v_school.school_id,
                        v_last_week_start, v_new_tier, v_student.rank, v_student.weekly_xp, v_result);

                -- Update profile if tier changed
                IF v_new_tier != v_student.current_tier THEN
                    UPDATE profiles SET league_tier = v_new_tier WHERE id = v_student.student_id;
                END IF;
            END LOOP;
        END LOOP;
    END LOOP;
END;
$$;

COMMENT ON FUNCTION process_weekly_league_reset IS 'Process weekly league promotion/demotion per tier within each school. Call every Monday 00:00 UTC.';

-- 3. Rewrite get_weekly_school_leaderboard() — add tier filter
DROP FUNCTION IF EXISTS get_weekly_school_leaderboard(UUID, INTEGER);

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

-- 4. Rewrite get_user_weekly_school_position() — add tier filter
DROP FUNCTION IF EXISTS get_user_weekly_school_position(UUID, UUID);

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
    SELECT r.id, r.first_name, r.last_name, r.class_name, r.avatar_url, r.xp,
           r.week_xp, r.level, r.rnk, r.prev_rank, r.league_tier
    FROM ranked r
    WHERE r.id = p_user_id;
END;
$$;

COMMENT ON FUNCTION get_user_weekly_school_position IS 'Get a user''s position in weekly school leaderboard. When p_league_tier is provided, ranks within that tier only.';
