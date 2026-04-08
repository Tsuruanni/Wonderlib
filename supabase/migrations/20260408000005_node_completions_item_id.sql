-- =============================================
-- Add item_id to user_node_completions for per-node tracking
-- Previously: UNIQUE(user_id, unit_id, node_type) = one completion per type per unit
-- Now: UNIQUE(user_id, unit_id, node_type, item_id) = one completion per specific node
-- =============================================

-- 1. Add nullable item_id column
ALTER TABLE user_node_completions
    ADD COLUMN IF NOT EXISTS item_id UUID;

-- 2. Drop old unique constraint and create new one
ALTER TABLE user_node_completions
    DROP CONSTRAINT IF EXISTS user_node_completions_user_id_unit_id_node_type_key;

-- For backwards compatibility: existing rows have item_id = NULL
-- New treasure/game completions will have item_id set
CREATE UNIQUE INDEX idx_node_completions_per_item
    ON user_node_completions(user_id, unit_id, node_type, item_id)
    WHERE item_id IS NOT NULL;

-- Keep old unique index for flipbook/daily_review (they don't have item_id)
CREATE UNIQUE INDEX idx_node_completions_legacy
    ON user_node_completions(user_id, unit_id, node_type)
    WHERE item_id IS NULL;

-- 3. Update spin_treasure_wheel to accept and store item_id
CREATE OR REPLACE FUNCTION spin_treasure_wheel(
    p_user_id UUID,
    p_unit_id UUID,
    p_item_id UUID
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
BEGIN
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Not authorized: user mismatch';
    END IF;

    -- Check THIS specific treasure node (by item_id)
    SELECT EXISTS(
        SELECT 1 FROM user_node_completions
        WHERE user_id = p_user_id
          AND unit_id = p_unit_id
          AND node_type = 'treasure'
          AND item_id = p_item_id
    ) INTO v_existing;

    IF v_existing THEN
        RAISE EXCEPTION 'ALREADY_CLAIMED';
    END IF;

    SELECT COALESCE(SUM(weight), 0) INTO v_total_weight
    FROM treasure_wheel_slices
    WHERE is_active = true;

    IF v_total_weight = 0 THEN
        RAISE EXCEPTION 'No active wheel slices configured';
    END IF;

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

    IF v_winning_slice IS NULL THEN
        SELECT id, label, reward_type, reward_amount, weight, color, sort_order
        INTO v_winning_slice
        FROM treasure_wheel_slices
        WHERE is_active = true
        ORDER BY sort_order DESC
        LIMIT 1;
        v_winning_index := v_current_index;
    END IF;

    IF v_winning_slice.reward_type = 'coin' THEN
        PERFORM award_coins_transaction(
            p_user_id,
            v_winning_slice.reward_amount,
            'treasure_wheel'::VARCHAR,
            p_unit_id,
            v_winning_slice.label
        );
    ELSIF v_winning_slice.reward_type = 'card_pack' THEN
        UPDATE profiles
        SET unopened_packs = unopened_packs + v_winning_slice.reward_amount,
            updated_at = NOW()
        WHERE id = p_user_id;
    END IF;

    -- Store with item_id for per-node tracking
    INSERT INTO user_node_completions (user_id, unit_id, node_type, item_id)
    VALUES (p_user_id, p_unit_id, 'treasure', p_item_id);

    RETURN jsonb_build_object(
        'slice_index', v_winning_index,
        'slice_label', v_winning_slice.label,
        'reward_type', v_winning_slice.reward_type,
        'reward_amount', v_winning_slice.reward_amount
    );
END;
$$;
