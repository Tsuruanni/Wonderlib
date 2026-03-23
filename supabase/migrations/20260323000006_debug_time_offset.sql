-- =============================================
-- Debug Time Offset — System-wide time manipulation for testing
-- =============================================

-- 1. Helper functions
CREATE OR REPLACE FUNCTION app_current_date() RETURNS DATE AS $$
  SELECT (CURRENT_DATE + COALESCE(
    (SELECT value::INT FROM system_settings WHERE key = 'debug_date_offset'), 0
  ))::DATE;
$$ LANGUAGE sql STABLE;

COMMENT ON FUNCTION app_current_date IS 'Returns CURRENT_DATE + debug offset days. Use instead of CURRENT_DATE in business logic.';

CREATE OR REPLACE FUNCTION app_now() RETURNS TIMESTAMPTZ AS $$
  SELECT NOW() + COALESCE(
    (SELECT value::INT FROM system_settings WHERE key = 'debug_date_offset'), 0
  ) * INTERVAL '1 day';
$$ LANGUAGE sql STABLE;

COMMENT ON FUNCTION app_now IS 'Returns NOW() + debug offset days. Use instead of NOW() in business logic.';

-- 2. Setting
INSERT INTO system_settings (key, value, category, description) VALUES
  ('debug_date_offset', '0', 'app', 'Debug: shift all date/time by N days (0 = production)')
ON CONFLICT (key) DO NOTHING;

