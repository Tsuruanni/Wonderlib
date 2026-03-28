-- Add auth.uid() verification to award_xp_transaction RPC.
-- Prevents a client from awarding XP to another user.
-- SECURITY DEFINER bypasses RLS, so we must verify identity explicitly.
-- Same pattern used in complete_vocabulary_session (20260328000002).

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
    v_current_coins INTEGER;
    v_new_xp INTEGER;
    v_new_coins INTEGER;
    v_current_level INTEGER;
    v_new_level INTEGER;
BEGIN
    -- Auth check: ensure caller is the user they claim to be
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Not authorized: user mismatch';
    END IF;

    -- Lock the row FIRST to prevent race conditions
    SELECT xp, level, coins INTO v_current_xp, v_current_level, v_current_coins
    FROM profiles
    WHERE id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found: %', p_user_id;
    END IF;

    -- Idempotency check AFTER lock (prevents TOCTOU race condition)
    IF p_source_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM xp_logs
        WHERE user_id = p_user_id AND source = p_source AND source_id = p_source_id
    ) THEN
        -- Already awarded — return current state without modification
        RETURN QUERY SELECT v_current_xp, v_current_level, false;
        RETURN;
    END IF;

    -- Calculate new values
    v_new_xp := v_current_xp + p_amount;
    v_new_level := calculate_level(v_new_xp);
    v_new_coins := v_current_coins + p_amount;

    -- Update profile (XP + level + coins atomically)
    UPDATE profiles
    SET xp = v_new_xp,
        level = v_new_level,
        coins = v_new_coins,
        updated_at = NOW()
    WHERE id = p_user_id;

    -- Log XP
    INSERT INTO xp_logs (user_id, amount, source, source_id, description)
    VALUES (p_user_id, p_amount, p_source, p_source_id, p_description);

    -- Log coins
    INSERT INTO coin_logs (user_id, amount, balance_after, source, source_id, description)
    VALUES (p_user_id, p_amount, v_new_coins, p_source, p_source_id, p_description);

    RETURN QUERY SELECT v_new_xp, v_new_level, (v_new_level > v_current_level);
END;
$$;
