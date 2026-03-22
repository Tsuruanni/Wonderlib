-- =============================================
-- Daily Quest Engine
-- =============================================

-- 1. Quest definitions table
CREATE TABLE daily_quests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quest_type VARCHAR(50) NOT NULL UNIQUE,
    title VARCHAR(200) NOT NULL,
    icon VARCHAR(10),
    goal_value INTEGER NOT NULL,
    reward_type VARCHAR(50) NOT NULL CHECK (reward_type IN ('xp', 'coins', 'card_pack')),
    reward_amount INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE daily_quests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read quests"
    ON daily_quests FOR SELECT TO authenticated USING (true);

CREATE POLICY "Admins can manage quests"
    ON daily_quests FOR ALL USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- Seed data
INSERT INTO daily_quests (quest_type, title, icon, goal_value, reward_type, reward_amount, sort_order) VALUES
    ('daily_review', 'Review daily vocab', '📖', 1, 'xp', 20, 1),
    ('read_words', 'Read 100 words', '📚', 100, 'coins', 10, 2),
    ('correct_answers', 'Answer 5 questions', '✅', 5, 'xp', 15, 3);

-- 2. Quest completion records
CREATE TABLE daily_quest_completions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    quest_id UUID NOT NULL REFERENCES daily_quests(id) ON DELETE CASCADE,
    completion_date DATE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, quest_id, completion_date)
);

CREATE INDEX idx_quest_completions_user_date ON daily_quest_completions(user_id, completion_date);

ALTER TABLE daily_quest_completions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own quest completions"
    ON daily_quest_completions FOR SELECT USING (user_id = auth.uid());

-- INSERT only via SECURITY DEFINER RPCs

-- 3. Daily bonus claims (replaces daily_quest_pack_claims going forward)
CREATE TABLE daily_quest_bonus_claims (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    claim_date DATE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, claim_date)
);

ALTER TABLE daily_quest_bonus_claims ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own bonus claims"
    ON daily_quest_bonus_claims FOR SELECT USING (user_id = auth.uid());

-- 4. RPC: get_daily_quest_progress
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
                    SELECT 1 FROM daily_review_sessions
                    WHERE user_id = p_user_id AND session_date = v_today
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
                FROM inline_activity_results
                WHERE user_id = p_user_id
                  AND is_correct = true
                  AND answered_at >= v_istanbul_start;

            ELSE
                v_current := 0;
        END CASE;

        v_completed := v_current >= v_quest.goal_value;

        -- Check if already awarded
        SELECT EXISTS(
            SELECT 1 FROM daily_quest_completions
            WHERE user_id = p_user_id AND quest_id = v_quest.id AND completion_date = v_today
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

-- 5. RPC: claim_daily_bonus
CREATE OR REPLACE FUNCTION claim_daily_bonus(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_today DATE := CURRENT_DATE;
    v_active_count INT;
    v_completed_count INT;
    v_new_packs INT;
BEGIN
    -- Auth check
    IF auth.uid() != p_user_id THEN
        RAISE EXCEPTION 'unauthorized';
    END IF;

    -- Lock user row
    PERFORM id FROM profiles WHERE id = p_user_id FOR UPDATE;

    -- Count active quests
    SELECT COUNT(*) INTO v_active_count FROM daily_quests WHERE is_active = true;

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
