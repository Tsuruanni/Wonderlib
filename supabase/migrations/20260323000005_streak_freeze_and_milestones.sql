-- =============================================
-- Streak Freeze & Milestones
-- =============================================

-- 1. Add streak_freeze_count to profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS streak_freeze_count INTEGER DEFAULT 0;

-- 2. Add settings for streak freeze
INSERT INTO system_settings (key, value, category, description) VALUES
  ('streak_freeze_price', '50', 'progression', 'Coin cost to buy one streak freeze'),
  ('streak_freeze_max', '2', 'progression', 'Maximum streak freezes a user can hold')
ON CONFLICT (key) DO NOTHING;

-- 3. Modified update_user_streak with freeze + milestones
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
    v_today DATE := CURRENT_DATE;
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

-- 4. New RPC: buy_streak_freeze
CREATE OR REPLACE FUNCTION buy_streak_freeze(p_user_id UUID)
RETURNS TABLE(success BOOLEAN, freeze_count INTEGER, coins_remaining INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_max INTEGER;
    v_price INTEGER;
    v_current_freezes INTEGER;
    v_current_coins INTEGER;
    v_new_coins INTEGER;
BEGIN
    -- Auth check
    IF auth.uid() != p_user_id THEN
        RAISE EXCEPTION 'unauthorized';
    END IF;

    -- Read settings
    SELECT (value)::INT INTO v_max FROM system_settings WHERE key = 'streak_freeze_max';
    SELECT (value)::INT INTO v_price FROM system_settings WHERE key = 'streak_freeze_price';

    -- Defaults if settings not found
    v_max := COALESCE(v_max, 2);
    v_price := COALESCE(v_price, 50);

    -- Lock and read profile
    SELECT p.streak_freeze_count, p.coins
    INTO v_current_freezes, v_current_coins
    FROM profiles p
    WHERE p.id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    -- Validate
    IF v_current_freezes >= v_max THEN
        RAISE EXCEPTION 'max_freezes_reached';
    END IF;

    IF v_current_coins < v_price THEN
        RAISE EXCEPTION 'insufficient_coins';
    END IF;

    -- Spend coins using existing transaction function
    SELECT sc.new_coins INTO v_new_coins
    FROM spend_coins_transaction(p_user_id, v_price, 'streak_freeze', NULL, 'Purchased streak freeze') sc;

    -- Increment freeze count
    UPDATE profiles
    SET streak_freeze_count = streak_freeze_count + 1,
        updated_at = NOW()
    WHERE id = p_user_id;

    RETURN QUERY SELECT TRUE, v_current_freezes + 1, v_new_coins;
END;
$$;

COMMENT ON FUNCTION buy_streak_freeze IS 'Purchase a streak freeze with coins';
