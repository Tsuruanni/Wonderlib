-- Migration 10: Stored Functions
-- ReadEng (Wonderlib) Database Schema

-- =============================================
-- CALCULATE LEVEL FROM XP
-- =============================================
CREATE OR REPLACE FUNCTION calculate_level(p_xp INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    -- Level thresholds: 0, 100, 300, 600, 1000, 1500, 2100, 2800, 3600, 4500...
    -- Formula: threshold(n) = n * (n + 1) * 50
    -- Inverse: level = floor((-1 + sqrt(1 + xp/25)) / 2) + 1
    IF p_xp <= 0 THEN
        RETURN 1;
    END IF;
    RETURN LEAST(GREATEST(FLOOR((-1 + SQRT(1 + p_xp / 25.0)) / 2) + 1, 1), 100)::INTEGER;
END;
$$;

COMMENT ON FUNCTION calculate_level IS 'Calculate user level from XP using quadratic formula';

-- =============================================
-- AWARD XP TRANSACTION
-- =============================================
CREATE OR REPLACE FUNCTION award_xp_transaction(
    p_user_id UUID,
    p_amount INTEGER,
    p_source VARCHAR,
    p_source_id UUID DEFAULT NULL,
    p_description TEXT DEFAULT NULL
)
RETURNS TABLE(new_xp INTEGER, new_level INTEGER, level_up BOOLEAN)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_xp INTEGER;
    v_new_xp INTEGER;
    v_current_level INTEGER;
    v_new_level INTEGER;
BEGIN
    -- Get current XP with row lock
    SELECT xp, level INTO v_current_xp, v_current_level
    FROM profiles
    WHERE id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found: %', p_user_id;
    END IF;

    -- Calculate new values
    v_new_xp := v_current_xp + p_amount;
    v_new_level := calculate_level(v_new_xp);

    -- Update profile
    UPDATE profiles
    SET xp = v_new_xp,
        level = v_new_level,
        updated_at = NOW()
    WHERE id = p_user_id;

    -- Log XP
    INSERT INTO xp_logs (user_id, amount, source, source_id, description)
    VALUES (p_user_id, p_amount, p_source, p_source_id, p_description);

    -- Return result
    RETURN QUERY SELECT v_new_xp, v_new_level, (v_new_level > v_current_level);
END;
$$;

COMMENT ON FUNCTION award_xp_transaction IS 'Atomically award XP to user, update level, and log';

-- =============================================
-- UPDATE STREAK
-- =============================================
CREATE OR REPLACE FUNCTION update_user_streak(p_user_id UUID)
RETURNS TABLE(
    new_streak INTEGER,
    longest_streak INTEGER,
    streak_broken BOOLEAN,
    streak_extended BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_last_activity DATE;
    v_current_streak INTEGER;
    v_longest_streak INTEGER;
    v_today DATE := CURRENT_DATE;
    v_new_streak INTEGER;
    v_streak_broken BOOLEAN := FALSE;
    v_streak_extended BOOLEAN := FALSE;
BEGIN
    -- Get current streak info
    SELECT last_activity_date, current_streak, profiles.longest_streak
    INTO v_last_activity, v_current_streak, v_longest_streak
    FROM profiles
    WHERE id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found: %', p_user_id;
    END IF;

    -- Calculate new streak
    IF v_last_activity IS NULL THEN
        v_new_streak := 1;
        v_streak_extended := TRUE;
    ELSIF v_last_activity = v_today THEN
        -- Same day, no change
        v_new_streak := v_current_streak;
    ELSIF v_last_activity = v_today - 1 THEN
        -- Consecutive day
        v_new_streak := v_current_streak + 1;
        v_streak_extended := TRUE;
    ELSE
        -- Streak broken
        v_new_streak := 1;
        v_streak_broken := TRUE;
    END IF;

    -- Update longest streak
    IF v_new_streak > v_longest_streak THEN
        v_longest_streak := v_new_streak;
    END IF;

    -- Update profile
    UPDATE profiles
    SET current_streak = v_new_streak,
        longest_streak = v_longest_streak,
        last_activity_date = v_today,
        updated_at = NOW()
    WHERE id = p_user_id;

    RETURN QUERY SELECT v_new_streak, v_longest_streak, v_streak_broken, v_streak_extended;
END;
$$;

COMMENT ON FUNCTION update_user_streak IS 'Update user streak and return new values';

-- =============================================
-- GET WORDS DUE FOR REVIEW
-- =============================================
CREATE OR REPLACE FUNCTION get_words_due_for_review(
    p_user_id UUID,
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE(
    word_id UUID,
    word VARCHAR,
    phonetic VARCHAR,
    meaning_tr TEXT,
    meaning_en TEXT,
    ease_factor DECIMAL,
    repetitions INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT
        vw.id,
        vw.word,
        vw.phonetic,
        vw.meaning_tr,
        vw.meaning_en,
        vp.ease_factor,
        vp.repetitions
    FROM vocabulary_progress vp
    JOIN vocabulary_words vw ON vp.word_id = vw.id
    WHERE vp.user_id = p_user_id
    AND vp.status != 'mastered'
    AND (vp.next_review_at IS NULL OR vp.next_review_at <= NOW())
    ORDER BY vp.next_review_at ASC NULLS FIRST
    LIMIT p_limit;
END;
$$;

COMMENT ON FUNCTION get_words_due_for_review IS 'Get vocabulary words due for spaced repetition review';

-- =============================================
-- GET CLASS LEADERBOARD
-- =============================================
CREATE OR REPLACE FUNCTION get_class_leaderboard(
    p_class_id UUID,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE(
    user_id UUID,
    first_name VARCHAR,
    last_name VARCHAR,
    avatar_url VARCHAR,
    xp INTEGER,
    level INTEGER,
    rank BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.id,
        p.first_name,
        p.last_name,
        p.avatar_url,
        p.xp,
        p.level,
        RANK() OVER (ORDER BY p.xp DESC)
    FROM profiles p
    WHERE p.class_id = p_class_id
    AND p.role = 'student'
    ORDER BY p.xp DESC
    LIMIT p_limit;
END;
$$;

COMMENT ON FUNCTION get_class_leaderboard IS 'Get top students in a class by XP';

-- =============================================
-- GET SCHOOL LEADERBOARD
-- =============================================
CREATE OR REPLACE FUNCTION get_school_leaderboard(
    p_school_id UUID,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE(
    user_id UUID,
    first_name VARCHAR,
    last_name VARCHAR,
    class_name VARCHAR,
    avatar_url VARCHAR,
    xp INTEGER,
    level INTEGER,
    rank BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.id,
        p.first_name,
        p.last_name,
        c.name,
        p.avatar_url,
        p.xp,
        p.level,
        RANK() OVER (ORDER BY p.xp DESC)
    FROM profiles p
    LEFT JOIN classes c ON p.class_id = c.id
    WHERE p.school_id = p_school_id
    AND p.role = 'student'
    ORDER BY p.xp DESC
    LIMIT p_limit;
END;
$$;

COMMENT ON FUNCTION get_school_leaderboard IS 'Get top students in a school by XP';

-- =============================================
-- SEARCH BOOKS
-- =============================================
CREATE OR REPLACE FUNCTION search_books(
    p_query TEXT DEFAULT NULL,
    p_level VARCHAR DEFAULT NULL,
    p_genre VARCHAR DEFAULT NULL,
    p_age_group VARCHAR DEFAULT NULL,
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE(
    id UUID,
    title VARCHAR,
    slug VARCHAR,
    description TEXT,
    cover_url VARCHAR,
    level VARCHAR,
    genre VARCHAR,
    age_group VARCHAR,
    estimated_minutes INTEGER,
    word_count INTEGER,
    chapter_count INTEGER,
    rank REAL
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT
        b.id,
        b.title,
        b.slug,
        b.description,
        b.cover_url,
        b.level,
        b.genre,
        b.age_group,
        b.estimated_minutes,
        b.word_count,
        b.chapter_count,
        CASE
            WHEN p_query IS NULL OR p_query = '' THEN 1.0
            ELSE ts_rank(b.fts, websearch_to_tsquery('english', p_query))
        END as rank
    FROM books b
    WHERE b.status = 'published'
    AND (p_query IS NULL OR p_query = '' OR b.fts @@ websearch_to_tsquery('english', p_query))
    AND (p_level IS NULL OR b.level = p_level)
    AND (p_genre IS NULL OR b.genre = p_genre)
    AND (p_age_group IS NULL OR b.age_group = p_age_group)
    ORDER BY rank DESC, b.title
    LIMIT p_limit;
END;
$$;

COMMENT ON FUNCTION search_books IS 'Search books with optional filters and full-text search';

-- =============================================
-- CHECK BADGE ELIGIBILITY
-- =============================================
CREATE OR REPLACE FUNCTION check_and_award_badges(p_user_id UUID)
RETURNS TABLE(badge_id UUID, badge_name VARCHAR, xp_reward INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_profile profiles%ROWTYPE;
    v_badge badges%ROWTYPE;
    v_books_completed INTEGER;
    v_vocab_learned INTEGER;
    v_perfect_scores INTEGER;
BEGIN
    -- Get user profile
    SELECT * INTO v_profile FROM profiles WHERE id = p_user_id;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    -- Get stats
    SELECT COUNT(*) INTO v_books_completed
    FROM reading_progress
    WHERE user_id = p_user_id AND is_completed = TRUE;

    SELECT COUNT(*) INTO v_vocab_learned
    FROM vocabulary_progress
    WHERE user_id = p_user_id AND status = 'mastered';

    SELECT COUNT(*) INTO v_perfect_scores
    FROM activity_results
    WHERE user_id = p_user_id AND score = max_score;

    -- Check each badge
    FOR v_badge IN
        SELECT * FROM badges
        WHERE is_active = TRUE
        AND id NOT IN (SELECT ub.badge_id FROM user_badges ub WHERE ub.user_id = p_user_id)
    LOOP
        IF (v_badge.condition_type = 'xp_total' AND v_profile.xp >= v_badge.condition_value) OR
           (v_badge.condition_type = 'streak_days' AND v_profile.current_streak >= v_badge.condition_value) OR
           (v_badge.condition_type = 'books_completed' AND v_books_completed >= v_badge.condition_value) OR
           (v_badge.condition_type = 'vocabulary_learned' AND v_vocab_learned >= v_badge.condition_value) OR
           (v_badge.condition_type = 'perfect_scores' AND v_perfect_scores >= v_badge.condition_value) OR
           (v_badge.condition_type = 'level_completed' AND v_profile.level >= v_badge.condition_value)
        THEN
            -- Award badge
            INSERT INTO user_badges (user_id, badge_id) VALUES (p_user_id, v_badge.id);

            -- Award XP if badge has reward
            IF v_badge.xp_reward > 0 THEN
                PERFORM award_xp_transaction(p_user_id, v_badge.xp_reward, 'badge', v_badge.id, 'Earned: ' || v_badge.name);
            END IF;

            RETURN QUERY SELECT v_badge.id, v_badge.name::VARCHAR, v_badge.xp_reward;
        END IF;
    END LOOP;
END;
$$;

COMMENT ON FUNCTION check_and_award_badges IS 'Check and award eligible badges to user';

-- =============================================
-- GET USER STATS
-- =============================================
CREATE OR REPLACE FUNCTION get_user_stats(p_user_id UUID)
RETURNS TABLE(
    total_xp INTEGER,
    current_level INTEGER,
    current_streak INTEGER,
    longest_streak INTEGER,
    books_completed INTEGER,
    chapters_completed INTEGER,
    words_mastered INTEGER,
    reading_time_total INTEGER,
    badges_earned INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.xp,
        p.level,
        p.current_streak,
        p.longest_streak,
        (SELECT COUNT(*)::INTEGER FROM reading_progress rp WHERE rp.user_id = p_user_id AND rp.is_completed = TRUE),
        (SELECT COALESCE(SUM(array_length(rp.completed_chapter_ids, 1)), 0)::INTEGER FROM reading_progress rp WHERE rp.user_id = p_user_id),
        (SELECT COUNT(*)::INTEGER FROM vocabulary_progress vp WHERE vp.user_id = p_user_id AND vp.status = 'mastered'),
        (SELECT COALESCE(SUM(rp.total_reading_time), 0)::INTEGER FROM reading_progress rp WHERE rp.user_id = p_user_id),
        (SELECT COUNT(*)::INTEGER FROM user_badges ub WHERE ub.user_id = p_user_id)
    FROM profiles p
    WHERE p.id = p_user_id;
END;
$$;

COMMENT ON FUNCTION get_user_stats IS 'Get comprehensive user statistics';
