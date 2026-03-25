-- =============================================
-- INTERNAL HELPER: Rebuild avatar equipped cache
-- =============================================
CREATE OR REPLACE FUNCTION _rebuild_avatar_cache(p_user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_base_url TEXT;
    v_layers JSONB;
BEGIN
    -- Get base animal URL
    SELECT ab.image_url INTO v_base_url
    FROM profiles p
    JOIN avatar_bases ab ON ab.id = p.avatar_base_id
    WHERE p.id = p_user_id;

    -- Get equipped item layers sorted by z_index
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object('z', aic.z_index, 'url', ai.image_url)
        ORDER BY aic.z_index
    ), '[]'::jsonb) INTO v_layers
    FROM user_avatar_items uai
    JOIN avatar_items ai ON ai.id = uai.item_id
    JOIN avatar_item_categories aic ON aic.id = ai.category_id
    WHERE uai.user_id = p_user_id AND uai.is_equipped = true;

    -- Update cache
    UPDATE profiles
    SET avatar_equipped_cache = jsonb_build_object(
        'base_url', v_base_url,
        'layers', v_layers
    )
    WHERE id = p_user_id;
END;
$$;

-- =============================================
-- SET AVATAR BASE
-- =============================================
CREATE OR REPLACE FUNCTION set_avatar_base(p_base_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    -- Validate base exists
    IF NOT EXISTS (SELECT 1 FROM avatar_bases WHERE id = p_base_id) THEN
        RAISE EXCEPTION 'Avatar base not found';
    END IF;

    -- Update profile
    UPDATE profiles SET avatar_base_id = p_base_id WHERE id = v_user_id;

    -- Rebuild cache
    PERFORM _rebuild_avatar_cache(v_user_id);
END;
$$;

-- =============================================
-- BUY AVATAR ITEM
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
BEGIN
    -- Get item details
    SELECT id, display_name, coin_price, is_active INTO v_item
    FROM avatar_items WHERE id = p_item_id;

    IF v_item.id IS NULL THEN
        RAISE EXCEPTION 'Avatar item not found';
    END IF;

    IF NOT v_item.is_active THEN
        RAISE EXCEPTION 'Avatar item is not available';
    END IF;

    -- Check if already owned
    IF EXISTS (SELECT 1 FROM user_avatar_items WHERE user_id = v_user_id AND item_id = p_item_id) THEN
        RAISE EXCEPTION 'Already owned';
    END IF;

    -- Check coins
    SELECT coins INTO v_current_coins FROM profiles WHERE id = v_user_id;
    IF v_current_coins < v_item.coin_price THEN
        RAISE EXCEPTION 'Insufficient coins';
    END IF;

    -- Deduct coins via existing transaction function
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

    -- Get remaining coins
    SELECT coins INTO v_coins_remaining FROM profiles WHERE id = v_user_id;

    RETURN jsonb_build_object(
        'coins_remaining', v_coins_remaining,
        'item_id', p_item_id
    );
END;
$$;

-- =============================================
-- EQUIP AVATAR ITEM
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
    -- Validate ownership
    IF NOT EXISTS (SELECT 1 FROM user_avatar_items WHERE user_id = v_user_id AND item_id = p_item_id) THEN
        RAISE EXCEPTION 'Item not owned';
    END IF;

    -- Get category of this item
    SELECT category_id INTO v_category_id FROM avatar_items WHERE id = p_item_id;

    -- Unequip any currently equipped item in same category
    UPDATE user_avatar_items SET is_equipped = false
    WHERE user_id = v_user_id
      AND is_equipped = true
      AND item_id IN (SELECT id FROM avatar_items WHERE category_id = v_category_id);

    -- Equip the new item
    UPDATE user_avatar_items SET is_equipped = true
    WHERE user_id = v_user_id AND item_id = p_item_id;

    -- Rebuild cache
    PERFORM _rebuild_avatar_cache(v_user_id);
END;
$$;

-- =============================================
-- UNEQUIP AVATAR ITEM
-- =============================================
CREATE OR REPLACE FUNCTION unequip_avatar_item(p_item_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    -- Validate ownership
    IF NOT EXISTS (SELECT 1 FROM user_avatar_items WHERE user_id = v_user_id AND item_id = p_item_id) THEN
        RAISE EXCEPTION 'Item not owned';
    END IF;

    -- Unequip
    UPDATE user_avatar_items SET is_equipped = false
    WHERE user_id = v_user_id AND item_id = p_item_id;

    -- Rebuild cache
    PERFORM _rebuild_avatar_cache(v_user_id);
END;
$$;
