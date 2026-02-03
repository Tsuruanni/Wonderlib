-- Daily Review Sessions for Anki-style spaced repetition
-- Tracks completed daily review sessions for XP awards and analytics

-- Table: daily_review_sessions
CREATE TABLE daily_review_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    session_date DATE NOT NULL DEFAULT CURRENT_DATE,
    words_reviewed INTEGER NOT NULL DEFAULT 0,
    correct_count INTEGER NOT NULL DEFAULT 0,
    incorrect_count INTEGER NOT NULL DEFAULT 0,
    xp_earned INTEGER NOT NULL DEFAULT 0,
    is_perfect BOOLEAN DEFAULT FALSE,
    completed_at TIMESTAMPTZ DEFAULT NOW(),

    -- Only one session per user per day
    UNIQUE(user_id, session_date)
);

-- Index for quick lookups
CREATE INDEX idx_daily_review_sessions_user_date
ON daily_review_sessions(user_id, session_date DESC);

-- Enable RLS
ALTER TABLE daily_review_sessions ENABLE ROW LEVEL SECURITY;

-- Users can only see their own sessions
CREATE POLICY daily_review_sessions_select ON daily_review_sessions
    FOR SELECT USING (auth.uid() = user_id);

-- Users can insert their own sessions
CREATE POLICY daily_review_sessions_insert ON daily_review_sessions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- RPC: Complete daily review with atomic XP award
-- ============================================================
-- Awards:
--   - 5 XP per correct answer
--   - 10 XP session completion bonus
--   - 20 XP perfect session bonus (if 100% correct)
-- Prevents duplicate awards on same day
-- ============================================================

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
    -- Check for existing session today
    SELECT * INTO v_existing_session
    FROM daily_review_sessions
    WHERE user_id = p_user_id AND session_date = CURRENT_DATE;

    -- If session already exists, return without awarding XP
    IF v_existing_session.id IS NOT NULL THEN
        RETURN QUERY SELECT
            v_existing_session.id,
            0::INTEGER,
            FALSE,
            v_existing_session.is_perfect;
        RETURN;
    END IF;

    -- Calculate XP
    v_base_xp := p_correct_count * 5;  -- 5 XP per correct answer
    v_is_perfect := (p_correct_count = p_words_reviewed AND p_incorrect_count = 0 AND p_words_reviewed > 0);

    v_total_xp := v_base_xp + v_session_bonus;  -- Always get session bonus
    IF v_is_perfect THEN
        v_total_xp := v_total_xp + v_perfect_bonus;  -- Perfect bonus
    END IF;

    -- Insert session record
    INSERT INTO daily_review_sessions (
        user_id,
        session_date,
        words_reviewed,
        correct_count,
        incorrect_count,
        xp_earned,
        is_perfect
    ) VALUES (
        p_user_id,
        CURRENT_DATE,
        p_words_reviewed,
        p_correct_count,
        p_incorrect_count,
        v_total_xp,
        v_is_perfect
    ) RETURNING id INTO v_session_id;

    -- Award XP using existing function
    PERFORM award_xp_transaction(
        p_user_id,
        v_total_xp,
        'daily_review',
        v_session_id,
        'Daily vocabulary review completed'
    );

    -- Update streak
    PERFORM update_user_streak(p_user_id);

    -- Check for badge eligibility
    PERFORM check_and_award_badges(p_user_id);

    RETURN QUERY SELECT v_session_id, v_total_xp, TRUE, v_is_perfect;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION complete_daily_review TO authenticated;
