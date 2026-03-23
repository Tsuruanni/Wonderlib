-- Quest completion stats for admin dashboard
CREATE OR REPLACE FUNCTION get_quest_completion_stats()
RETURNS TABLE(
    quest_id UUID,
    today_completed INT,
    today_total_users INT,
    avg_daily_7d NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_students INT;
BEGIN
    -- Admin-only check
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin') THEN
        RAISE EXCEPTION 'unauthorized';
    END IF;

    -- Count total students once
    SELECT COUNT(*)::INT INTO v_total_students
    FROM profiles WHERE role = 'student';

    RETURN QUERY
    SELECT
        dq.id AS quest_id,
        COALESCE(tc.cnt, 0)::INT AS today_completed,
        v_total_students AS today_total_users,
        COALESCE(avg7.avg_completions, 0) AS avg_daily_7d
    FROM daily_quests dq
    LEFT JOIN (
        -- Today's completions per quest
        SELECT dqc.quest_id AS qid, COUNT(*)::INT AS cnt
        FROM daily_quest_completions dqc
        WHERE dqc.completion_date = CURRENT_DATE
        GROUP BY dqc.quest_id
    ) tc ON tc.qid = dq.id
    LEFT JOIN (
        -- 7-day average completions per quest
        SELECT
            sub.qid,
            (SUM(sub.daily_cnt)::NUMERIC / 7) AS avg_completions
        FROM (
            SELECT dqc.quest_id AS qid, dqc.completion_date, COUNT(*) AS daily_cnt
            FROM daily_quest_completions dqc
            WHERE dqc.completion_date >= CURRENT_DATE - 6
            GROUP BY dqc.quest_id, dqc.completion_date
        ) sub
        GROUP BY sub.qid
    ) avg7 ON avg7.qid = dq.id
    ORDER BY dq.sort_order;
END;
$$;
