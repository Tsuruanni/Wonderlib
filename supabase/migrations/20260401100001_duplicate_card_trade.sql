-- Duplicate Card Trade System

-- 1. Audit log table
CREATE TABLE card_trade_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id),
    traded_rarity VARCHAR(20) NOT NULL,
    traded_cards JSONB NOT NULL,
    total_cards_traded INTEGER NOT NULL,
    received_card_id UUID NOT NULL REFERENCES myth_cards(id),
    received_rarity VARCHAR(20) NOT NULL,
    was_new_card BOOLEAN NOT NULL,
    idempotency_key UUID UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_card_trade_logs_user ON card_trade_logs(user_id);

ALTER TABLE card_trade_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own trade logs"
    ON card_trade_logs FOR SELECT
    USING (user_id = auth.uid());

-- 2. Trade RPC
CREATE OR REPLACE FUNCTION trade_duplicate_cards(
    p_user_id UUID,
    p_card_quantities JSONB,
    p_target_rarity VARCHAR(20),
    p_idempotency_key UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_source_rarity VARCHAR(20);
    v_required_count INTEGER;
    v_total_given INTEGER := 0;
    v_card_id UUID;
    v_amount INTEGER;
    v_current_qty INTEGER;
    v_selected_card RECORD;
    v_existing RECORD;
    v_is_new BOOLEAN;
    v_new_qty INTEGER;
    v_roll DOUBLE PRECISION;
BEGIN
    -- Auth check
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Not authorized: user mismatch';
    END IF;

    -- Idempotency check
    IF p_idempotency_key IS NOT NULL THEN
        SELECT ctl.received_card_id, ctl.was_new_card,
               mc.card_no, mc.name, mc.category, mc.category_icon,
               mc.rarity, mc.power, mc.special_skill, mc.description, mc.image_url
        INTO v_existing
        FROM card_trade_logs ctl
        JOIN myth_cards mc ON mc.id = ctl.received_card_id
        WHERE ctl.idempotency_key = p_idempotency_key;

        IF FOUND THEN
            RETURN jsonb_build_object(
                'received_card', jsonb_build_object(
                    'id', v_existing.received_card_id,
                    'card_no', v_existing.card_no,
                    'name', v_existing.name,
                    'category', v_existing.category,
                    'category_icon', v_existing.category_icon,
                    'rarity', v_existing.rarity,
                    'power', v_existing.power,
                    'special_skill', v_existing.special_skill,
                    'description', v_existing.description,
                    'image_url', v_existing.image_url
                ),
                'is_new', v_existing.was_new_card,
                'quantity', (SELECT quantity FROM user_cards WHERE user_id = p_user_id AND card_id = v_existing.received_card_id),
                'already_processed', true
            );
        END IF;
    END IF;

    -- Determine source rarity and required count
    CASE p_target_rarity
        WHEN 'rare' THEN v_source_rarity := 'common'; v_required_count := 5;
        WHEN 'epic' THEN v_source_rarity := 'rare'; v_required_count := 4;
        WHEN 'legendary' THEN v_source_rarity := 'epic'; v_required_count := 3;
        ELSE RAISE EXCEPTION 'Invalid target rarity: %', p_target_rarity;
    END CASE;

    -- Validate all given cards
    FOR v_card_id, v_amount IN
        SELECT (key)::UUID, (value)::INTEGER
        FROM jsonb_each_text(p_card_quantities)
    LOOP
        IF v_amount < 1 THEN
            RAISE EXCEPTION 'Invalid amount for card %', v_card_id;
        END IF;

        SELECT uc.quantity INTO v_current_qty
        FROM user_cards uc
        JOIN myth_cards mc ON mc.id = uc.card_id
        WHERE uc.user_id = p_user_id
          AND uc.card_id = v_card_id
          AND mc.rarity = v_source_rarity
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Card % not owned or wrong rarity', v_card_id;
        END IF;

        IF v_current_qty - v_amount < 1 THEN
            RAISE EXCEPTION 'Must keep at least 1 copy of card %', v_card_id;
        END IF;

        v_total_given := v_total_given + v_amount;
    END LOOP;

    IF v_total_given != v_required_count THEN
        RAISE EXCEPTION 'Expected % cards, got %', v_required_count, v_total_given;
    END IF;

    -- Deduct cards
    FOR v_card_id, v_amount IN
        SELECT (key)::UUID, (value)::INTEGER
        FROM jsonb_each_text(p_card_quantities)
    LOOP
        UPDATE user_cards
        SET quantity = quantity - v_amount, updated_at = NOW()
        WHERE user_id = p_user_id AND card_id = v_card_id;
    END LOOP;

    -- Select result card: 80% unowned, 20% any
    v_roll := random();

    IF v_roll < 0.80 THEN
        SELECT mc.* INTO v_selected_card
        FROM myth_cards mc
        WHERE mc.rarity = p_target_rarity
          AND mc.is_active = true
          AND NOT EXISTS (
              SELECT 1 FROM user_cards uc
              WHERE uc.user_id = p_user_id AND uc.card_id = mc.id
          )
        ORDER BY random()
        LIMIT 1;
    END IF;

    IF v_selected_card IS NULL THEN
        SELECT mc.* INTO v_selected_card
        FROM myth_cards mc
        WHERE mc.rarity = p_target_rarity
          AND mc.is_active = true
        ORDER BY random()
        LIMIT 1;
    END IF;

    -- Upsert received card
    SELECT quantity INTO v_new_qty
    FROM user_cards
    WHERE user_id = p_user_id AND card_id = v_selected_card.id;

    IF FOUND THEN
        v_is_new := FALSE;
        v_new_qty := v_new_qty + 1;
        UPDATE user_cards
        SET quantity = v_new_qty, updated_at = NOW()
        WHERE user_id = p_user_id AND card_id = v_selected_card.id;
    ELSE
        v_is_new := TRUE;
        v_new_qty := 1;
        INSERT INTO user_cards (user_id, card_id, quantity)
        VALUES (p_user_id, v_selected_card.id, 1);
    END IF;

    -- Update stats
    UPDATE user_card_stats
    SET total_unique_cards = (
            SELECT COUNT(*) FROM user_cards WHERE user_id = p_user_id
        ),
        updated_at = NOW()
    WHERE user_id = p_user_id;

    -- Log the trade
    INSERT INTO card_trade_logs (
        user_id, traded_rarity, traded_cards, total_cards_traded,
        received_card_id, received_rarity, was_new_card, idempotency_key
    ) VALUES (
        p_user_id, v_source_rarity, p_card_quantities, v_total_given,
        v_selected_card.id, p_target_rarity, v_is_new, p_idempotency_key
    );

    RETURN jsonb_build_object(
        'received_card', jsonb_build_object(
            'id', v_selected_card.id,
            'card_no', v_selected_card.card_no,
            'name', v_selected_card.name,
            'category', v_selected_card.category,
            'category_icon', v_selected_card.category_icon,
            'rarity', v_selected_card.rarity,
            'power', v_selected_card.power,
            'special_skill', v_selected_card.special_skill,
            'description', v_selected_card.description,
            'image_url', v_selected_card.image_url
        ),
        'is_new', v_is_new,
        'quantity', v_new_qty
    );
END;
$$;
