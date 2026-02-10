-- Migration: Pack Inventory System
-- Allows users to store packs (from purchases and daily quest rewards) and open them later

-- =============================================
-- 1. ADD UNOPENED_PACKS COUNTER TO PROFILES
-- =============================================
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS unopened_packs INTEGER DEFAULT 0;

-- =============================================
-- 2. DAILY QUEST PACK CLAIMS (prevent double-claim per day)
-- NOTE: INSERT/UPDATE are done via SECURITY DEFINER functions only.
--       No INSERT/UPDATE RLS policies needed — direct table writes are blocked by RLS.
-- =============================================
CREATE TABLE IF NOT EXISTS daily_quest_pack_claims (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    claim_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, claim_date)
);

ALTER TABLE daily_quest_pack_claims ENABLE ROW LEVEL SECURITY;

-- Performance: composite index for daily claim lookup
CREATE INDEX IF NOT EXISTS idx_daily_quest_pack_claims_user_date
    ON daily_quest_pack_claims(user_id, claim_date);

CREATE POLICY "Users can read own claims"
    ON daily_quest_pack_claims FOR SELECT
    USING (auth.uid() = user_id);

-- =============================================
-- 3. BUY CARD PACK (coins → inventory)
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

COMMENT ON FUNCTION buy_card_pack IS 'Buy a card pack with coins and add to inventory (does not open immediately)';

-- =============================================
-- 4. DROP OLD open_card_pack (had unused p_pack_cost param)
--    Then recreate with clean signature (UUID only)
-- =============================================
DROP FUNCTION IF EXISTS open_card_pack(UUID, INTEGER);

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
        AND mc.id != ALL(v_card_ids)
        ORDER BY random()
        LIMIT 1;

        -- Fallback: if no cards available at target rarity
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

COMMENT ON FUNCTION open_card_pack IS 'Open a card pack from inventory: decrement pack count, roll 3 cards with weighted randomness + pity system';

-- =============================================
-- 5. CLAIM DAILY QUEST PACK (quest reward → inventory)
-- Uses FOR UPDATE lock on profiles to prevent race conditions
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

    -- Check if already claimed today (UNIQUE constraint is a safety net, but check first for better error)
    IF EXISTS (
        SELECT 1 FROM daily_quest_pack_claims
        WHERE user_id = p_user_id AND claim_date = CURRENT_DATE
    ) THEN
        RAISE EXCEPTION 'Daily quest pack already claimed today';
    END IF;

    -- Record claim
    INSERT INTO daily_quest_pack_claims (user_id, claim_date)
    VALUES (p_user_id, CURRENT_DATE);

    -- Increment unopened packs (row is already locked)
    UPDATE profiles
    SET unopened_packs = unopened_packs + 1,
        updated_at = NOW()
    WHERE id = p_user_id
    RETURNING unopened_packs INTO v_new_packs;

    RETURN jsonb_build_object(
        'success', true,
        'unopened_packs', v_new_packs
    );
END;
$$;

COMMENT ON FUNCTION claim_daily_quest_pack IS 'Award a free card pack for completing all daily quests (once per day)';

-- =============================================
-- 6. CHECK DAILY QUEST PACK CLAIM STATUS (server-side date)
-- Avoids client/server timezone mismatch at midnight
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
        WHERE user_id = p_user_id AND claim_date = CURRENT_DATE
    );
END;
$$;

COMMENT ON FUNCTION has_daily_quest_pack_claimed IS 'Check if daily quest pack was already claimed today (uses server date)';
