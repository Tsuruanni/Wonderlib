-- =============================================
-- FIX: Session vocabulary_progress now uses SM2 interval growth
-- FIX: XP award is capped — only the improvement over best_score is awarded
--
-- SM2 CHANGE:
--   BEFORE: Strong words always got next_review_at = NOW() + 1 day
--   AFTER:  Intervals grow with SM2 (1d → 6d → 15d → mastered)
--
-- XP CHANGE:
--   BEFORE: Full XP awarded every session (infinite farming possible)
--   AFTER:  Only the delta above previous best_score is awarded
--           e.g. best=600, new=750 → award 150. new=500 → award 0.
-- =============================================

CREATE OR REPLACE FUNCTION complete_vocabulary_session(
    p_user_id UUID,
    p_word_list_id UUID,
    p_total_questions INTEGER,
    p_correct_count INTEGER,
    p_incorrect_count INTEGER,
    p_accuracy DECIMAL(5,2),
    p_max_combo INTEGER,
    p_xp_earned INTEGER,
    p_duration_seconds INTEGER,
    p_words_strong INTEGER,
    p_words_weak INTEGER,
    p_first_try_perfect_count INTEGER,
    p_word_results JSONB
)
RETURNS TABLE(
    session_id UUID,
    total_xp INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_session_id UUID;
    v_total_xp INTEGER;
    v_xp_to_award INTEGER;
    v_previous_best INTEGER;
    v_session_bonus INTEGER := 10;
    v_perfect_bonus INTEGER := 20;
    v_word_result JSONB;
    v_is_perfect BOOLEAN;
    v_word_id UUID;
    v_current_reps INTEGER;
    v_current_interval INTEGER;
    v_current_ease NUMERIC;
    v_new_interval INTEGER;
    v_new_status TEXT;
BEGIN
    -- Calculate total XP for this session
    v_is_perfect := (p_accuracy >= 100.0);
    v_total_xp := p_xp_earned + v_session_bonus;
    IF v_is_perfect THEN
        v_total_xp := v_total_xp + v_perfect_bonus;
    END IF;

    -- Look up previous best score for this word list
    SELECT COALESCE(best_score, 0) INTO v_previous_best
    FROM user_word_list_progress
    WHERE user_id = p_user_id AND word_list_id = p_word_list_id;

    IF NOT FOUND THEN
        v_previous_best := 0;
    END IF;

    -- Only award the improvement over previous best
    v_xp_to_award := GREATEST(0, v_total_xp - v_previous_best);

    -- Insert session record (always store the full session score)
    INSERT INTO vocabulary_sessions (
        user_id, word_list_id, total_questions, correct_count, incorrect_count,
        accuracy, max_combo, xp_earned, duration_seconds,
        words_strong, words_weak, first_try_perfect_count
    ) VALUES (
        p_user_id, p_word_list_id, p_total_questions, p_correct_count, p_incorrect_count,
        p_accuracy, p_max_combo, v_total_xp, p_duration_seconds,
        p_words_strong, p_words_weak, p_first_try_perfect_count
    ) RETURNING id INTO v_session_id;

    -- Insert per-word results and update vocabulary_progress with SM2
    FOR v_word_result IN SELECT * FROM jsonb_array_elements(p_word_results)
    LOOP
        v_word_id := (v_word_result->>'word_id')::UUID;

        INSERT INTO vocabulary_session_words (
            session_id, word_id, correct_count, incorrect_count,
            mastery_level, is_first_try_perfect
        ) VALUES (
            v_session_id,
            v_word_id,
            (v_word_result->>'correct_count')::INTEGER,
            (v_word_result->>'incorrect_count')::INTEGER,
            COALESCE(v_word_result->>'mastery_level', 'introduced'),
            COALESCE((v_word_result->>'is_first_try_perfect')::BOOLEAN, FALSE)
        );

        IF (v_word_result->>'incorrect_count')::INTEGER = 0 THEN
            -- ==========================================
            -- STRONG WORD: SM2 interval growth
            -- ==========================================
            SELECT repetitions, interval_days, ease_factor
            INTO v_current_reps, v_current_interval, v_current_ease
            FROM vocabulary_progress
            WHERE user_id = p_user_id AND word_id = v_word_id;

            IF NOT FOUND THEN
                INSERT INTO vocabulary_progress (
                    user_id, word_id, status, ease_factor,
                    interval_days, repetitions, next_review_at, last_reviewed_at
                ) VALUES (
                    p_user_id, v_word_id, 'learning', 2.50,
                    1, 1, NOW() + INTERVAL '1 day', NOW()
                );
            ELSE
                v_current_reps := v_current_reps + 1;

                IF v_current_reps = 1 THEN
                    v_new_interval := 1;
                ELSIF v_current_reps = 2 THEN
                    v_new_interval := 6;
                ELSE
                    v_new_interval := LEAST(
                        CEIL(v_current_interval * v_current_ease),
                        365
                    );
                END IF;

                IF v_new_interval > 21 THEN
                    v_new_status := 'mastered';
                ELSIF v_current_reps >= 2 THEN
                    v_new_status := 'reviewing';
                ELSE
                    v_new_status := 'learning';
                END IF;

                UPDATE vocabulary_progress SET
                    last_reviewed_at = NOW(),
                    repetitions = v_current_reps,
                    interval_days = v_new_interval,
                    ease_factor = LEAST(v_current_ease + 0.02, 3.0),
                    next_review_at = NOW() + make_interval(days => v_new_interval),
                    status = v_new_status
                WHERE user_id = p_user_id
                  AND word_id = v_word_id
                  AND status != 'mastered';
            END IF;
        ELSE
            -- ==========================================
            -- WEAK WORD: reset to immediate review
            -- ==========================================
            INSERT INTO vocabulary_progress (
                user_id, word_id, status, ease_factor,
                interval_days, repetitions, next_review_at, last_reviewed_at
            ) VALUES (
                p_user_id, v_word_id, 'learning', 2.50,
                0, 0, NOW(), NOW()
            )
            ON CONFLICT (user_id, word_id) DO UPDATE SET
                last_reviewed_at = NOW(),
                interval_days = 0,
                repetitions = 0,
                ease_factor = GREATEST(vocabulary_progress.ease_factor - 0.2, 1.3),
                next_review_at = NOW(),
                status = 'learning';
        END IF;
    END LOOP;

    -- Upsert user_word_list_progress
    INSERT INTO user_word_list_progress (
        user_id, word_list_id, best_score, best_accuracy,
        total_sessions, last_session_at, started_at, completed_at, updated_at
    ) VALUES (
        p_user_id, p_word_list_id, v_total_xp, p_accuracy,
        1, NOW(), NOW(), NOW(), NOW()
    )
    ON CONFLICT (user_id, word_list_id) DO UPDATE SET
        best_score = GREATEST(user_word_list_progress.best_score, v_total_xp),
        best_accuracy = GREATEST(user_word_list_progress.best_accuracy, p_accuracy),
        total_sessions = user_word_list_progress.total_sessions + 1,
        last_session_at = NOW(),
        completed_at = COALESCE(user_word_list_progress.completed_at, NOW()),
        updated_at = NOW();

    -- Award only the delta XP (0 if no improvement)
    IF v_xp_to_award > 0 THEN
        PERFORM award_xp_transaction(
            p_user_id,
            v_xp_to_award,
            'vocabulary_session',
            v_session_id,
            'Vocabulary session completed'
        );
    END IF;

    -- Update streak (always — even if no XP improvement, they still practiced)
    PERFORM update_user_streak(p_user_id);

    -- Check badge eligibility
    PERFORM check_and_award_badges(p_user_id);

    RETURN QUERY SELECT v_session_id, v_xp_to_award;
END;
$$;
