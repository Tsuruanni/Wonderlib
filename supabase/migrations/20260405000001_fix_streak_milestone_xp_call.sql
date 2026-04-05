-- Fix: update_user_streak passes text 'day_N' to award_xp_transaction's
-- p_source_id which is UUID. This causes a type mismatch error when a
-- streak milestone is hit (day 7, 14, 30, etc.), rolling back the entire
-- streak update transaction.
--
-- Fix: pass NULL for source_id, keep milestone info in description only.

CREATE OR REPLACE FUNCTION update_user_streak(p_user_id UUID)
RETURNS TABLE(
    new_streak INTEGER,
    longest_streak INTEGER,
    streak_broken BOOLEAN,
    streak_extended BOOLEAN,
    freeze_used BOOLEAN,
    freezes_consumed INTEGER,
    freezes_remaining INTEGER,
    milestone_bonus_xp INTEGER,
    previous_streak INTEGER
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
    v_milestones JSONB;
    v_repeat_interval INTEGER;
    v_repeat_xp INTEGER;
    i INTEGER;
BEGIN
    -- Auth check: prevent updating another user's streak
    IF auth.uid() != p_user_id THEN
        RAISE EXCEPTION 'unauthorized';
    END IF;

    SELECT p.last_activity_date, p.current_streak, p.longest_streak, p.streak_freeze_count
    INTO v_last_activity, v_current_streak, v_longest_streak, v_freeze_count
    FROM profiles p
    WHERE p.id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found: %', p_user_id;
    END IF;

    INSERT INTO daily_logins (user_id, login_date, is_freeze)
    VALUES (p_user_id, v_today, false)
    ON CONFLICT (user_id, login_date) DO UPDATE SET is_freeze = false;

    IF v_last_activity IS NULL THEN
        v_new_streak := 1;
        v_streak_extended := TRUE;
    ELSIF v_last_activity = v_today THEN
        v_new_streak := v_current_streak;
    ELSIF v_last_activity = v_today - 1 THEN
        v_new_streak := v_current_streak + 1;
        v_streak_extended := TRUE;
    ELSE
        v_days_missed := (v_today - v_last_activity) - 1;

        IF v_days_missed <= v_freeze_count THEN
            v_freeze_count := v_freeze_count - v_days_missed;
            v_new_streak := v_current_streak + 1;
            v_streak_extended := TRUE;
            v_freeze_used := TRUE;
            v_freezes_consumed := v_days_missed;

            FOR i IN 1..v_days_missed LOOP
                INSERT INTO daily_logins (user_id, login_date, is_freeze)
                VALUES (p_user_id, v_last_activity + i, true)
                ON CONFLICT (user_id, login_date) DO NOTHING;
            END LOOP;

        ELSIF v_freeze_count > 0 THEN
            v_freezes_consumed := v_freeze_count;
            v_freeze_count := 0;
            v_new_streak := 1;
            v_streak_broken := TRUE;
            v_freeze_used := TRUE;

            FOR i IN 1..v_freezes_consumed LOOP
                INSERT INTO daily_logins (user_id, login_date, is_freeze)
                VALUES (p_user_id, v_last_activity + i, true)
                ON CONFLICT (user_id, login_date) DO NOTHING;
            END LOOP;

        ELSE
            v_new_streak := 1;
            v_streak_broken := TRUE;
        END IF;
    END IF;

    IF v_new_streak > v_longest_streak THEN
        v_longest_streak := v_new_streak;
    END IF;

    IF v_streak_extended THEN
        -- Load milestone config from system_settings
        SELECT value INTO v_milestones FROM system_settings WHERE key = 'streak_milestones';
        SELECT COALESCE((SELECT (value#>>'{}')::INT FROM system_settings WHERE key = 'streak_milestone_repeat_interval'), 100) INTO v_repeat_interval;
        SELECT COALESCE((SELECT (value#>>'{}')::INT FROM system_settings WHERE key = 'streak_milestone_repeat_xp'), 1000) INTO v_repeat_xp;

        -- Check defined milestones
        IF v_milestones IS NOT NULL THEN
            v_milestone_xp := COALESCE((v_milestones->>v_new_streak::TEXT)::INT, 0);
        END IF;

        -- Check repeating milestone (beyond defined milestones)
        IF v_milestone_xp = 0 AND v_repeat_interval > 0 AND v_new_streak > 100 AND v_new_streak % v_repeat_interval = 0 THEN
            v_milestone_xp := v_repeat_xp;
        END IF;

        IF v_milestone_xp > 0 THEN
            -- FIX: pass NULL for source_id (UUID type) instead of text 'day_N'
            PERFORM award_xp_transaction(
                p_user_id, v_milestone_xp, 'streak_milestone',
                NULL, 'Streak milestone: ' || v_new_streak || ' days'
            );
        END IF;
    END IF;

    UPDATE profiles
    SET current_streak = v_new_streak,
        longest_streak = v_longest_streak,
        last_activity_date = v_today,
        streak_freeze_count = v_freeze_count,
        updated_at = NOW()
    WHERE id = p_user_id;

    RETURN QUERY SELECT v_new_streak, v_longest_streak, v_streak_broken, v_streak_extended,
                        v_freeze_used, v_freezes_consumed, v_freeze_count, v_milestone_xp,
                        v_current_streak;
END;
$$;
