-- =============================================
-- Extend Badge Conditions
-- 1. Add condition_param VARCHAR(50) NULL to badges (for category slug, tier name, etc.)
-- 2. Extend condition_type CHECK constraint with 3 new values
-- 3. Rewrite check_and_award_badges RPC with 3 new OR branches
-- =============================================

-- 1. Add column
ALTER TABLE badges
    ADD COLUMN IF NOT EXISTS condition_param VARCHAR(50);

COMMENT ON COLUMN badges.condition_param IS
    'Optional string parameter for condition types that need it (e.g., category slug, league tier name)';

-- 2. Extend CHECK constraint: drop old, add new
ALTER TABLE badges DROP CONSTRAINT IF EXISTS badges_condition_type_check;

ALTER TABLE badges ADD CONSTRAINT badges_condition_type_check
    CHECK (condition_type IN (
        'xp_total', 'streak_days', 'books_completed',
        'vocabulary_learned', 'perfect_scores',
        'level_completed', 'daily_login',
        -- New:
        'cards_collected', 'myth_category_completed', 'league_tier_reached'
    ));

-- 3. Rewrite RPC — return type unchanged, so CREATE OR REPLACE is safe
CREATE OR REPLACE FUNCTION check_and_award_badges(p_user_id UUID)
RETURNS TABLE(badge_id UUID, badge_name VARCHAR, badge_icon VARCHAR, xp_reward INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_profile profiles%ROWTYPE;
    v_books_completed INTEGER;
    v_vocab_learned INTEGER;
    v_perfect_scores INTEGER;
    v_cards_collected INTEGER;
    v_current_tier_ordinal INTEGER;
    v_awarded RECORD;
    v_tier_order CONSTANT TEXT[] :=
        ARRAY['bronze', 'silver', 'gold', 'platinum', 'diamond'];
BEGIN
    -- Auth check: ensure caller is the user they claim to be
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Not authorized: user mismatch';
    END IF;

    -- Get user profile
    SELECT * INTO v_profile FROM profiles WHERE id = p_user_id;
    IF NOT FOUND THEN RETURN; END IF;

    -- Existing stats
    SELECT COUNT(*) INTO v_books_completed
    FROM reading_progress WHERE user_id = p_user_id AND is_completed = TRUE;

    SELECT COUNT(*) INTO v_vocab_learned
    FROM vocabulary_progress WHERE user_id = p_user_id AND status = 'mastered';

    SELECT COUNT(*) INTO v_perfect_scores
    FROM activity_results WHERE user_id = p_user_id AND score = max_score;

    -- New stat: distinct cards collected (UNIQUE(user_id, card_id) guarantees distinctness)
    SELECT COUNT(*) INTO v_cards_collected
    FROM user_cards WHERE user_id = p_user_id;

    -- New stat: current tier ordinal (1=bronze .. 5=diamond, 0=unknown)
    v_current_tier_ordinal := COALESCE(
        array_position(v_tier_order, v_profile.league_tier),
        0
    );

    -- Set-based INSERT for all qualifying badges
    FOR v_awarded IN
        INSERT INTO user_badges (user_id, badge_id)
        SELECT p_user_id, b.id
        FROM badges b
        WHERE b.is_active = TRUE
        AND NOT EXISTS (
            SELECT 1 FROM user_badges ub
            WHERE ub.user_id = p_user_id AND ub.badge_id = b.id
        )
        AND (
            (b.condition_type = 'xp_total' AND v_profile.xp >= b.condition_value) OR
            (b.condition_type = 'streak_days' AND v_profile.current_streak >= b.condition_value) OR
            (b.condition_type = 'books_completed' AND v_books_completed >= b.condition_value) OR
            (b.condition_type = 'vocabulary_learned' AND v_vocab_learned >= b.condition_value) OR
            (b.condition_type = 'perfect_scores' AND v_perfect_scores >= b.condition_value) OR
            (b.condition_type = 'level_completed' AND v_profile.level >= b.condition_value) OR
            -- New branches:
            (b.condition_type = 'cards_collected'
                AND v_cards_collected >= b.condition_value) OR
            (b.condition_type = 'myth_category_completed'
                AND b.condition_param IS NOT NULL
                AND (
                    SELECT COUNT(*) FROM user_cards uc
                    JOIN myth_cards mc ON mc.id = uc.card_id
                    WHERE uc.user_id = p_user_id
                      AND mc.category = b.condition_param
                ) >= b.condition_value) OR
            (b.condition_type = 'league_tier_reached'
                AND b.condition_param IS NOT NULL
                AND v_current_tier_ordinal >=
                    COALESCE(array_position(v_tier_order, b.condition_param), 0)
                AND v_current_tier_ordinal > 0)
        )
        ON CONFLICT DO NOTHING
        RETURNING user_badges.badge_id
    LOOP
        -- Award XP for each newly earned badge
        SELECT b.id, b.name, b.icon, b.xp_reward
        INTO badge_id, badge_name, badge_icon, xp_reward
        FROM badges b WHERE b.id = v_awarded.badge_id;

        IF xp_reward > 0 THEN
            PERFORM award_xp_transaction(
                p_user_id, xp_reward, 'badge', v_awarded.badge_id,
                'Earned: ' || badge_name
            );
        END IF;

        RETURN NEXT;
    END LOOP;
END;
$$;

COMMENT ON FUNCTION check_and_award_badges IS
    'Check and award badges with auth verification. Supports xp, streak, books, vocab, perfect_scores, level, cards_collected, myth_category_completed, league_tier_reached. Returns badge_id, badge_name, badge_icon, xp_reward';
