-- =============================================
-- TREASURE WHEEL: Table + RPC + RLS
-- Spec: docs/superpowers/specs/2026-04-07-treasure-wheel-design.md
-- =============================================

-- ===== 1. TABLE =====

CREATE TABLE treasure_wheel_slices (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    label       TEXT NOT NULL,
    reward_type TEXT NOT NULL CHECK (reward_type IN ('coin', 'card_pack')),
    reward_amount INTEGER NOT NULL CHECK (reward_amount > 0),
    weight      INTEGER NOT NULL CHECK (weight > 0),
    color       TEXT NOT NULL,
    sort_order  INTEGER NOT NULL DEFAULT 0,
    is_active   BOOLEAN NOT NULL DEFAULT true,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ===== 2. RLS =====

ALTER TABLE treasure_wheel_slices ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read (students need slices to render the wheel)
CREATE POLICY "Authenticated users can read wheel slices"
    ON treasure_wheel_slices FOR SELECT
    TO authenticated
    USING (true);

-- Only admins can modify
CREATE POLICY "Admins can insert wheel slices"
    ON treasure_wheel_slices FOR INSERT
    TO authenticated
    WITH CHECK (is_admin());

CREATE POLICY "Admins can update wheel slices"
    ON treasure_wheel_slices FOR UPDATE
    TO authenticated
    USING (is_admin())
    WITH CHECK (is_admin());

CREATE POLICY "Admins can delete wheel slices"
    ON treasure_wheel_slices FOR DELETE
    TO authenticated
    USING (is_admin());

-- ===== 3. SEED DEFAULT SLICES =====

INSERT INTO treasure_wheel_slices (label, reward_type, reward_amount, weight, color, sort_order) VALUES
    ('10 Coins',     'coin',      10,  40, '#4CAF50', 0),
    ('25 Coins',     'coin',      25,  25, '#2196F3', 1),
    ('50 Coins',     'coin',      50,  15, '#9C27B0', 2),
    ('100 Coins',    'coin',     100,   7, '#FF9800', 3),
    ('1 Card Pack',  'card_pack',  1,  10, '#E91E63', 4),
    ('2 Card Packs', 'card_pack',  2,   3, '#F44336', 5);

-- ===== 4. RPC: spin_treasure_wheel =====

CREATE OR REPLACE FUNCTION spin_treasure_wheel(
    p_user_id UUID,
    p_unit_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_existing BOOLEAN;
    v_slices RECORD;
    v_total_weight INTEGER;
    v_roll DOUBLE PRECISION;
    v_cumulative INTEGER := 0;
    v_winning_slice RECORD;
    v_winning_index INTEGER := 0;
    v_current_index INTEGER := 0;
    v_all_cards JSONB := '[]'::JSONB;
    v_pack_result JSONB;
    v_i INTEGER;
BEGIN
    -- Auth check
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Not authorized: user mismatch';
    END IF;

    -- Duplicate check: already claimed this treasure?
    SELECT EXISTS(
        SELECT 1 FROM user_node_completions
        WHERE user_id = p_user_id
          AND unit_id = p_unit_id
          AND node_type = 'treasure'
    ) INTO v_existing;

    IF v_existing THEN
        RAISE EXCEPTION 'ALREADY_CLAIMED';
    END IF;

    -- Get total weight of active slices
    SELECT COALESCE(SUM(weight), 0) INTO v_total_weight
    FROM treasure_wheel_slices
    WHERE is_active = true;

    IF v_total_weight = 0 THEN
        RAISE EXCEPTION 'No active wheel slices configured';
    END IF;

    -- Weighted random selection
    v_roll := random() * v_total_weight;

    FOR v_slices IN
        SELECT id, label, reward_type, reward_amount, weight, color, sort_order
        FROM treasure_wheel_slices
        WHERE is_active = true
        ORDER BY sort_order
    LOOP
        v_cumulative := v_cumulative + v_slices.weight;
        IF v_roll <= v_cumulative THEN
            v_winning_slice := v_slices;
            v_winning_index := v_current_index;
            EXIT;
        END IF;
        v_current_index := v_current_index + 1;
    END LOOP;

    -- Fallback: if somehow no slice was selected (rounding), pick last
    IF v_winning_slice IS NULL THEN
        SELECT id, label, reward_type, reward_amount, weight, color, sort_order
        INTO v_winning_slice
        FROM treasure_wheel_slices
        WHERE is_active = true
        ORDER BY sort_order DESC
        LIMIT 1;
        v_winning_index := v_current_index;
    END IF;

    -- Award the reward
    IF v_winning_slice.reward_type = 'coin' THEN
        -- Award coins using existing function
        PERFORM award_coins_transaction(
            p_user_id,
            v_winning_slice.reward_amount,
            'treasure_wheel',
            p_unit_id::TEXT,
            v_winning_slice.label
        );

    ELSIF v_winning_slice.reward_type = 'card_pack' THEN
        -- Add packs to inventory, then open each one
        UPDATE profiles
        SET unopened_packs = unopened_packs + v_winning_slice.reward_amount,
            updated_at = NOW()
        WHERE id = p_user_id;

        -- Open each pack and collect cards
        FOR v_i IN 1..v_winning_slice.reward_amount LOOP
            v_pack_result := open_card_pack(p_user_id);
            v_all_cards := v_all_cards || (v_pack_result->'cards');
        END LOOP;
    END IF;

    -- Mark treasure as completed
    INSERT INTO user_node_completions (user_id, unit_id, node_type)
    VALUES (p_user_id, p_unit_id, 'treasure');

    -- Return result
    RETURN jsonb_build_object(
        'slice_index', v_winning_index,
        'slice_label', v_winning_slice.label,
        'reward_type', v_winning_slice.reward_type,
        'reward_amount', v_winning_slice.reward_amount,
        'cards', v_all_cards
    );
END;
$$;
