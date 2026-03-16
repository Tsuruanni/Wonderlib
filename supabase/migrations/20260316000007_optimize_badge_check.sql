-- Optimize check_and_award_badges: set-based INSERT instead of FOR LOOP
-- Performance: single query instead of N iterations over all badges

CREATE OR REPLACE FUNCTION check_and_award_badges(p_user_id UUID)
RETURNS TABLE(badge_id UUID, badge_name VARCHAR, xp_reward INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_profile profiles%ROWTYPE;
    v_books_completed INTEGER;
    v_vocab_learned INTEGER;
    v_perfect_scores INTEGER;
    v_awarded RECORD;
BEGIN
    -- Get user profile
    SELECT * INTO v_profile FROM profiles WHERE id = p_user_id;
    IF NOT FOUND THEN RETURN; END IF;

    -- Get stats
    SELECT COUNT(*) INTO v_books_completed
    FROM reading_progress WHERE user_id = p_user_id AND is_completed = TRUE;

    SELECT COUNT(*) INTO v_vocab_learned
    FROM vocabulary_progress WHERE user_id = p_user_id AND status = 'mastered';

    SELECT COUNT(*) INTO v_perfect_scores
    FROM activity_results WHERE user_id = p_user_id AND score = max_score;

    -- Single set-based INSERT for all qualifying badges
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
            (b.condition_type = 'level_completed' AND v_profile.level >= b.condition_value)
        )
        ON CONFLICT DO NOTHING
        RETURNING user_badges.badge_id
    LOOP
        -- Award XP for each newly earned badge
        SELECT b.id, b.name, b.xp_reward
        INTO badge_id, badge_name, xp_reward
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
