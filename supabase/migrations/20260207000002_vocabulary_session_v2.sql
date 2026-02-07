-- =============================================
-- VOCABULARY SESSION V2
-- Replaces 4-phase system with adaptive session flow
-- =============================================

-- =============================================
-- 1. MODIFY user_word_list_progress
-- Drop old phase columns, add session-based tracking
-- =============================================

ALTER TABLE user_word_list_progress
    DROP COLUMN IF EXISTS phase1_complete,
    DROP COLUMN IF EXISTS phase2_complete,
    DROP COLUMN IF EXISTS phase3_complete,
    DROP COLUMN IF EXISTS phase4_complete,
    DROP COLUMN IF EXISTS phase4_score,
    DROP COLUMN IF EXISTS phase4_total;

ALTER TABLE user_word_list_progress
    ADD COLUMN best_score INTEGER,
    ADD COLUMN best_accuracy DECIMAL(5,2),
    ADD COLUMN total_sessions INTEGER DEFAULT 0,
    ADD COLUMN last_session_at TIMESTAMPTZ;

COMMENT ON TABLE user_word_list_progress IS 'Session-based vocabulary learning progress per user per list';
COMMENT ON COLUMN user_word_list_progress.best_score IS 'Highest XP earned in a single session';
COMMENT ON COLUMN user_word_list_progress.best_accuracy IS 'Highest accuracy percentage achieved';
COMMENT ON COLUMN user_word_list_progress.total_sessions IS 'Number of completed sessions';
COMMENT ON COLUMN user_word_list_progress.last_session_at IS 'When the last session was completed';

-- =============================================
-- 2. CREATE vocabulary_sessions
-- Stores each completed learning session
-- =============================================

CREATE TABLE vocabulary_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    word_list_id UUID NOT NULL REFERENCES word_lists(id) ON DELETE CASCADE,
    total_questions INTEGER NOT NULL DEFAULT 0,
    correct_count INTEGER NOT NULL DEFAULT 0,
    incorrect_count INTEGER NOT NULL DEFAULT 0,
    accuracy DECIMAL(5,2) NOT NULL DEFAULT 0,
    max_combo INTEGER NOT NULL DEFAULT 0,
    xp_earned INTEGER NOT NULL DEFAULT 0,
    duration_seconds INTEGER NOT NULL DEFAULT 0,
    words_strong INTEGER NOT NULL DEFAULT 0,
    words_weak INTEGER NOT NULL DEFAULT 0,
    first_try_perfect_count INTEGER NOT NULL DEFAULT 0,
    completed_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE vocabulary_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own vocabulary sessions"
    ON vocabulary_sessions FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own vocabulary sessions"
    ON vocabulary_sessions FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE INDEX idx_vocabulary_sessions_user_list
    ON vocabulary_sessions(user_id, word_list_id, completed_at DESC);

COMMENT ON TABLE vocabulary_sessions IS 'Completed vocabulary learning sessions with scores and stats';

-- =============================================
-- 3. CREATE vocabulary_session_words
-- Per-word results within a session
-- =============================================

CREATE TABLE vocabulary_session_words (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES vocabulary_sessions(id) ON DELETE CASCADE,
    word_id UUID NOT NULL REFERENCES vocabulary_words(id) ON DELETE CASCADE,
    correct_count INTEGER NOT NULL DEFAULT 0,
    incorrect_count INTEGER NOT NULL DEFAULT 0,
    mastery_level VARCHAR(20) NOT NULL DEFAULT 'introduced'
        CHECK (mastery_level IN ('introduced', 'recognized', 'bridged', 'produced')),
    is_first_try_perfect BOOLEAN DEFAULT TRUE,

    UNIQUE(session_id, word_id)
);

ALTER TABLE vocabulary_session_words ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own session words"
    ON vocabulary_session_words FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM vocabulary_sessions vs
            WHERE vs.id = vocabulary_session_words.session_id
            AND vs.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert own session words"
    ON vocabulary_session_words FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM vocabulary_sessions vs
            WHERE vs.id = vocabulary_session_words.session_id
            AND vs.user_id = auth.uid()
        )
    );

