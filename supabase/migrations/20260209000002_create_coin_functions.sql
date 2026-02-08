-- Migration: Coin Transaction Functions
-- Mythic Scholars Arena - Atomic coin operations

-- =============================================
-- AWARD COINS TRANSACTION
-- =============================================
CREATE OR REPLACE FUNCTION award_coins_transaction(
    p_user_id UUID,
    p_amount INTEGER,
    p_source VARCHAR,
    p_source_id UUID DEFAULT NULL,
    p_description TEXT DEFAULT NULL
)
RETURNS TABLE(new_coins INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_coins INTEGER;
    v_new_coins INTEGER;
BEGIN
    -- Get current coins with row lock
    SELECT coins INTO v_current_coins
    FROM profiles
    WHERE id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found: %', p_user_id;
    END IF;

    -- Calculate new balance
    v_new_coins := v_current_coins + p_amount;

    -- Prevent negative balance
    IF v_new_coins < 0 THEN
        RAISE EXCEPTION 'Insufficient coins. Current: %, Requested: %', v_current_coins, p_amount;
    END IF;

    -- Update profile
    UPDATE profiles
    SET coins = v_new_coins,
        updated_at = NOW()
    WHERE id = p_user_id;

    -- Log transaction
    INSERT INTO coin_logs (user_id, amount, balance_after, source, source_id, description)
    VALUES (p_user_id, p_amount, v_new_coins, p_source, p_source_id, p_description);

    RETURN QUERY SELECT v_new_coins;
END;
$$;

COMMENT ON FUNCTION award_coins_transaction IS 'Atomically award coins to user and log transaction';

-- =============================================
-- SPEND COINS TRANSACTION (convenience wrapper)
-- =============================================
CREATE OR REPLACE FUNCTION spend_coins_transaction(
    p_user_id UUID,
    p_amount INTEGER,
    p_source VARCHAR,
    p_source_id UUID DEFAULT NULL,
    p_description TEXT DEFAULT NULL
)
RETURNS TABLE(new_coins INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Negate amount to spend
    RETURN QUERY SELECT * FROM award_coins_transaction(
        p_user_id, -p_amount, p_source, p_source_id, p_description
    );
END;
$$;

COMMENT ON FUNCTION spend_coins_transaction IS 'Atomically spend coins (deduct from balance)';

-- =============================================
-- MODIFY award_xp_transaction TO ALSO AWARD COINS
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
    v_current_coins INTEGER;
    v_new_xp INTEGER;
    v_new_coins INTEGER;
    v_current_level INTEGER;
    v_new_level INTEGER;
BEGIN
    -- Get current XP and coins with row lock
    SELECT xp, level, coins INTO v_current_xp, v_current_level, v_current_coins
    FROM profiles
    WHERE id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found: %', p_user_id;
    END IF;

    -- Calculate new values
    v_new_xp := v_current_xp + p_amount;
    v_new_level := calculate_level(v_new_xp);
    v_new_coins := v_current_coins + p_amount;  -- Award equal coins

    -- Update profile (XP + level + coins)
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

    -- Return result
    RETURN QUERY SELECT v_new_xp, v_new_level, (v_new_level > v_current_level);
END;
$$;

COMMENT ON FUNCTION award_xp_transaction IS 'Atomically award XP + coins to user, update level, and log both';
