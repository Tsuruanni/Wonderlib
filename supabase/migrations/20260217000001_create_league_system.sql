-- =============================================
-- LEAGUE SYSTEM: Weekly Duolingo-style leaderboard
-- =============================================

-- 1. Add league_tier column to profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS league_tier VARCHAR(20) NOT NULL DEFAULT 'bronze';

-- 2. Create league_history table (weekly snapshots)
CREATE TABLE IF NOT EXISTS league_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    class_id UUID REFERENCES classes(id) ON DELETE SET NULL,
    week_start DATE NOT NULL,
    league_tier VARCHAR(20) NOT NULL,
    rank INTEGER NOT NULL,
    weekly_xp INTEGER NOT NULL DEFAULT 0,
    result VARCHAR(20) NOT NULL DEFAULT 'stayed',  -- 'promoted', 'demoted', 'stayed'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, week_start)
);

CREATE INDEX IF NOT EXISTS idx_league_history_week ON league_history(week_start, class_id);
CREATE INDEX IF NOT EXISTS idx_league_history_user ON league_history(user_id, week_start DESC);

-- Enable RLS
ALTER TABLE league_history ENABLE ROW LEVEL SECURITY;

-- Students can read their own history + classmates' history
CREATE POLICY "Users can read own league history"
    ON league_history FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Users can read classmates league history"
    ON league_history FOR SELECT
    USING (
        class_id IN (
            SELECT class_id FROM profiles WHERE id = auth.uid()
        )
    );

-- Only service role can insert/update (via RPC functions with SECURITY DEFINER)
CREATE POLICY "Service role can manage league history"
    ON league_history FOR ALL
    USING (auth.role() = 'service_role');

-- =============================================
-- Helper: Get Monday-based week start date
-- PostgreSQL date_trunc('week', ...) returns Monday by default (ISO 8601)
-- =============================================

