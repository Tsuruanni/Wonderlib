-- Fix: daily_review quest should not appear (and not award XP) when user has < 10 due words.
-- This aligns the DB threshold with the Flutter UI threshold (minDailyReviewCount = 10).
-- Also fixes claim_daily_bonus to not require daily_review completion when quest is skipped.

-- =============================================
-- A. get_daily_quest_progress — skip daily_review when < 10 due words
-- Base: 20260323000006 (app_current_date/app_now version)
-- =============================================
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
    v_today DATE := app_current_date();
    v_istanbul_start TIMESTAMPTZ := date_trunc('day', app_now() AT TIME ZONE 'Europe/Istanbul') AT TIME ZONE 'Europe/Istanbul';
    v_quest RECORD;
    v_current INT;
    v_completed BOOLEAN;
    v_already_awarded BOOLEAN;
    v_newly BOOLEAN;
    v_due_word_count INT;
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
                -- Count non-mastered words due for review
                SELECT COUNT(*)::INT
                INTO v_due_word_count
                FROM vocabulary_progress vp
                WHERE vp.user_id = p_user_id
                  AND vp.next_review_at <= app_now()
                  AND vp.status != 'mastered';

                -- Skip quest entirely if user has fewer than 10 due words
                -- (aligns with Flutter UI minDailyReviewCount = 10)
                IF v_due_word_count < 10 THEN
                    CONTINUE;
                END IF;

                -- Check if review session completed today
                SELECT CASE WHEN EXISTS(
                    SELECT 1 FROM daily_review_sessions drs
                    WHERE drs.user_id = p_user_id AND drs.session_date = v_today
                ) THEN 1 ELSE 0 END INTO v_current;

            WHEN 'read_chapters' THEN
                SELECT COUNT(*)::INT
                INTO v_current
                FROM daily_chapter_reads dcr
                WHERE dcr.user_id = p_user_id AND dcr.read_date = v_today;

            WHEN 'vocab_session' THEN
                SELECT COUNT(*)::INT
                INTO v_current
                FROM vocabulary_sessions vs
                WHERE vs.user_id = p_user_id
                  AND vs.completed_at >= v_istanbul_start;

            -- Legacy types (kept for backward compat, won't match active quests)
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

        -- Check if already awarded
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

-- =============================================
-- B. claim_daily_bonus — exclude daily_review from required count
--    when user has < 10 due words (same eligibility logic)
-- Base: 20260323000006 (app_current_date version)
-- =============================================
CREATE OR REPLACE FUNCTION claim_daily_bonus(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_today DATE := app_current_date();
    v_active_count INT;
    v_completed_count INT;
    v_new_packs INT;
    v_due_word_count INT;
BEGIN
    -- Auth check
    IF auth.uid() != p_user_id THEN
        RAISE EXCEPTION 'unauthorized';
    END IF;

    -- Lock user row
    PERFORM id FROM profiles WHERE id = p_user_id FOR UPDATE;

    -- Count active quests, excluding daily_review if user has < 10 due words
    SELECT COUNT(*)::INT
    INTO v_due_word_count
    FROM vocabulary_progress vp
    WHERE vp.user_id = p_user_id
      AND vp.next_review_at <= app_now()
      AND vp.status != 'mastered';

    SELECT COUNT(*) INTO v_active_count
    FROM daily_quests
    WHERE is_active = true
      AND NOT (quest_type = 'daily_review' AND v_due_word_count < 10);

    -- Count completed quests today
    SELECT COUNT(*) INTO v_completed_count
    FROM daily_quest_completions dqc
    JOIN daily_quests dq ON dq.id = dqc.quest_id
    WHERE dqc.user_id = p_user_id
      AND dqc.completion_date = v_today
      AND dq.is_active = true;

    IF v_completed_count < v_active_count THEN
        RAISE EXCEPTION 'Not all quests completed';
    END IF;

    -- Check already claimed
    IF EXISTS(SELECT 1 FROM daily_quest_bonus_claims WHERE user_id = p_user_id AND claim_date = v_today) THEN
        RAISE EXCEPTION 'Bonus already claimed today';
    END IF;

    -- Claim
    INSERT INTO daily_quest_bonus_claims (user_id, claim_date) VALUES (p_user_id, v_today);

    -- Award pack
    UPDATE profiles SET unopened_packs = unopened_packs + 1 WHERE id = p_user_id
    RETURNING unopened_packs INTO v_new_packs;

    RETURN jsonb_build_object('success', true, 'unopened_packs', v_new_packs);
END;
$$;
