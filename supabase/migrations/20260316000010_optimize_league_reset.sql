-- Optimize process_weekly_league_reset: single-pass XP aggregation
-- Previously: nested loops (school × tier) each running their own xp_logs aggregation
-- Now: aggregate XP once into temp table, then process tier assignments

CREATE OR REPLACE FUNCTION process_weekly_league_reset()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_last_week_start DATE := (date_trunc('week', NOW()) - INTERVAL '7 days')::DATE;
    v_last_week_ts TIMESTAMPTZ := date_trunc('week', NOW()) - INTERVAL '7 days';
    v_this_week_ts TIMESTAMPTZ := date_trunc('week', NOW());
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
    -- Skip if already processed this week
    IF EXISTS (SELECT 1 FROM league_history WHERE week_start = v_last_week_start LIMIT 1) THEN
        RAISE NOTICE 'Week % already processed', v_last_week_start;
        RETURN;
    END IF;

    -- Step 1: Pre-aggregate ALL weekly XP in a single pass
    CREATE TEMP TABLE IF NOT EXISTS tmp_weekly_xp AS
    SELECT
        xl.user_id,
        COALESCE(SUM(xl.amount), 0)::BIGINT AS week_xp
    FROM xp_logs xl
    WHERE xl.created_at >= v_last_week_ts
    AND xl.created_at < v_this_week_ts
    GROUP BY xl.user_id;

    CREATE INDEX IF NOT EXISTS idx_tmp_weekly_xp_user ON tmp_weekly_xp(user_id);

    -- Step 2: Process each school × tier (using pre-aggregated data)
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

    -- Cleanup temp table
    DROP TABLE IF EXISTS tmp_weekly_xp;
END;
$$;
