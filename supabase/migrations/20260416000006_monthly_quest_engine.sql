-- =============================================
-- Monthly Quest Engine
-- Mirrors daily quest architecture with calendar-month periods (Istanbul TZ).
-- =============================================

-- 1. Quest definitions table
CREATE TABLE monthly_quests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quest_type VARCHAR(50) NOT NULL UNIQUE,
    title VARCHAR(200) NOT NULL,
    icon VARCHAR(10),
    goal_value INTEGER NOT NULL CHECK (goal_value > 0),
    reward_type VARCHAR(50) NOT NULL CHECK (reward_type IN ('xp', 'coins', 'card_pack')),
    reward_amount INTEGER NOT NULL DEFAULT 0,
    badge_id UUID REFERENCES badges(id) ON DELETE SET NULL,
    is_active BOOLEAN DEFAULT true,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE monthly_quests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read monthly quests"
    ON monthly_quests FOR SELECT TO authenticated USING (true);

CREATE POLICY "Admins can manage monthly quests"
    ON monthly_quests FOR ALL USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- Seed: matches UI placeholder "Complete 20 quests"
INSERT INTO monthly_quests (quest_type, title, icon, goal_value, reward_type, reward_amount, sort_order)
VALUES ('complete_daily_quests', 'Complete 20 daily quests this month', '🏆', 20, 'card_pack', 1, 1);

-- 2. Per-user, per-period completion records
CREATE TABLE monthly_quest_completions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    quest_id UUID NOT NULL REFERENCES monthly_quests(id) ON DELETE CASCADE,
    period_key VARCHAR(7) NOT NULL,
    completed_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, quest_id, period_key)
);

CREATE INDEX idx_mqc_user_period ON monthly_quest_completions(user_id, period_key);

ALTER TABLE monthly_quest_completions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own monthly quest completions"
    ON monthly_quest_completions FOR SELECT USING (user_id = auth.uid());

-- INSERT only via SECURITY DEFINER RPCs below.

-- 3. RPC: get_monthly_quest_progress
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
                FROM daily_quest_completions
                WHERE user_id = p_user_id
                  AND completion_date >= v_month_start::date
                  AND completion_date <  v_month_end::date;

            WHEN 'read_chapters' THEN
                SELECT COUNT(DISTINCT chapter_id)::INT INTO v_current
                FROM daily_chapter_reads
                WHERE user_id = p_user_id
                  AND read_date >= v_month_start::date
                  AND read_date <  v_month_end::date;

            WHEN 'read_words' THEN
                SELECT COALESCE(SUM(COALESCE(ch.word_count, 0)), 0)::INT INTO v_current
                FROM daily_chapter_reads dcr
                JOIN chapters ch ON ch.id = dcr.chapter_id
                WHERE dcr.user_id = p_user_id
                  AND dcr.read_date >= v_month_start::date
                  AND dcr.read_date <  v_month_end::date;

            WHEN 'vocab_sessions' THEN
                SELECT COUNT(*)::INT INTO v_current
                FROM vocabulary_sessions
                WHERE user_id = p_user_id
                  AND completed_at >= v_month_start
                  AND completed_at <  v_month_end;

            WHEN 'correct_answers' THEN
                SELECT COUNT(*)::INT INTO v_current
                FROM inline_activity_results
                WHERE user_id = p_user_id
                  AND is_correct = true
                  AND answered_at >= v_month_start
                  AND answered_at <  v_month_end;

            WHEN 'daily_reviews' THEN
                SELECT COUNT(DISTINCT session_date)::INT INTO v_current
                FROM daily_review_sessions
                WHERE user_id = p_user_id
                  AND session_date >= v_month_start::date
                  AND session_date <  v_month_end::date;

            ELSE
                v_current := 0;
        END CASE;

        v_completed := v_current >= v_quest.goal_value;
        v_newly := false;
        v_badge_awarded := false;

        SELECT EXISTS(
            SELECT 1 FROM monthly_quest_completions
            WHERE user_id = p_user_id
              AND quest_id = v_quest.id
              AND period_key = v_period_key
        ) INTO v_already_awarded;

        IF v_completed AND NOT v_already_awarded THEN
            INSERT INTO monthly_quest_completions (user_id, quest_id, period_key)
            VALUES (p_user_id, v_quest.id, v_period_key)
            ON CONFLICT DO NOTHING;

            -- Primary reward
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
                    UPDATE profiles
                    SET unopened_packs = unopened_packs + v_quest.reward_amount
                    WHERE id = p_user_id;
                ELSE NULL;
            END CASE;

            -- Optional badge reward
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

COMMENT ON FUNCTION get_monthly_quest_progress IS
    'Returns monthly quest progress for the caller. Auto-awards on completion. Istanbul TZ calendar-month windowing.';
