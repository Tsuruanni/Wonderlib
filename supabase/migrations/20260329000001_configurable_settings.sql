-- Add configurable settings for: pack cost, activity XP tiers,
-- daily review XP, activity thresholds, star rating thresholds.
-- Defaults match current hardcoded values for zero-change deployment.

-- Category: game
INSERT INTO system_settings (key, value, category, description, sort_order) VALUES
  ('pack_cost', '"100"', 'game', 'Card pack price in coins', 1)
ON CONFLICT (key) DO NOTHING;

-- Category: xp_reading — Activity Result XP tiers
INSERT INTO system_settings (key, value, category, description, group_label, sort_order) VALUES
  ('xp_activity_result_perfect', '"10"', 'xp_reading', 'XP for 100% score on inline activity', 'Activity Result XP', 20),
  ('xp_activity_result_good', '"7"', 'xp_reading', 'XP for ≥80% score on inline activity', 'Activity Result XP', 21),
  ('xp_activity_result_pass', '"5"', 'xp_reading', 'XP for ≥60% score on inline activity', 'Activity Result XP', 22),
  ('xp_activity_result_participation', '"2"', 'xp_reading', 'XP for less than 60% score on inline activity', 'Activity Result XP', 23)
ON CONFLICT (key) DO NOTHING;

-- Category: xp_vocab — Daily Review
INSERT INTO system_settings (key, value, category, description, group_label, sort_order) VALUES
  ('xp_daily_review_correct', '"5"', 'xp_vocab', 'XP per correct answer in daily review', 'Daily Review', 20)
ON CONFLICT (key) DO NOTHING;

-- Category: progression — Activity Thresholds + Star Rating
INSERT INTO system_settings (key, value, category, description, group_label, sort_order) VALUES
  ('activity_pass_threshold', '"60"', 'progression', 'Minimum % to pass an inline activity', 'Activity Thresholds', 10),
  ('activity_excellence_threshold', '"90"', 'progression', 'Minimum % for excellent on inline activity', 'Activity Thresholds', 11),
  ('star_rating_3', '"90"', 'progression', 'Minimum accuracy % for 3 stars on word list', 'Star Rating', 20),
  ('star_rating_2', '"70"', 'progression', 'Minimum accuracy % for 2 stars on word list', 'Star Rating', 21),
  ('star_rating_1', '"50"', 'progression', 'Minimum accuracy % for 1 star on word list', 'Star Rating', 22)
ON CONFLICT (key) DO NOTHING;

-- Update complete_daily_review RPC to read xp_daily_review_correct from settings
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
    v_xp_per_correct INTEGER;
    v_base_xp INTEGER;
    v_session_bonus INTEGER;
    v_perfect_bonus INTEGER;
    v_total_xp INTEGER;
    v_is_perfect BOOLEAN;
    v_session_id UUID;
BEGIN
    -- Auth check
    IF auth.uid() != p_user_id THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    -- Read XP values from system_settings (with fallback defaults)
    SELECT COALESCE(
      (SELECT (value #>> '{}')::INTEGER FROM system_settings WHERE key = 'xp_daily_review_correct'),
      5
    ) INTO v_xp_per_correct;

    SELECT COALESCE(
      (SELECT (value #>> '{}')::INTEGER FROM system_settings WHERE key = 'xp_vocab_session_bonus'),
      10
    ) INTO v_session_bonus;

    SELECT COALESCE(
      (SELECT (value #>> '{}')::INTEGER FROM system_settings WHERE key = 'xp_vocab_perfect_bonus'),
      20
    ) INTO v_perfect_bonus;

    -- Prevent duplicate session on same day
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

    -- Calculate XP using configurable per-correct value
    v_base_xp := p_correct_count * v_xp_per_correct;
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

    PERFORM check_and_award_badges(p_user_id);

    RETURN QUERY SELECT v_session_id, v_total_xp, TRUE, v_is_perfect;
END;
$$;