-- =============================================
-- A. update_user_streak
-- Source: 20260323000005_streak_freeze_and_milestones.sql
-- Change: v_today DATE := CURRENT_DATE → app_current_date()
-- Note: updated_at = NOW() is NOT replaced (profile timestamp)
-- =============================================
DROP FUNCTION IF EXISTS update_user_streak(UUID);
CREATE OR REPLACE FUNCTION update_user_streak(p_user_id UUID)
RETURNS TABLE(
    new_streak INTEGER,
    longest_streak INTEGER,
    streak_broken BOOLEAN,
    streak_extended BOOLEAN,
    freeze_used BOOLEAN,
    freezes_consumed INTEGER,
    freezes_remaining INTEGER,
    milestone_bonus_xp INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_last_activity DATE;
    v_current_streak INTEGER;
    v_longest_streak INTEGER;
    v_freeze_count INTEGER;
    v_today DATE := app_current_date();
    v_new_streak INTEGER;
    v_streak_broken BOOLEAN := FALSE;
    v_streak_extended BOOLEAN := FALSE;
    v_freeze_used BOOLEAN := FALSE;
    v_freezes_consumed INTEGER := 0;
    v_days_missed INTEGER;
    v_milestone_xp INTEGER := 0;
BEGIN
    -- Get current streak info with row lock
    SELECT p.last_activity_date, p.current_streak, p.longest_streak, p.streak_freeze_count
    INTO v_last_activity, v_current_streak, v_longest_streak, v_freeze_count
    FROM profiles p
    WHERE p.id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found: %', p_user_id;
    END IF;

    -- Calculate new streak
    IF v_last_activity IS NULL THEN
        -- First activity ever
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
        -- Gap >= 2 days — check freezes
        v_days_missed := (v_today - v_last_activity) - 1;

        IF v_days_missed <= v_freeze_count THEN
            -- All missed days covered by freezes
            v_freeze_count := v_freeze_count - v_days_missed;
            v_new_streak := v_current_streak + 1;
            v_streak_extended := TRUE;
            v_freeze_used := TRUE;
            v_freezes_consumed := v_days_missed;
        ELSIF v_freeze_count > 0 THEN
            -- Partial coverage: not enough freezes
            v_freezes_consumed := v_freeze_count;
            v_freeze_count := 0;
            v_new_streak := 1;
            v_streak_broken := TRUE;
            v_freeze_used := TRUE;
        ELSE
            -- No freezes
            v_new_streak := 1;
            v_streak_broken := TRUE;
        END IF;
    END IF;

    -- Update longest streak
    IF v_new_streak > v_longest_streak THEN
        v_longest_streak := v_new_streak;
    END IF;

    -- Milestone bonus (only when streak extended)
    IF v_streak_extended THEN
        v_milestone_xp := CASE v_new_streak
            WHEN 7   THEN 50
            WHEN 14  THEN 100
            WHEN 30  THEN 200
            WHEN 60  THEN 400
            WHEN 100 THEN 1000
            ELSE 0
        END;

        IF v_milestone_xp > 0 THEN
            PERFORM award_xp_transaction(
                p_user_id, v_milestone_xp, 'streak_milestone',
                NULL, 'Streak milestone: ' || v_new_streak || ' days'
            );
        END IF;
    END IF;

    -- Update profile
    UPDATE profiles
    SET current_streak = v_new_streak,
        longest_streak = v_longest_streak,
        last_activity_date = v_today,
        streak_freeze_count = v_freeze_count,
        updated_at = NOW()
    WHERE id = p_user_id;

    RETURN QUERY SELECT v_new_streak, v_longest_streak, v_streak_broken, v_streak_extended,
                        v_freeze_used, v_freezes_consumed, v_freeze_count, v_milestone_xp;
END;
$$;

COMMENT ON FUNCTION update_user_streak IS 'Update user streak with freeze support and milestone bonuses';

-- =============================================
-- B. get_daily_quest_progress
-- Source: 20260323000002_update_quest_types.sql
-- Change: v_today DATE := CURRENT_DATE → app_current_date()
--         NOW() AT TIME ZONE 'Europe/Istanbul' → app_now() AT TIME ZONE 'Europe/Istanbul'
-- =============================================
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
    v_today DATE := app_current_date();
    v_istanbul_start TIMESTAMPTZ := date_trunc('day', app_now() AT TIME ZONE 'Europe/Istanbul') AT TIME ZONE 'Europe/Istanbul';
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
                    SELECT 1 FROM daily_review_sessions drs
                    WHERE drs.user_id = p_user_id AND drs.session_date = v_today
                ) THEN 1 ELSE 0 END INTO v_current;

            WHEN 'read_chapters' THEN
                SELECT COUNT(*)::INT
                INTO v_current
                FROM daily_chapter_reads dcr
                WHERE dcr.user_id = p_user_id AND dcr.read_date = v_today;

            WHEN 'vocab_session' THEN
                SELECT COUNT(*)::INT
                INTO v_current
                FROM vocabulary_sessions vs
                WHERE vs.user_id = p_user_id
                  AND vs.completed_at >= v_istanbul_start;

            -- Legacy types (kept for backward compat, won't match active quests)
            WHEN 'read_words' THEN
                SELECT COALESCE(SUM(COALESCE(ch.word_count, 0)), 0)
                INTO v_current
                FROM daily_chapter_reads dcr
                JOIN chapters ch ON ch.id = dcr.chapter_id
                WHERE dcr.user_id = p_user_id AND dcr.read_date = v_today;

            WHEN 'correct_answers' THEN
                SELECT COUNT(*)::INT
                INTO v_current
                FROM inline_activity_results iar
                WHERE iar.user_id = p_user_id
                  AND iar.is_correct = true
                  AND iar.answered_at >= v_istanbul_start;

            ELSE
                v_current := 0;
        END CASE;

        v_completed := v_current >= v_quest.goal_value;

        -- Check if already awarded
        SELECT EXISTS(
            SELECT 1 FROM daily_quest_completions dqc
            WHERE dqc.user_id = p_user_id AND dqc.quest_id = v_quest.id AND dqc.completion_date = v_today
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

-- =============================================
-- C. claim_daily_bonus
-- Source: 20260322000003_daily_quest_engine.sql
-- Change: v_today DATE := CURRENT_DATE → app_current_date()
-- =============================================
CREATE OR REPLACE FUNCTION claim_daily_bonus(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_today DATE := app_current_date();
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

-- =============================================
-- D. complete_daily_review
-- Source: 20260203000001_add_daily_review_sessions.sql
-- Change: CURRENT_DATE → app_current_date() in business logic queries
--         (2 occurrences: WHERE clause check + INSERT value)
-- Note: DEFAULT CURRENT_DATE on table column is NOT touched (in CREATE TABLE, not here)
-- =============================================
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
    WHERE user_id = p_user_id AND session_date = app_current_date();

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
        app_current_date(),
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

-- =============================================
-- E. complete_vocabulary_session
-- Source: 20260317000001_fix_session_sm2_interval_growth.sql
-- Change: NOW() → app_now() in business logic:
--   - next_review_at = NOW() + INTERVAL '1 day'  (INSERT for new strong word)
--   - last_reviewed_at = NOW()                    (INSERT for new strong word)
--   - next_review_at = NOW() + make_interval(...)  (UPDATE for existing strong word)
--   - last_reviewed_at = NOW()                    (UPDATE for existing strong word)
--   - next_review_at = NOW()                      (INSERT/ON CONFLICT for weak word)
--   - last_reviewed_at = NOW()                    (INSERT/ON CONFLICT for weak word)
-- NOT replaced: updated_at = NOW(), last_session_at = NOW(), started_at = NOW(),
--               completed_at = NOW() (these are record timestamps, not business time)
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
                    1, 1, app_now() + INTERVAL '1 day', app_now()
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
                    last_reviewed_at = app_now(),
                    repetitions = v_current_reps,
                    interval_days = v_new_interval,
                    ease_factor = LEAST(v_current_ease + 0.02, 3.0),
                    next_review_at = app_now() + make_interval(days => v_new_interval),
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
                0, 0, app_now(), app_now()
            )
            ON CONFLICT (user_id, word_id) DO UPDATE SET
                last_reviewed_at = app_now(),
                interval_days = 0,
                repetitions = 0,
                ease_factor = GREATEST(vocabulary_progress.ease_factor - 0.2, 1.3),
                next_review_at = app_now(),
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

-- =============================================
-- F. get_quest_completion_stats
-- Source: 20260323000004_quest_admin_stats_rpc.sql
-- Change: CURRENT_DATE → app_current_date() (2 occurrences)
-- =============================================
CREATE OR REPLACE FUNCTION get_quest_completion_stats()
RETURNS TABLE(
    quest_id UUID,
    today_completed INT,
    today_total_users INT,
    avg_daily_7d NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_students INT;
BEGIN
    -- Admin-only check
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin') THEN
        RAISE EXCEPTION 'unauthorized';
    END IF;

    -- Count total students once
    SELECT COUNT(*)::INT INTO v_total_students
    FROM profiles WHERE role = 'student';

    RETURN QUERY
    SELECT
        dq.id AS quest_id,
        COALESCE(tc.cnt, 0)::INT AS today_completed,
        v_total_students AS today_total_users,
        COALESCE(avg7.avg_completions, 0) AS avg_daily_7d
    FROM daily_quests dq
    LEFT JOIN (
        -- Today's completions per quest
        SELECT dqc.quest_id AS qid, COUNT(*)::INT AS cnt
        FROM daily_quest_completions dqc
        WHERE dqc.completion_date = app_current_date()
        GROUP BY dqc.quest_id
    ) tc ON tc.qid = dq.id
    LEFT JOIN (
        -- 7-day average completions per quest
        SELECT
            sub.qid,
            (SUM(sub.daily_cnt)::NUMERIC / 7) AS avg_completions
        FROM (
            SELECT dqc.quest_id AS qid, dqc.completion_date, COUNT(*) AS daily_cnt
            FROM daily_quest_completions dqc
            WHERE dqc.completion_date >= app_current_date() - 6
            GROUP BY dqc.quest_id, dqc.completion_date
        ) sub
        GROUP BY sub.qid
    ) avg7 ON avg7.qid = dq.id
    ORDER BY dq.sort_order;
END;
$$;

-- =============================================
-- G. get_words_due_for_review
-- Source: 20260131000010_create_functions.sql
-- Change: NOW() → app_now() in the WHERE clause
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
    AND (vp.next_review_at IS NULL OR vp.next_review_at <= app_now())
    ORDER BY vp.next_review_at ASC NULLS FIRST
    LIMIT p_limit;
END;
$$;

COMMENT ON FUNCTION get_words_due_for_review IS 'Get vocabulary words due for spaced repetition review';

-- =============================================
-- H. process_weekly_league_reset
-- Source: 20260218000001_league_school_based_reset.sql
-- Change: NOW() → app_now() in date_trunc and interval calculations
--   - v_last_week_start: date_trunc('week', NOW()) → date_trunc('week', app_now())
--   - v_last_week_ts: date_trunc('week', NOW()) → date_trunc('week', app_now())
--   - v_this_week_ts: date_trunc('week', NOW()) → date_trunc('week', app_now())
-- =============================================
CREATE OR REPLACE FUNCTION process_weekly_league_reset()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_last_week_start DATE := (date_trunc('week', app_now()) - INTERVAL '7 days')::DATE;
    v_last_week_ts TIMESTAMPTZ := date_trunc('week', app_now()) - INTERVAL '7 days';
    v_this_week_ts TIMESTAMPTZ := date_trunc('week', app_now());
    v_school RECORD;
    v_student RECORD;
    v_school_size INTEGER;
    v_promote_count INTEGER;
    v_demote_count INTEGER;
    v_tier_order TEXT[] := ARRAY['bronze', 'silver', 'gold', 'platinum', 'diamond'];
    v_current_idx INTEGER;
    v_new_tier VARCHAR(20);
    v_result VARCHAR(20);
BEGIN
    -- Skip if already processed this week
    IF EXISTS (SELECT 1 FROM league_history WHERE week_start = v_last_week_start LIMIT 1) THEN
        RAISE NOTICE 'Week % already processed', v_last_week_start;
        RETURN;
    END IF;

    -- Process each school
    FOR v_school IN
        SELECT DISTINCT p.school_id
        FROM profiles p
        WHERE p.role = 'student'
        AND p.school_id IS NOT NULL
    LOOP
        -- Count students in this school
        SELECT COUNT(*) INTO v_school_size
        FROM profiles
        WHERE school_id = v_school.school_id AND role = 'student';

        -- Determine promotion/demotion counts based on school size
        IF v_school_size < 10 THEN
            v_promote_count := 1;
            v_demote_count := 1;
        ELSIF v_school_size <= 25 THEN
            v_promote_count := 2;
            v_demote_count := 2;
        ELSIF v_school_size <= 50 THEN
            v_promote_count := 3;
            v_demote_count := 3;
        ELSE
            v_promote_count := 5;
            v_demote_count := 5;
        END IF;

        -- Rank students by weekly XP within the school
        FOR v_student IN
            WITH weekly_xp_calc AS (
                SELECT
                    xl.user_id AS uid,
                    COALESCE(SUM(xl.amount), 0) AS week_xp
                FROM xp_logs xl
                WHERE xl.created_at >= v_last_week_ts
                AND xl.created_at < v_this_week_ts
                GROUP BY xl.user_id
            )
            SELECT
                p.id AS student_id,
                p.class_id AS student_class_id,
                p.league_tier AS current_tier,
                COALESCE(wxc.week_xp, 0) AS weekly_xp,
                RANK() OVER (ORDER BY COALESCE(wxc.week_xp, 0) DESC, p.xp DESC)::INTEGER AS rank
            FROM profiles p
            LEFT JOIN weekly_xp_calc wxc ON p.id = wxc.uid
            WHERE p.school_id = v_school.school_id
            AND p.role = 'student'
            ORDER BY rank
        LOOP
            -- Determine promotion/demotion
            v_result := 'stayed';
            v_new_tier := v_student.current_tier;

            -- Find current tier index
            v_current_idx := array_position(v_tier_order, v_student.current_tier);
            IF v_current_idx IS NULL THEN
                v_current_idx := 1; -- default to bronze
            END IF;

            IF v_student.rank <= v_promote_count AND v_current_idx < 5 THEN
                -- Promote (only if not already diamond)
                v_new_tier := v_tier_order[v_current_idx + 1];
                v_result := 'promoted';
            ELSIF v_student.rank > (v_school_size - v_demote_count) AND v_current_idx > 1 THEN
                -- Demote (only if not already bronze)
                v_new_tier := v_tier_order[v_current_idx - 1];
                v_result := 'demoted';
            END IF;

            -- Insert history snapshot (school_id + class_id for reference)
            INSERT INTO league_history (user_id, class_id, school_id, week_start, league_tier, rank, weekly_xp, result)
            VALUES (v_student.student_id, v_student.student_class_id, v_school.school_id,
                    v_last_week_start, v_new_tier, v_student.rank, v_student.weekly_xp, v_result);

            -- Update profile if tier changed
            IF v_new_tier != v_student.current_tier THEN
                UPDATE profiles SET league_tier = v_new_tier WHERE id = v_student.student_id;
            END IF;
        END LOOP;
    END LOOP;
END;
$$;

COMMENT ON FUNCTION process_weekly_league_reset IS 'Process weekly league promotion/demotion for all schools. Call every Monday 00:00 UTC.';
