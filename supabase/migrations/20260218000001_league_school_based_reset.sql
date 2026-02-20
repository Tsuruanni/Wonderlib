-- =============================================
-- LEAGUE SYSTEM: Change from class-based to school-based
-- Students compete within their school, not just their class
-- =============================================

-- 1. Add school_id to league_history
ALTER TABLE league_history ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES schools(id) ON DELETE SET NULL;

-- 2. Index for school-based queries
CREATE INDEX IF NOT EXISTS idx_league_history_school_week ON league_history(week_start, school_id);

-- 3. RLS: Students can read league history for their school
CREATE POLICY "Users can read school league history"
    ON league_history FOR SELECT
    USING (
        school_id IN (
            SELECT school_id FROM profiles WHERE id = auth.uid()
        )
    );

-- 4. Rewrite process_weekly_league_reset() to be school-based
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
    v_student RECORD;
    v_school_size INTEGER;
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

    -- Process each school
    FOR v_school IN
        SELECT DISTINCT p.school_id
        FROM profiles p
        WHERE p.role = 'student'
        AND p.school_id IS NOT NULL
    LOOP
        -- Count students in this school
        SELECT COUNT(*) INTO v_school_size
        FROM profiles
        WHERE school_id = v_school.school_id AND role = 'student';

        -- Determine promotion/demotion counts based on school size
        IF v_school_size < 10 THEN
            v_promote_count := 1;
            v_demote_count := 1;
        ELSIF v_school_size <= 25 THEN
            v_promote_count := 2;
            v_demote_count := 2;
        ELSIF v_school_size <= 50 THEN
            v_promote_count := 3;
            v_demote_count := 3;
        ELSE
            v_promote_count := 5;
            v_demote_count := 5;
        END IF;

        -- Rank students by weekly XP within the school
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
            ELSIF v_student.rank > (v_school_size - v_demote_count) AND v_current_idx > 1 THEN
                -- Demote (only if not already bronze)
                v_new_tier := v_tier_order[v_current_idx - 1];
                v_result := 'demoted';
            END IF;

            -- Insert history snapshot (school_id + class_id for reference)
            INSERT INTO league_history (user_id, class_id, school_id, week_start, league_tier, rank, weekly_xp, result)
            VALUES (v_student.student_id, v_student.student_class_id, v_school.school_id,
                    v_last_week_start, v_new_tier, v_student.rank, v_student.weekly_xp, v_result);

            -- Update profile if tier changed
            IF v_new_tier != v_student.current_tier THEN
                UPDATE profiles SET league_tier = v_new_tier WHERE id = v_student.student_id;
            END IF;
        END LOOP;
    END LOOP;
END;
$$;

COMMENT ON FUNCTION process_weekly_league_reset IS 'Process weekly league promotion/demotion for all schools. Call every Monday 00:00 UTC.';
