-- =============================================
-- PER-ANIMAL OUTFIT MEMORY
-- Stores equipped items per base animal so switching
-- between animals preserves their last outfit.
--
-- Format: {"base_uuid_1": ["item_uuid_a", "item_uuid_b"], ...}
-- =============================================

ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS avatar_outfits JSONB DEFAULT '{}'::jsonb;

-- =============================================
-- UPDATED: set_avatar_base — save/restore outfits per animal
-- =============================================
CREATE OR REPLACE FUNCTION set_avatar_base(p_base_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_old_base_id UUID;
    v_equipped_item_ids UUID[];
    v_outfits JSONB;
    v_restore_ids UUID[];
    v_item_id UUID;
    v_category_id UUID;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM avatar_bases WHERE id = p_base_id) THEN
        RAISE EXCEPTION 'Avatar base not found';
    END IF;

    -- Get current state
    SELECT avatar_base_id, COALESCE(avatar_outfits, '{}'::jsonb)
    INTO v_old_base_id, v_outfits
    FROM profiles WHERE id = v_user_id;

    -- Save current outfit for old base (if any)
    IF v_old_base_id IS NOT NULL THEN
        SELECT ARRAY_AGG(item_id) INTO v_equipped_item_ids
        FROM user_avatar_items
        WHERE user_id = v_user_id AND is_equipped = true;

        IF v_equipped_item_ids IS NOT NULL THEN
            v_outfits = jsonb_set(v_outfits, ARRAY[v_old_base_id::text],
                to_jsonb(v_equipped_item_ids));
        ELSE
            v_outfits = jsonb_set(v_outfits, ARRAY[v_old_base_id::text], '[]'::jsonb);
        END IF;
    END IF;

    -- Unequip all
    UPDATE user_avatar_items SET is_equipped = false
    WHERE user_id = v_user_id AND is_equipped = true;

    -- Set new base
    UPDATE profiles
    SET avatar_base_id = p_base_id, avatar_outfits = v_outfits
    WHERE id = v_user_id;

    -- Restore outfit for new base (if saved before)
    IF v_outfits ? p_base_id::text THEN
        SELECT ARRAY(
            SELECT (jsonb_array_elements_text(v_outfits -> p_base_id::text))::UUID
        ) INTO v_restore_ids;

        IF v_restore_ids IS NOT NULL THEN
            FOREACH v_item_id IN ARRAY v_restore_ids LOOP
                -- Only equip if user still owns the item
                IF EXISTS (SELECT 1 FROM user_avatar_items WHERE user_id = v_user_id AND item_id = v_item_id) THEN
                    -- Get category to check for conflicts
                    SELECT ai.category_id INTO v_category_id
                    FROM avatar_items ai WHERE ai.id = v_item_id;

                    -- Unequip same-category item first
                    UPDATE user_avatar_items SET is_equipped = false
                    WHERE user_id = v_user_id AND is_equipped = true
                      AND item_id IN (SELECT id FROM avatar_items WHERE category_id = v_category_id);

                    UPDATE user_avatar_items SET is_equipped = true
                    WHERE user_id = v_user_id AND item_id = v_item_id;
                END IF;
            END LOOP;
        END IF;
    END IF;

    -- Rebuild cache
    PERFORM _rebuild_avatar_cache(v_user_id);
END;
$$;

COMMENT ON FUNCTION set_avatar_base IS 'Set base animal, save current outfit, restore previously saved outfit for new animal.';

