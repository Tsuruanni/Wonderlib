-- Fix ambiguous column reference in get_daily_quest_progress RPC
-- The RETURNS TABLE column names (quest_id, quest_type, etc.) clash with
-- table column names in subqueries, causing "column reference is ambiguous" errors.
-- Solution: use explicit table aliases in all subqueries.

CREATE OR REPLACE FUNCTION get_daily_quest_progress(p_user_id UUID)
RETURNS TABLE(
    quest_id UUID,
    quest_type VARCHAR,
    title VARCHAR,
    icon VARCHAR,
    goal_value INT,
    current_value INT,
    is_completed BOOLEAN,
    reward_type VARCHAR,
    reward_amount INT,
    reward_awarded BOOLEAN,
    newly_completed BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_today DATE := CURRENT_DATE;
    v_istanbul_start TIMESTAMPTZ := date_trunc('day', NOW() AT TIME ZONE 'Europe/Istanbul') AT TIME ZONE 'Europe/Istanbul';
    v_quest RECORD;
    v_current INT;
    v_completed BOOLEAN;
    v_already_awarded BOOLEAN;
    v_newly BOOLEAN;
BEGIN
    -- Auth check
    IF auth.uid() != p_user_id THEN
        RAISE EXCEPTION 'unauthorized';
    END IF;

    FOR v_quest IN
        SELECT dq.id, dq.quest_type, dq.title, dq.icon, dq.goal_value, dq.reward_type, dq.reward_amount
        FROM daily_quests dq
        WHERE dq.is_active = true
        ORDER BY dq.sort_order
    LOOP
        -- Calculate current_value per quest type
        CASE v_quest.quest_type
            WHEN 'daily_review' THEN
                SELECT CASE WHEN EXISTS(
                    SELECT 1 FROM daily_review_sessions drs
                    WHERE drs.user_id = p_user_id AND drs.session_date = v_today
                ) THEN 1 ELSE 0 END INTO v_current;

            WHEN 'read_words' THEN
                SELECT COALESCE(SUM(COALESCE(ch.word_count, 0)), 0)
                INTO v_current
                FROM daily_chapter_reads dcr
                JOIN chapters ch ON ch.id = dcr.chapter_id
                WHERE dcr.user_id = p_user_id AND dcr.read_date = v_today;

            WHEN 'correct_answers' THEN
                SELECT COUNT(*)::INT
                INTO v_current
                FROM inline_activity_results iar
                WHERE iar.user_id = p_user_id
                  AND iar.is_correct = true
                  AND iar.answered_at >= v_istanbul_start;

            ELSE
                v_current := 0;
        END CASE;

        v_completed := v_current >= v_quest.goal_value;

        -- Check if already awarded (use explicit alias to avoid ambiguity with RETURNS TABLE columns)
        SELECT EXISTS(
            SELECT 1 FROM daily_quest_completions dqc
            WHERE dqc.user_id = p_user_id AND dqc.quest_id = v_quest.id AND dqc.completion_date = v_today
        ) INTO v_already_awarded;

        v_newly := false;

        -- Auto-complete and award if newly completed
        IF v_completed AND NOT v_already_awarded THEN
            INSERT INTO daily_quest_completions (user_id, quest_id, completion_date)
            VALUES (p_user_id, v_quest.id, v_today)
            ON CONFLICT DO NOTHING;

            -- Award reward
            CASE v_quest.reward_type
                WHEN 'xp' THEN
                    PERFORM award_xp_transaction(
                        p_user_id, v_quest.reward_amount, 'daily_quest',
                        v_quest.id, v_quest.title
                    );
                WHEN 'coins' THEN
                    PERFORM award_coins_transaction(
                        p_user_id, v_quest.reward_amount, 'daily_quest',
                        v_quest.id, v_quest.title
                    );
                WHEN 'card_pack' THEN
                    UPDATE profiles SET unopened_packs = unopened_packs + v_quest.reward_amount
                    WHERE id = p_user_id;
                ELSE NULL;
            END CASE;

            v_newly := true;
            v_already_awarded := true;
        END IF;

        quest_id := v_quest.id;
        quest_type := v_quest.quest_type;
        title := v_quest.title;
        icon := v_quest.icon;
        goal_value := v_quest.goal_value;
        current_value := v_current;
        is_completed := v_completed;
        reward_type := v_quest.reward_type;
        reward_amount := v_quest.reward_amount;
        reward_awarded := v_already_awarded;
        newly_completed := v_newly;
        RETURN NEXT;
    END LOOP;
END;
$$;