CREATE INDEX idx_vocabulary_session_words_session
    ON vocabulary_session_words(session_id);

COMMENT ON TABLE vocabulary_session_words IS 'Per-word mastery results within a vocabulary session';

-- =============================================
-- 4. RPC: complete_vocabulary_session
-- Atomic session completion with XP award
-- =============================================
-- XP Formula:
--   Base: per-question XP (varies by type, calculated client-side)
--   Combo multiplier applied client-side
--   Session bonus: +10 XP
--   Perfect bonus: +20 XP (100% accuracy)
-- Also:
--   Updates user_word_list_progress
--   Adds words to vocabulary_progress for spaced repetition
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
    p_word_results JSONB  -- [{word_id, correct_count, incorrect_count, mastery_level, is_first_try_perfect}]
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
    v_session_bonus INTEGER := 10;
    v_perfect_bonus INTEGER := 20;
    v_word_result JSONB;
    v_is_perfect BOOLEAN;
BEGIN
    -- Calculate total XP
    v_is_perfect := (p_accuracy >= 100.0);
    v_total_xp := p_xp_earned + v_session_bonus;
    IF v_is_perfect THEN
        v_total_xp := v_total_xp + v_perfect_bonus;
    END IF;

    -- Insert session record
    INSERT INTO vocabulary_sessions (
        user_id, word_list_id, total_questions, correct_count, incorrect_count,
        accuracy, max_combo, xp_earned, duration_seconds,
        words_strong, words_weak, first_try_perfect_count
    ) VALUES (
        p_user_id, p_word_list_id, p_total_questions, p_correct_count, p_incorrect_count,
        p_accuracy, p_max_combo, v_total_xp, p_duration_seconds,
        p_words_strong, p_words_weak, p_first_try_perfect_count
    ) RETURNING id INTO v_session_id;

    -- Insert per-word results
    FOR v_word_result IN SELECT * FROM jsonb_array_elements(p_word_results)
    LOOP
        INSERT INTO vocabulary_session_words (
            session_id, word_id, correct_count, incorrect_count,
            mastery_level, is_first_try_perfect
        ) VALUES (
            v_session_id,
            (v_word_result->>'word_id')::UUID,
            (v_word_result->>'correct_count')::INTEGER,
            (v_word_result->>'incorrect_count')::INTEGER,
            COALESCE(v_word_result->>'mastery_level', 'introduced'),
            COALESCE((v_word_result->>'is_first_try_perfect')::BOOLEAN, FALSE)
        );

        -- Add strong words to vocabulary_progress (next review = tomorrow)
        IF (v_word_result->>'incorrect_count')::INTEGER = 0 THEN
            INSERT INTO vocabulary_progress (user_id, word_id, status, ease_factor, interval_days, repetitions, next_review_at, last_reviewed_at)
            VALUES (
                p_user_id,
                (v_word_result->>'word_id')::UUID,
                'learning',
                2.50,
                1,
                1,
                NOW() + INTERVAL '1 day',
                NOW()
            )
            ON CONFLICT (user_id, word_id) DO UPDATE SET
                last_reviewed_at = NOW(),
                repetitions = vocabulary_progress.repetitions + 1,
                next_review_at = NOW() + INTERVAL '1 day'
            WHERE vocabulary_progress.status != 'mastered';
        ELSE
            -- Add weak words to vocabulary_progress (review today / immediate)
            INSERT INTO vocabulary_progress (user_id, word_id, status, ease_factor, interval_days, repetitions, next_review_at, last_reviewed_at)
            VALUES (
                p_user_id,
                (v_word_result->>'word_id')::UUID,
                'learning',
                2.50,
                0,
                0,
                NOW(),
                NOW()
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

    -- Award XP
    PERFORM award_xp_transaction(
        p_user_id,
        v_total_xp,
        'vocabulary_session',
        v_session_id,
        'Vocabulary session completed'
    );

    -- Update streak
    PERFORM update_user_streak(p_user_id);

    -- Check badge eligibility
    PERFORM check_and_award_badges(p_user_id);

    RETURN QUERY SELECT v_session_id, v_total_xp;
END;
$$;

GRANT EXECUTE ON FUNCTION complete_vocabulary_session TO authenticated;