-- =============================================
-- GET WEEKLY CLASS LEADERBOARD
-- Ranks students by XP earned this week (since Monday 00:00 UTC)
-- =============================================
CREATE OR REPLACE FUNCTION get_weekly_class_leaderboard(
    p_class_id UUID,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE(
    user_id UUID,
    first_name VARCHAR,
    last_name VARCHAR,
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
        AND lh.class_id = p_class_id
    )
    SELECT
        p.id,
        p.first_name,
        p.last_name,
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
    WHERE p.class_id = p_class_id
    AND p.role = 'student'
    ORDER BY COALESCE(wxc.week_xp, 0) DESC, p.xp DESC
    LIMIT p_limit;
END;
$$;

COMMENT ON FUNCTION get_weekly_class_leaderboard IS 'Get top students in a class by weekly XP (since Monday)';

-- =============================================
-- GET WEEKLY SCHOOL LEADERBOARD
-- =============================================
CREATE OR REPLACE FUNCTION get_weekly_school_leaderboard(
    p_school_id UUID,
    p_limit INTEGER DEFAULT 10
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
    ORDER BY COALESCE(wxc.week_xp, 0) DESC, p.xp DESC
    LIMIT p_limit;
END;
$$;

COMMENT ON FUNCTION get_weekly_school_leaderboard IS 'Get top students in a school by weekly XP (since Monday)';

-- =============================================
-- GET USER WEEKLY CLASS POSITION
-- Returns a specific user's rank in their class (for when they're not in top N)
-- =============================================
CREATE OR REPLACE FUNCTION get_user_weekly_class_position(
    p_user_id UUID,
    p_class_id UUID
)
RETURNS TABLE(
    user_id UUID,
    first_name VARCHAR,
    last_name VARCHAR,
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
        AND lh.class_id = p_class_id
    ),
    ranked AS (
        SELECT
            p.id,
            p.first_name,
            p.last_name,
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
        WHERE p.class_id = p_class_id
        AND p.role = 'student'
    )
    SELECT r.id, r.first_name, r.last_name, r.avatar_url, r.xp,
           r.week_xp, r.level, r.rnk, r.prev_rank, r.league_tier
    FROM ranked r
    WHERE r.id = p_user_id;
END;
$$;

COMMENT ON FUNCTION get_user_weekly_class_position IS 'Get a user''s position in weekly class leaderboard';

-- =============================================
-- GET USER WEEKLY SCHOOL POSITION
-- =============================================
CREATE OR REPLACE FUNCTION get_user_weekly_school_position(
    p_user_id UUID,
    p_school_id UUID
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
    )
    SELECT r.id, r.first_name, r.last_name, r.class_name, r.avatar_url, r.xp,
           r.week_xp, r.level, r.rnk, r.prev_rank, r.league_tier
    FROM ranked r
    WHERE r.id = p_user_id;
END;
$$;

COMMENT ON FUNCTION get_user_weekly_school_position IS 'Get a user''s position in weekly school leaderboard';

-- =============================================
-- PROCESS WEEKLY LEAGUE RESET
-- Called every Monday 00:00 UTC (via pg_cron or Edge Function)
-- Snapshots last week's results and applies promotion/demotion
-- =============================================
CREATE OR REPLACE FUNCTION process_weekly_league_reset()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_last_week_start DATE := (date_trunc('week', NOW()) - INTERVAL '7 days')::DATE;
    v_last_week_ts TIMESTAMPTZ := date_trunc('week', NOW()) - INTERVAL '7 days';
    v_this_week_ts TIMESTAMPTZ := date_trunc('week', NOW());
    v_class RECORD;
    v_student RECORD;
    v_class_size INTEGER;
    v_promote_count INTEGER;
    v_demote_count INTEGER;
    v_tier_order TEXT[] := ARRAY['bronze', 'silver', 'gold', 'platinum', 'diamond'];
    v_current_idx INTEGER;
    v_new_tier VARCHAR(20);
    v_result VARCHAR(20);
BEGIN
    -- Skip if already processed this week
    IF EXISTS (SELECT 1 FROM league_history WHERE week_start = v_last_week_start LIMIT 1) THEN
        RAISE NOTICE 'Week % already processed', v_last_week_start;
        RETURN;
    END IF;

    -- Process each class
    FOR v_class IN
        SELECT DISTINCT c.id AS class_id
        FROM classes c
        INNER JOIN profiles p ON p.class_id = c.id AND p.role = 'student'
    LOOP
        -- Count students in this class
        SELECT COUNT(*) INTO v_class_size
        FROM profiles
        WHERE class_id = v_class.class_id AND role = 'student';

        -- Determine promotion/demotion counts based on class size
        IF v_class_size < 5 THEN
            v_promote_count := 1;
            v_demote_count := 1;
        ELSIF v_class_size <= 10 THEN
            v_promote_count := 2;
            v_demote_count := 2;
        ELSE
            v_promote_count := 3;
            v_demote_count := 3;
        END IF;

        -- Rank students by weekly XP
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
                p.league_tier AS current_tier,
                COALESCE(wxc.week_xp, 0) AS weekly_xp,
                RANK() OVER (ORDER BY COALESCE(wxc.week_xp, 0) DESC, p.xp DESC)::INTEGER AS rank
            FROM profiles p
            LEFT JOIN weekly_xp_calc wxc ON p.id = wxc.uid
            WHERE p.class_id = v_class.class_id
            AND p.role = 'student'
            ORDER BY rank
        LOOP
            -- Determine promotion/demotion
            v_result := 'stayed';
            v_new_tier := v_student.current_tier;

            -- Find current tier index
            v_current_idx := array_position(v_tier_order, v_student.current_tier);
            IF v_current_idx IS NULL THEN
                v_current_idx := 1; -- default to bronze
            END IF;

            IF v_student.rank <= v_promote_count AND v_current_idx < 5 THEN
                -- Promote (only if not already diamond)
                v_new_tier := v_tier_order[v_current_idx + 1];
                v_result := 'promoted';
            ELSIF v_student.rank > (v_class_size - v_demote_count) AND v_current_idx > 1 THEN
                -- Demote (only if not already bronze)
                v_new_tier := v_tier_order[v_current_idx - 1];
                v_result := 'demoted';
            END IF;

            -- Insert history snapshot
            INSERT INTO league_history (user_id, class_id, week_start, league_tier, rank, weekly_xp, result)
            VALUES (v_student.student_id, v_class.class_id, v_last_week_start,
                    v_new_tier, v_student.rank, v_student.weekly_xp, v_result);

            -- Update profile if tier changed
            IF v_new_tier != v_student.current_tier THEN
                UPDATE profiles SET league_tier = v_new_tier WHERE id = v_student.student_id;
            END IF;
        END LOOP;
    END LOOP;
END;
$$;

COMMENT ON FUNCTION process_weekly_league_reset IS 'Process weekly league promotion/demotion for all classes. Call every Monday 00:00 UTC.';

-- =============================================
-- Index for weekly XP calculation performance
-- =============================================
CREATE INDEX IF NOT EXISTS idx_xp_logs_created_at ON xp_logs(created_at DESC);

-- =============================================
-- UPDATE EXISTING TOTAL XP LEADERBOARD RPCs
-- Add league_tier to the return table
-- Must DROP first because return type is changing
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
-- GET USER POSITION IN CLASS (total XP)
-- =============================================
CREATE OR REPLACE FUNCTION get_user_class_position(
    p_user_id UUID,
    p_class_id UUID
)
RETURNS TABLE(
    user_id UUID,
    first_name VARCHAR,
    last_name VARCHAR,
    avatar_url VARCHAR,
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
            p.xp,
            p.level,
            RANK() OVER (ORDER BY p.xp DESC) AS rnk,
            p.league_tier
        FROM profiles p
        WHERE p.class_id = p_class_id
        AND p.role = 'student'
    )
    SELECT r.id, r.first_name, r.last_name, r.avatar_url, r.xp,
           r.level, r.rnk, r.league_tier
    FROM ranked r
    WHERE r.id = p_user_id;
END;
$$;

-- =============================================
-- GET USER POSITION IN SCHOOL (total XP)
-- =============================================
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
            p.xp,
            p.level,
            RANK() OVER (ORDER BY p.xp DESC) AS rnk,
            p.league_tier
        FROM profiles p
        LEFT JOIN classes c ON p.class_id = c.id
        WHERE p.school_id = p_school_id
        AND p.role = 'student'
    )
    SELECT r.id, r.first_name, r.last_name, r.class_name, r.avatar_url, r.xp,
           r.level, r.rnk, r.league_tier
    FROM ranked r
    WHERE r.id = p_user_id;
END;
$$;
