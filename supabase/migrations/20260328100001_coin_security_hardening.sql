-- Coin Economy security hardening (Findings #1-4, #13, #14)
-- Adds auth.uid() checks to 4 RPCs, revokes direct UPDATE on monetary columns,
-- adds streak_freeze_count non-negative constraint, drops redundant index.

-- =============================================
-- 1. AUTH GUARD: award_coins_transaction (#2)
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
    -- Auth check: ensure caller is the user they claim to be
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Not authorized: user mismatch';
    END IF;

    -- Lock first
    SELECT coins INTO v_current_coins
    FROM profiles
    WHERE id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found: %', p_user_id;
    END IF;

    -- Idempotency check after lock
    IF p_source_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM coin_logs
        WHERE user_id = p_user_id AND source = p_source AND source_id = p_source_id
    ) THEN
        RETURN QUERY SELECT v_current_coins;
        RETURN;
    END IF;

    v_new_coins := v_current_coins + p_amount;

    IF v_new_coins < 0 THEN
        RAISE EXCEPTION 'Insufficient coins. Current: %, Requested: %', v_current_coins, p_amount;
    END IF;

    UPDATE profiles
    SET coins = v_new_coins, updated_at = NOW()
    WHERE id = p_user_id;

    INSERT INTO coin_logs (user_id, amount, balance_after, source, source_id, description)
    VALUES (p_user_id, p_amount, v_new_coins, p_source, p_source_id, p_description);

    RETURN QUERY SELECT v_new_coins;
END;
$$;

-- =============================================
-- 2. AUTH GUARD: spend_coins_transaction (#2)
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
    -- Auth check: ensure caller is the user they claim to be
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Not authorized: user mismatch';
    END IF;

    -- Negate amount to spend
    RETURN QUERY SELECT * FROM award_coins_transaction(
        p_user_id, -p_amount, p_source, p_source_id, p_description
    );
END;
$$;

-- =============================================
-- 3. AUTH GUARD: buy_card_pack (#3)
-- =============================================
CREATE OR REPLACE FUNCTION buy_card_pack(
    p_user_id UUID,
    p_pack_cost INTEGER DEFAULT 100
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_coins INTEGER;
    v_new_coins INTEGER;
    v_new_packs INTEGER;
BEGIN
    -- Auth check: ensure caller is the user they claim to be
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Not authorized: user mismatch';
    END IF;

    -- Lock user row and check balance
    SELECT coins, unopened_packs INTO v_current_coins, v_new_packs
    FROM profiles
    WHERE id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found: %', p_user_id;
    END IF;

    IF v_current_coins < p_pack_cost THEN
        RAISE EXCEPTION 'Insufficient coins. Have: %, Need: %', v_current_coins, p_pack_cost;
    END IF;

    -- Deduct coins, increment packs
    v_new_coins := v_current_coins - p_pack_cost;
    v_new_packs := v_new_packs + 1;

    UPDATE profiles
    SET coins = v_new_coins,
        unopened_packs = v_new_packs,
        updated_at = NOW()
    WHERE id = p_user_id;

    -- Log coin transaction
    INSERT INTO coin_logs (user_id, amount, balance_after, source, description)
    VALUES (p_user_id, -p_pack_cost, v_new_coins, 'pack_purchase', 'Card pack purchased (stored)');

    RETURN jsonb_build_object(
        'coins_spent', p_pack_cost,
        'coins_remaining', v_new_coins,
        'unopened_packs', v_new_packs
    );
END;
$$;

-- =============================================
-- 4. AUTH GUARD: open_card_pack (#4)
-- =============================================
CREATE OR REPLACE FUNCTION open_card_pack(
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_packs INTEGER;
    v_pity_counter INTEGER;
    v_total_packs INTEGER;
    v_card_ids UUID[] := ARRAY[]::UUID[];
    v_result_cards JSONB := '[]'::JSONB;
    v_selected_card RECORD;
    v_slot INTEGER;
    v_roll DOUBLE PRECISION;
    v_target_rarity VARCHAR(20);
    v_is_new BOOLEAN;
    v_current_qty INTEGER;
    v_best_rarity VARCHAR(20) := 'common';
    v_pity_triggered BOOLEAN := FALSE;
    v_rarity_order INTEGER;
    v_best_order INTEGER := 0;
BEGIN
    -- Auth check: ensure caller is the user they claim to be
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Not authorized: user mismatch';
    END IF;

    -- ===== 1. CHECK & DECREMENT PACK INVENTORY =====
    SELECT unopened_packs INTO v_current_packs
    FROM profiles
    WHERE id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found: %', p_user_id;
    END IF;

    IF v_current_packs < 1 THEN
        RAISE EXCEPTION 'No unopened packs available';
    END IF;

    -- Decrement pack count
    UPDATE profiles
    SET unopened_packs = unopened_packs - 1,
        updated_at = NOW()
    WHERE id = p_user_id;

    -- ===== 2. GET/CREATE PITY COUNTER =====
    SELECT packs_since_legendary, total_packs_opened
    INTO v_pity_counter, v_total_packs
    FROM user_card_stats
    WHERE user_id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        INSERT INTO user_card_stats (user_id, packs_since_legendary, total_packs_opened, total_unique_cards)
        VALUES (p_user_id, 0, 0, 0);
        v_pity_counter := 0;
        v_total_packs := 0;
    END IF;

    -- ===== 3. ROLL 3 CARDS =====
    FOR v_slot IN 1..3 LOOP
        v_roll := random();

        IF v_slot <= 2 THEN
            IF v_roll < 0.03 THEN
                v_target_rarity := 'legendary';
            ELSIF v_roll < 0.15 THEN
                v_target_rarity := 'epic';
            ELSIF v_roll < 0.40 THEN
                v_target_rarity := 'rare';
            ELSE
                v_target_rarity := 'common';
            END IF;
        ELSE
            IF v_pity_counter >= 14 THEN
                v_target_rarity := 'legendary';
                v_pity_triggered := TRUE;
            ELSIF v_roll < 0.10 THEN
                v_target_rarity := 'legendary';
            ELSIF v_roll < 0.40 THEN
                v_target_rarity := 'epic';
            ELSE
                v_target_rarity := 'rare';
            END IF;
        END IF;

        SELECT mc.* INTO v_selected_card
        FROM myth_cards mc
        WHERE mc.rarity = v_target_rarity
        AND mc.is_active = true
        AND mc.id != ALL(v_card_ids)
        ORDER BY random()
        LIMIT 1;

        IF NOT FOUND THEN
            SELECT mc.* INTO v_selected_card
            FROM myth_cards mc
            WHERE mc.is_active = true
            AND mc.id != ALL(v_card_ids)
            ORDER BY random()
            LIMIT 1;
        END IF;

        v_card_ids := array_append(v_card_ids, v_selected_card.id);

        -- ===== 4. UPSERT USER_CARDS =====
        SELECT quantity INTO v_current_qty
        FROM user_cards
        WHERE user_id = p_user_id AND card_id = v_selected_card.id;

        IF FOUND THEN
            v_is_new := FALSE;
            v_current_qty := v_current_qty + 1;
            UPDATE user_cards
            SET quantity = v_current_qty, updated_at = NOW()
            WHERE user_id = p_user_id AND card_id = v_selected_card.id;
        ELSE
            v_is_new := TRUE;
            v_current_qty := 1;
            INSERT INTO user_cards (user_id, card_id, quantity)
            VALUES (p_user_id, v_selected_card.id, 1);
        END IF;

        v_rarity_order := CASE v_selected_card.rarity
            WHEN 'common' THEN 1
            WHEN 'rare' THEN 2
            WHEN 'epic' THEN 3
            WHEN 'legendary' THEN 4
        END;
        IF v_rarity_order > v_best_order THEN
            v_best_order := v_rarity_order;
            v_best_rarity := v_selected_card.rarity;
        END IF;

        v_result_cards := v_result_cards || jsonb_build_object(
            'id', v_selected_card.id,
            'card_no', v_selected_card.card_no,
            'name', v_selected_card.name,
            'category', v_selected_card.category,
            'category_icon', v_selected_card.category_icon,
            'rarity', v_selected_card.rarity,
            'power', v_selected_card.power,
            'special_skill', v_selected_card.special_skill,
            'description', v_selected_card.description,
            'is_new', v_is_new,
            'quantity', v_current_qty
        );
    END LOOP;

    -- ===== 5. UPDATE PITY COUNTER =====
    IF v_best_rarity = 'legendary' THEN
        v_pity_counter := 0;
    ELSE
        v_pity_counter := v_pity_counter + 1;
    END IF;

    -- ===== 6. UPDATE STATS =====
    UPDATE user_card_stats
    SET packs_since_legendary = v_pity_counter,
        total_packs_opened = v_total_packs + 1,
        total_unique_cards = (
            SELECT COUNT(*) FROM user_cards WHERE user_id = p_user_id
        ),
        updated_at = NOW()
    WHERE user_id = p_user_id;

    -- ===== 7. LOG PACK OPENING =====
    INSERT INTO pack_purchases (user_id, cost, card_ids, pity_counter_at_purchase)
    VALUES (p_user_id, 0, v_card_ids, v_pity_counter);

    -- ===== 8. RETURN RESULT =====
    RETURN jsonb_build_object(
        'cards', v_result_cards,
        'pack_glow_rarity', v_best_rarity,
        'packs_remaining', (SELECT unopened_packs FROM profiles WHERE id = p_user_id),
        'pity_triggered', v_pity_triggered
    );
END;
$$;

-- =============================================
-- 5. COLUMN-LEVEL REVOKE on profiles (#1)
-- Prevents direct UPDATE on monetary columns from authenticated role.
-- SECURITY DEFINER functions execute as owner and bypass this.
-- =============================================
REVOKE UPDATE(coins, unopened_packs, streak_freeze_count) ON profiles FROM authenticated;

-- =============================================
-- 6. streak_freeze_count non-negative constraint (#13)
-- =============================================
ALTER TABLE profiles
    ADD CONSTRAINT chk_streak_freeze_non_negative CHECK (streak_freeze_count >= 0);

-- =============================================
-- 7. Drop redundant index (#14)
-- idx_coin_logs_user_id is superseded by idx_coin_logs_user_created
-- =============================================
DROP INDEX IF EXISTS idx_coin_logs_user_id;
