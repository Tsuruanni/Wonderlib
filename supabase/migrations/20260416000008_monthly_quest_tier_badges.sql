-- =============================================
-- Monthly Quest Tier Badges
--
-- Replaces the single `monthly_quests.badge_id` model with a multi-tier
-- milestone system. Each quest can have N badges (e.g. Bronze 1×, Silver 3×,
-- Gold 5×) keyed by `condition_type='monthly_quest_completed'` and
-- `condition_param=quest_id::text` with `condition_value` = required total
-- completion count.
--
-- Behaviour after this migration:
--   • Monthly quest completion reward (xp/coins/card_pack) still fires every
--     month the quest is completed (unchanged).
--   • Whenever a completion is recorded, we re-evaluate all tier badges
--     for that quest and insert any whose threshold has been reached but
--     that the user doesn't yet hold. Badge XP rewards fire via
--     award_xp_transaction, notification fires via existing INSERT trigger
--     on user_badges.
--   • RPC drops `badge_id` and `badge_awarded` columns, adds
--     `completion_count` (user's total completions across all periods for
--     this quest) so the client can render tier progress.
-- =============================================

-- 1. Extend condition_type CHECK to allow monthly_quest_completed
ALTER TABLE badges DROP CONSTRAINT IF EXISTS badges_condition_type_check;
ALTER TABLE badges ADD CONSTRAINT badges_condition_type_check
    CHECK (condition_type IN (
        'xp_total', 'streak_days', 'books_completed',
        'vocabulary_learned', 'level_completed', 'daily_login',
        'cards_collected', 'myth_category_completed', 'league_tier_reached',
        'monthly_quest_completed'
    ));

-- 2. Drop the now-obsolete single badge column on monthly_quests.
--    Tier badges are discovered dynamically via the badges table.
ALTER TABLE monthly_quests DROP COLUMN IF EXISTS badge_id;

-- 3. Rewrite get_monthly_quest_progress
--    - Drop function first because RETURNS TABLE shape changes
--      (Postgres rejects CREATE OR REPLACE when OUT cols differ).
DROP FUNCTION IF EXISTS get_monthly_quest_progress(UUID);

CREATE FUNCTION get_monthly_quest_progress(p_user_id UUID)
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
    completion_count INT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_period_key       VARCHAR(7);
    v_month_start      TIMESTAMPTZ;
    v_month_end        TIMESTAMPTZ;
    v_days_left        INT;
    v_quest            RECORD;
    v_current          INT;
    v_completed        BOOLEAN;
    v_already_awarded  BOOLEAN;
    v_newly            BOOLEAN;
    v_completion_count INT;
    v_tier             RECORD;
    v_badge_rows       INT;
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
               mq.reward_type, mq.reward_amount
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

            -- Primary quest reward (fires every month the quest is completed)
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

            v_newly := true;
            v_already_awarded := true;
        END IF;

        -- Count total completions across all periods for this (user, quest).
        SELECT COUNT(*)::INT INTO v_completion_count
        FROM monthly_quest_completions mqc
        WHERE mqc.user_id = p_user_id
          AND mqc.quest_id = v_quest.id;

        -- Award any tier badges whose threshold has been reached and the
        -- user doesn't yet hold. Idempotent: safe to call on every request.
        FOR v_tier IN
            SELECT b.id AS badge_id,
                   b.condition_value AS threshold,
                   b.xp_reward,
                   b.name AS badge_name
            FROM badges b
            WHERE b.condition_type = 'monthly_quest_completed'
              AND b.condition_param = v_quest.id::text
              AND b.condition_value <= v_completion_count
              AND b.is_active = true
            ORDER BY b.condition_value ASC
        LOOP
            INSERT INTO user_badges (user_id, badge_id)
            VALUES (p_user_id, v_tier.badge_id)
            ON CONFLICT DO NOTHING;
            GET DIAGNOSTICS v_badge_rows = ROW_COUNT;
            IF v_badge_rows > 0 AND v_tier.xp_reward > 0 THEN
                PERFORM award_xp_transaction(
                    p_user_id, v_tier.xp_reward, 'badge',
                    v_tier.badge_id, v_tier.badge_name
                );
            END IF;
        END LOOP;

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
        completion_count := v_completion_count;
        RETURN NEXT;
    END LOOP;
END;
$$;
