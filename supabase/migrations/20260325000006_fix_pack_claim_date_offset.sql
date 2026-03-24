-- Fix: claim_daily_quest_pack and has_daily_quest_pack_claimed still use raw
-- CURRENT_DATE/NOW() instead of app_current_date()/app_now().
-- They were missed by 20260323000006_debug_time_offset.sql.

-- =============================================
-- A. claim_daily_quest_pack
-- Base: 20260209000007_add_pack_inventory.sql
-- Change: CURRENT_DATE → app_current_date(), NOW() → app_now()
-- =============================================
CREATE OR REPLACE FUNCTION claim_daily_quest_pack(
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_new_packs INTEGER;
BEGIN
    -- Lock profiles row first to serialize concurrent requests
    PERFORM id FROM profiles WHERE id = p_user_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found: %', p_user_id;
    END IF;

    -- Check if already claimed today
    IF EXISTS (
        SELECT 1 FROM daily_quest_pack_claims
        WHERE user_id = p_user_id AND claim_date = app_current_date()
    ) THEN
        RAISE EXCEPTION 'Daily quest pack already claimed today';
    END IF;

    -- Record claim
    INSERT INTO daily_quest_pack_claims (user_id, claim_date)
    VALUES (p_user_id, app_current_date());

    -- Increment unopened packs (row is already locked)
    UPDATE profiles
    SET unopened_packs = unopened_packs + 1,
        updated_at = app_now()
    WHERE id = p_user_id
    RETURNING unopened_packs INTO v_new_packs;

    RETURN jsonb_build_object(
        'success', true,
        'unopened_packs', v_new_packs
    );
END;
$$;

-- =============================================
-- B. has_daily_quest_pack_claimed
-- Base: 20260209000007_add_pack_inventory.sql
-- Change: CURRENT_DATE → app_current_date()
-- =============================================
CREATE OR REPLACE FUNCTION has_daily_quest_pack_claimed(
    p_user_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM daily_quest_pack_claims
        WHERE user_id = p_user_id AND claim_date = app_current_date()
    );
END;
$$;
