-- Fix JSONB → INT cast in helper functions and buy_streak_freeze
-- system_settings.value is JSONB. Direct ::INT cast fails on JSONB strings.
-- Use (value#>>'{}')::INT to extract JSONB scalar as text first, then cast.

-- 1. Fix app_current_date
CREATE OR REPLACE FUNCTION app_current_date() RETURNS DATE AS $$
  SELECT (CURRENT_DATE + COALESCE(
    (SELECT (value#>>'{}')::INT FROM system_settings WHERE key = 'debug_date_offset'), 0
  ))::DATE;
$$ LANGUAGE sql STABLE;

-- 2. Fix app_now
CREATE OR REPLACE FUNCTION app_now() RETURNS TIMESTAMPTZ AS $$
  SELECT NOW() + COALESCE(
    (SELECT (value#>>'{}')::INT FROM system_settings WHERE key = 'debug_date_offset'), 0
  ) * INTERVAL '1 day';
$$ LANGUAGE sql STABLE;

-- 3. Fix buy_streak_freeze
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

    -- Read settings (JSONB → text → int)
    SELECT (value#>>'{}')::INT INTO v_max FROM system_settings WHERE key = 'streak_freeze_max';
    SELECT (value#>>'{}')::INT INTO v_price FROM system_settings WHERE key = 'streak_freeze_price';

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
