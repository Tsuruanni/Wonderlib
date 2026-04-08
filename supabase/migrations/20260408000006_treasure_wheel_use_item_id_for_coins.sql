-- =============================================
-- FIX: Use p_item_id (not p_unit_id) as source_id for coin awards
-- Prevents idempotency check from blocking second treasure in same unit
-- =============================================

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
        -- Use p_item_id as source_id (not p_unit_id) so each treasure node
        -- has its own idempotency key in coin_logs
        PERFORM award_coins_transaction(
            p_user_id,
            v_winning_slice.reward_amount,
            'treasure_wheel'::VARCHAR,
            p_item_id,
            v_winning_slice.label
        );
    ELSIF v_winning_slice.reward_type = 'card_pack' THEN
        UPDATE profiles
        SET unopened_packs = unopened_packs + v_winning_slice.reward_amount,
            updated_at = NOW()
        WHERE id = p_user_id;
    END IF;

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
