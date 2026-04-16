-- =============================================
-- Fix: column reference "quest_id" is ambiguous
-- Cause: RETURNS TABLE(quest_id UUID, period_key VARCHAR, badge_id UUID, ...)
-- declares OUT columns that shadow table columns inside sub-SELECTs.
-- Fix: qualify all column references with table aliases.
-- =============================================

CREATE OR REPLACE FUNCTION get_monthly_quest_progress(p_user_id UUID)
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
    newly_completed BOOLEAN,
    period_key VARCHAR,
    days_left INT,
    badge_id UUID,
    badge_awarded BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_period_key  VARCHAR(7);
    v_month_start TIMESTAMPTZ;
    v_month_end   TIMESTAMPTZ;
    v_days_left   INT;
    v_quest RECORD;
    v_current INT;
    v_completed BOOLEAN;
    v_already_awarded BOOLEAN;
    v_newly BOOLEAN;
    v_badge_awarded BOOLEAN;
    v_badge_rows INT;
    v_badge_xp INT;
    v_badge_name VARCHAR;
BEGIN
    IF auth.uid() != p_user_id THEN
        RAISE EXCEPTION 'unauthorized';
    END IF;

    v_period_key  := to_char(NOW() AT TIME ZONE 'Europe/Istanbul', 'YYYY-MM');
    v_month_start := date_trunc('month', NOW() AT TIME ZONE 'Europe/Istanbul')
                       AT TIME ZONE 'Europe/Istanbul';
    v_month_end   := v_month_start + INTERVAL '1 month';
    v_days_left   := (v_month_end::date - 1) - (NOW() AT TIME ZONE 'Europe/Istanbul')::date;

    FOR v_quest IN
        SELECT mq.id, mq.quest_type, mq.title, mq.icon, mq.goal_value,
               mq.reward_type, mq.reward_amount, mq.badge_id
        FROM monthly_quests mq
        WHERE mq.is_active = true
        ORDER BY mq.sort_order
    LOOP
        CASE v_quest.quest_type
            WHEN 'complete_daily_quests' THEN
                SELECT COUNT(*)::INT INTO v_current
                FROM daily_quest_completions dqc
                WHERE dqc.user_id = p_user_id
                  AND dqc.completion_date >= v_month_start::date
                  AND dqc.completion_date <  v_month_end::date;

            WHEN 'read_chapters' THEN
                SELECT COUNT(DISTINCT dcr.chapter_id)::INT INTO v_current
                FROM daily_chapter_reads dcr
                WHERE dcr.user_id = p_user_id
                  AND dcr.read_date >= v_month_start::date
                  AND dcr.read_date <  v_month_end::date;

            WHEN 'read_words' THEN
                SELECT COALESCE(SUM(COALESCE(ch.word_count, 0)), 0)::INT INTO v_current
                FROM daily_chapter_reads dcr
                JOIN chapters ch ON ch.id = dcr.chapter_id
                WHERE dcr.user_id = p_user_id
                  AND dcr.read_date >= v_month_start::date
                  AND dcr.read_date <  v_month_end::date;

            WHEN 'vocab_sessions' THEN
                SELECT COUNT(*)::INT INTO v_current
                FROM vocabulary_sessions vs
                WHERE vs.user_id = p_user_id
                  AND vs.completed_at >= v_month_start
                  AND vs.completed_at <  v_month_end;

            WHEN 'correct_answers' THEN
                SELECT COUNT(*)::INT INTO v_current
                FROM inline_activity_results iar
                WHERE iar.user_id = p_user_id
                  AND iar.is_correct = true
                  AND iar.answered_at >= v_month_start
                  AND iar.answered_at <  v_month_end;

            WHEN 'daily_reviews' THEN
                SELECT COUNT(DISTINCT drs.session_date)::INT INTO v_current
                FROM daily_review_sessions drs
                WHERE drs.user_id = p_user_id
                  AND drs.session_date >= v_month_start::date
                  AND drs.session_date <  v_month_end::date;

            ELSE
                v_current := 0;
        END CASE;

        v_completed := v_current >= v_quest.goal_value;
        v_newly := false;
        v_badge_awarded := false;

        SELECT EXISTS(
            SELECT 1 FROM monthly_quest_completions mqc
            WHERE mqc.user_id = p_user_id
              AND mqc.quest_id = v_quest.id
              AND mqc.period_key = v_period_key
        ) INTO v_already_awarded;

        IF v_completed AND NOT v_already_awarded THEN
            INSERT INTO monthly_quest_completions (user_id, quest_id, period_key)
            VALUES (p_user_id, v_quest.id, v_period_key)
            ON CONFLICT DO NOTHING;

            CASE v_quest.reward_type
                WHEN 'xp' THEN
                    PERFORM award_xp_transaction(
                        p_user_id, v_quest.reward_amount, 'monthly_quest',
                        v_quest.id, v_quest.title
                    );
                WHEN 'coins' THEN
                    PERFORM award_coins_transaction(
                        p_user_id, v_quest.reward_amount, 'monthly_quest',
                        v_quest.id, v_quest.title
                    );
                WHEN 'card_pack' THEN
                    UPDATE profiles p
                    SET unopened_packs = p.unopened_packs + v_quest.reward_amount
                    WHERE p.id = p_user_id;
                ELSE NULL;
            END CASE;

            IF v_quest.badge_id IS NOT NULL THEN
                INSERT INTO user_badges (user_id, badge_id)
                VALUES (p_user_id, v_quest.badge_id)
                ON CONFLICT DO NOTHING;
                GET DIAGNOSTICS v_badge_rows = ROW_COUNT;
                IF v_badge_rows > 0 THEN
                    v_badge_awarded := true;
                    SELECT b.xp_reward, b.name INTO v_badge_xp, v_badge_name
                    FROM badges b WHERE b.id = v_quest.badge_id;
                    IF v_badge_xp > 0 THEN
                        PERFORM award_xp_transaction(
                            p_user_id, v_badge_xp, 'badge',
                            v_quest.badge_id, v_badge_name
                        );
                    END IF;
                END IF;
            END IF;

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
        period_key := v_period_key;
        days_left := v_days_left;
        badge_id := v_quest.badge_id;
        badge_awarded := v_badge_awarded;
        RETURN NEXT;
    END LOOP;
END;
$$;