-- =============================================
-- UPDATED: buy_avatar_item — auto-equip after purchase
-- =============================================
CREATE OR REPLACE FUNCTION buy_avatar_item(p_item_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_item RECORD;
    v_current_coins INT;
    v_coins_remaining INT;
    v_category_id UUID;
BEGIN
    SELECT id, display_name, coin_price, is_active, category_id INTO v_item
    FROM avatar_items WHERE id = p_item_id;

    IF v_item.id IS NULL THEN
        RAISE EXCEPTION 'Avatar item not found';
    END IF;

    IF NOT v_item.is_active THEN
        RAISE EXCEPTION 'Avatar item is not available';
    END IF;

    IF EXISTS (SELECT 1 FROM user_avatar_items WHERE user_id = v_user_id AND item_id = p_item_id) THEN
        RAISE EXCEPTION 'Already owned';
    END IF;

    SELECT coins INTO v_current_coins FROM profiles WHERE id = v_user_id;
    IF v_current_coins < v_item.coin_price THEN
        RAISE EXCEPTION 'Insufficient coins';
    END IF;

    PERFORM spend_coins_transaction(
        v_user_id,
        v_item.coin_price,
        'avatar_item',
        p_item_id,
        'Purchased: ' || v_item.display_name
    );

    -- Insert ownership
    INSERT INTO user_avatar_items (user_id, item_id, is_equipped)
    VALUES (v_user_id, p_item_id, false);

    -- Auto-equip: unequip same category, equip new item
    UPDATE user_avatar_items SET is_equipped = false
    WHERE user_id = v_user_id AND is_equipped = true
      AND item_id IN (SELECT id FROM avatar_items WHERE category_id = v_item.category_id);

    UPDATE user_avatar_items SET is_equipped = true
    WHERE user_id = v_user_id AND item_id = p_item_id;

    -- Rebuild cache
    PERFORM _rebuild_avatar_cache(v_user_id);

    SELECT coins INTO v_coins_remaining FROM profiles WHERE id = v_user_id;

    RETURN jsonb_build_object(
        'coins_remaining', v_coins_remaining,
        'item_id', p_item_id
    );
END;
$$;

COMMENT ON FUNCTION buy_avatar_item IS 'Purchase avatar item, auto-equip it, rebuild cache.';

-- =============================================
-- HELPER: Save current outfit to avatar_outfits JSONB
-- Called after equip/unequip to keep outfits in sync
-- =============================================
CREATE OR REPLACE FUNCTION _save_current_outfit(p_user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_base_id UUID;
    v_outfits JSONB;
    v_equipped_ids UUID[];
BEGIN
    SELECT avatar_base_id, COALESCE(avatar_outfits, '{}'::jsonb)
    INTO v_base_id, v_outfits
    FROM profiles WHERE id = p_user_id;

    IF v_base_id IS NULL THEN RETURN; END IF;

    SELECT ARRAY_AGG(item_id) INTO v_equipped_ids
    FROM user_avatar_items
    WHERE user_id = p_user_id AND is_equipped = true;

    IF v_equipped_ids IS NOT NULL THEN
        v_outfits = jsonb_set(v_outfits, ARRAY[v_base_id::text], to_jsonb(v_equipped_ids));
    ELSE
        v_outfits = jsonb_set(v_outfits, ARRAY[v_base_id::text], '[]'::jsonb);
    END IF;

    UPDATE profiles SET avatar_outfits = v_outfits WHERE id = p_user_id;
END;
$$;

-- =============================================
-- UPDATED: equip_avatar_item — also save outfit
-- =============================================
CREATE OR REPLACE FUNCTION equip_avatar_item(p_item_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_category_id UUID;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM user_avatar_items WHERE user_id = v_user_id AND item_id = p_item_id) THEN
        RAISE EXCEPTION 'Item not owned';
    END IF;

    SELECT category_id INTO v_category_id FROM avatar_items WHERE id = p_item_id;

    UPDATE user_avatar_items SET is_equipped = false
    WHERE user_id = v_user_id AND is_equipped = true
      AND item_id IN (SELECT id FROM avatar_items WHERE category_id = v_category_id);

    UPDATE user_avatar_items SET is_equipped = true
    WHERE user_id = v_user_id AND item_id = p_item_id;

    PERFORM _rebuild_avatar_cache(v_user_id);
    PERFORM _save_current_outfit(v_user_id);
END;
$$;

-- =============================================
-- UPDATED: unequip_avatar_item — also save outfit
-- =============================================
CREATE OR REPLACE FUNCTION unequip_avatar_item(p_item_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF NOT EXISTS (SELECT 1 FROM user_avatar_items WHERE user_id = v_user_id AND item_id = p_item_id) THEN
        RAISE EXCEPTION 'Item not owned';
    END IF;

    UPDATE user_avatar_items SET is_equipped = false
    WHERE user_id = v_user_id AND item_id = p_item_id;

    PERFORM _rebuild_avatar_cache(v_user_id);
    PERFORM _save_current_outfit(v_user_id);
END;
$$;
