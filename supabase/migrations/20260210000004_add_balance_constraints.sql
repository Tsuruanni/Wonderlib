-- Migration: Balance Constraints + XP Idempotency
-- Adds safety constraints and prevents duplicate XP awards on network retry

-- =============================================
-- 1. CHECK CONSTRAINTS (belt-and-suspenders)
-- =============================================

-- Prevent coins from going negative (FOR UPDATE locks already protect,
-- but this catches any direct SQL bypass)
ALTER TABLE profiles
  ADD CONSTRAINT chk_coins_non_negative CHECK (coins >= 0);

ALTER TABLE profiles
  ADD CONSTRAINT chk_unopened_packs_non_negative CHECK (unopened_packs >= 0);

-- =============================================
-- 2. XP IDEMPOTENCY INDEX
-- =============================================

-- Prevent duplicate XP awards for the same source event (e.g. network retry)
-- source_id can be NULL for manual/badge awards, COALESCE makes the index work
CREATE UNIQUE INDEX IF NOT EXISTS idx_xp_logs_idempotent
  ON xp_logs (user_id, source, COALESCE(source_id, '00000000-0000-0000-0000-000000000000'));

-- =============================================
-- 3. UPDATED award_xp_transaction WITH IDEMPOTENCY GUARD
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
    -- Idempotency guard: if this exact award was already given, return current state
    -- Only checks when source_id is provided (NULL source_id = manual/badge awards, always allowed)
    IF p_source_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM xp_logs
        WHERE user_id = p_user_id AND source = p_source AND source_id = p_source_id
    ) THEN
        SELECT xp, level INTO v_current_xp, v_current_level
        FROM profiles WHERE id = p_user_id;
        RETURN QUERY SELECT v_current_xp, v_current_level, FALSE;
        RETURN;
    END IF;

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

COMMENT ON FUNCTION award_xp_transaction IS 'Atomically award XP + coins to user with idempotency protection';
