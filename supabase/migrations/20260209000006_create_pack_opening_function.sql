-- Migration: Pack Opening RPC Function
-- Mythic Scholars Arena - Atomic pack opening with weighted randomness + pity system

-- =============================================
-- OPEN CARD PACK
-- =============================================
CREATE OR REPLACE FUNCTION open_card_pack(
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
    -- ===== 1. CHECK COIN BALANCE =====
    SELECT coins INTO v_current_coins
    FROM profiles
    WHERE id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found: %', p_user_id;
    END IF;

    IF v_current_coins < p_pack_cost THEN
        RAISE EXCEPTION 'Insufficient coins. Have: %, Need: %', v_current_coins, p_pack_cost;
    END IF;

    -- ===== 2. DEDUCT COINS =====
    v_new_coins := v_current_coins - p_pack_cost;
    UPDATE profiles SET coins = v_new_coins, updated_at = NOW() WHERE id = p_user_id;

    INSERT INTO coin_logs (user_id, amount, balance_after, source, description)
    VALUES (p_user_id, -p_pack_cost, v_new_coins, 'pack_purchase', 'Card pack purchase');

    -- ===== 3. GET/CREATE PITY COUNTER =====
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

    -- ===== 4. ROLL 3 CARDS =====
    FOR v_slot IN 1..3 LOOP
        v_roll := random();

        IF v_slot <= 2 THEN
            -- Slot 1-2: All rarities with weighted probability
            -- Common 60%, Rare 25%, Epic 12%, Legendary 3%
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
            -- Slot 3: Guaranteed Rare+ (Rare 60%, Epic 30%, Legendary 10%)
            -- PITY SYSTEM: If 14+ packs without legendary, force legendary
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

        -- Select random card of target rarity (avoid duplicates within same pack)
        SELECT mc.* INTO v_selected_card
        FROM myth_cards mc
        WHERE mc.rarity = v_target_rarity
        AND mc.is_active = true
        AND mc.id != ALL(v_card_ids)  -- No duplicate cards in same pack
        ORDER BY random()
        LIMIT 1;

        -- Fallback: if no cards available at target rarity (shouldn't happen)
        IF NOT FOUND THEN
            SELECT mc.* INTO v_selected_card
            FROM myth_cards mc
            WHERE mc.is_active = true
            AND mc.id != ALL(v_card_ids)
            ORDER BY random()
            LIMIT 1;
        END IF;

        -- Add to pack
        v_card_ids := array_append(v_card_ids, v_selected_card.id);

        -- ===== 5. UPSERT USER_CARDS =====
        -- Check if user already owns this card
        SELECT quantity INTO v_current_qty
        FROM user_cards
        WHERE user_id = p_user_id AND card_id = v_selected_card.id;

        IF FOUND THEN
            -- Duplicate: increment quantity
            v_is_new := FALSE;
            v_current_qty := v_current_qty + 1;
            UPDATE user_cards
            SET quantity = v_current_qty, updated_at = NOW()
            WHERE user_id = p_user_id AND card_id = v_selected_card.id;
        ELSE
            -- New card
            v_is_new := TRUE;
            v_current_qty := 1;
            INSERT INTO user_cards (user_id, card_id, quantity)
            VALUES (p_user_id, v_selected_card.id, 1);
        END IF;

        -- Track best rarity for pack glow
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

        -- Build card result JSON
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

    -- ===== 6. UPDATE PITY COUNTER =====
    IF v_best_rarity = 'legendary' THEN
        v_pity_counter := 0;  -- Reset pity on legendary
    ELSE
        v_pity_counter := v_pity_counter + 1;
    END IF;

    -- ===== 7. UPDATE STATS =====
    UPDATE user_card_stats
    SET packs_since_legendary = v_pity_counter,
        total_packs_opened = v_total_packs + 1,
        total_unique_cards = (
            SELECT COUNT(*) FROM user_cards WHERE user_id = p_user_id
        ),
        updated_at = NOW()
    WHERE user_id = p_user_id;

    -- ===== 8. LOG PACK PURCHASE =====
    INSERT INTO pack_purchases (user_id, cost, card_ids, pity_counter_at_purchase)
    VALUES (p_user_id, p_pack_cost, v_card_ids, v_pity_counter);

    -- ===== 9. RETURN RESULT =====
    RETURN jsonb_build_object(
        'cards', v_result_cards,
        'pack_glow_rarity', v_best_rarity,
        'coins_spent', p_pack_cost,
        'coins_remaining', v_new_coins,
        'pity_triggered', v_pity_triggered
    );
END;
$$;

COMMENT ON FUNCTION open_card_pack IS 'Atomically open a card pack: deduct coins, roll 3 cards with weighted randomness, pity system, and return results';
