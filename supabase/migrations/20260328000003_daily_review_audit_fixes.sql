-- Daily Review Audit Fixes
-- #1: Add auth check to complete_daily_review (Critical)
-- #2: Add auth check to get_due_review_words (Medium)
-- #15: Add status != 'mastered' filter to align with partial index

-- Fix #1: complete_daily_review — add auth.uid() check
CREATE OR REPLACE FUNCTION complete_daily_review(
    p_user_id UUID,
    p_words_reviewed INTEGER,
    p_correct_count INTEGER,
    p_incorrect_count INTEGER
)
RETURNS TABLE(
    session_id UUID,
    total_xp INTEGER,
    is_new_session BOOLEAN,
    is_perfect BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_existing_session daily_review_sessions%ROWTYPE;
    v_base_xp INTEGER;
    v_session_bonus INTEGER := 10;
    v_perfect_bonus INTEGER := 20;
    v_total_xp INTEGER;
    v_is_perfect BOOLEAN;
    v_session_id UUID;
BEGIN
    -- Auth check: user can only complete own daily review
    IF auth.uid() != p_user_id THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    SELECT * INTO v_existing_session
    FROM daily_review_sessions
    WHERE user_id = p_user_id AND session_date = app_current_date();

    IF v_existing_session.id IS NOT NULL THEN
        RETURN QUERY SELECT
            v_existing_session.id,
            0::INTEGER,
            FALSE,
            v_existing_session.is_perfect;
        RETURN;
    END IF;

    v_base_xp := p_correct_count * 5;
    v_is_perfect := (p_correct_count = p_words_reviewed AND p_incorrect_count = 0 AND p_words_reviewed > 0);

    v_total_xp := v_base_xp + v_session_bonus;
    IF v_is_perfect THEN
        v_total_xp := v_total_xp + v_perfect_bonus;
    END IF;

    INSERT INTO daily_review_sessions (
        user_id, session_date, words_reviewed, correct_count,
        incorrect_count, xp_earned, is_perfect
    ) VALUES (
        p_user_id, app_current_date(), p_words_reviewed, p_correct_count,
        p_incorrect_count, v_total_xp, v_is_perfect
    ) RETURNING id INTO v_session_id;

    PERFORM award_xp_transaction(
        p_user_id, v_total_xp, 'daily_review',
        v_session_id, 'Daily vocabulary review completed'
    );

    -- Streak removed: now login-based (checked on app open)

    PERFORM check_and_award_badges(p_user_id);

    RETURN QUERY SELECT v_session_id, v_total_xp, TRUE, v_is_perfect;
END;
$$;

-- Fix #2 + #15: get_due_review_words — add auth check + mastered filter
-- Rewrite from sql to plpgsql for auth check support.
-- Adding status != 'mastered' enables partial index idx_vocabulary_progress_review.
CREATE OR REPLACE FUNCTION get_due_review_words(
    p_user_id UUID,
    p_limit INT DEFAULT 30
)
RETURNS SETOF vocabulary_words
LANGUAGE plpgsql STABLE SECURITY DEFINER
AS $$
BEGIN
    -- Auth check: user can only fetch own due words
    IF auth.uid() != p_user_id THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    RETURN QUERY
    SELECT vw.*
    FROM vocabulary_words vw
    INNER JOIN vocabulary_progress vp ON vp.word_id = vw.id
    WHERE vp.user_id = p_user_id
      AND vp.next_review_at <= NOW()
      AND vp.status != 'mastered'
    ORDER BY vp.next_review_at ASC
    LIMIT p_limit;
END;
$$;
