-- =============================================
-- HUMAN AVATAR REDESIGN
-- Transforms animal avatar system to human (male/female) with
-- 9 customizable part categories, gender filtering, required
-- category enforcement, and 500-coin gender change fee.
-- =============================================

-- =============================================
-- 1. SCHEMA CHANGES
-- =============================================
ALTER TABLE avatar_items
    ADD COLUMN IF NOT EXISTS gender VARCHAR(10) DEFAULT 'unisex'
    CHECK (gender IN ('male', 'female', 'unisex'));

ALTER TABLE avatar_item_categories
    ADD COLUMN IF NOT EXISTS is_required BOOLEAN NOT NULL DEFAULT true;

-- =============================================
-- 2. CLEAN EXISTING DATA
-- All 50 seeded items are is_active = false, no real purchases exist.
-- =============================================
-- Clear profile references FIRST (FK constraint on avatar_base_id)
UPDATE profiles SET
    avatar_base_id = NULL,
    avatar_equipped_cache = NULL,
    avatar_outfits = '{}'::jsonb;

DELETE FROM user_avatar_items;
DELETE FROM avatar_items;
DELETE FROM avatar_item_categories;
DELETE FROM avatar_bases;

-- =============================================
-- 3. INSERT NEW BASES (male / female)
-- image_url left empty — admin uploads body PNGs later
-- =============================================
INSERT INTO avatar_bases (id, name, display_name, image_url, sort_order) VALUES
    (gen_random_uuid(), 'male',   'Boy',  '', 1),
    (gen_random_uuid(), 'female', 'Girl', '', 2);

-- =============================================
-- 4. INSERT NEW CATEGORIES (9 slots)
-- is_required = true for all except additional_accessories
-- =============================================
INSERT INTO avatar_item_categories (id, name, display_name, z_index, sort_order, is_required) VALUES
    (gen_random_uuid(), 'face',                   'Face',        5,  1, true),
    (gen_random_uuid(), 'ears',                   'Ears',       10,  2, true),
    (gen_random_uuid(), 'eyes',                   'Eyes',       15,  3, true),
    (gen_random_uuid(), 'brows',                  'Brows',      20,  4, true),
    (gen_random_uuid(), 'noses',                  'Noses',      25,  5, true),
    (gen_random_uuid(), 'mouth',                  'Mouth',      30,  6, true),
    (gen_random_uuid(), 'hair',                   'Hair',       35,  7, true),
    (gen_random_uuid(), 'clothes',                'Clothes',    40,  8, true),
    (gen_random_uuid(), 'additional_accessories', 'Accessories', 45, 9, false);

-- =============================================
-- 5. UPDATED RPC: set_avatar_base
-- Adds: same-base guard, 500 coin charge for gender change,
-- random equip of free items for empty required categories.
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
    v_new_base_name TEXT;
    v_cat RECORD;
    v_random_item UUID;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM avatar_bases WHERE id = p_base_id) THEN
        RAISE EXCEPTION 'Avatar base not found';
    END IF;

    -- Get current state
    SELECT avatar_base_id, COALESCE(avatar_outfits, '{}'::jsonb)
    INTO v_old_base_id, v_outfits
    FROM profiles WHERE id = v_user_id;

    -- No-op if selecting same base
    IF v_old_base_id = p_base_id THEN
        RETURN;
    END IF;

    -- Charge 500 coins for gender change (skip if first-time onboarding)
    IF v_old_base_id IS NOT NULL THEN
        PERFORM spend_coins_transaction(
            v_user_id, 500, 'avatar_gender_change', p_base_id::text,
            'Avatar gender change'
        );
    END IF;

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

    -- Get new base name for gender filtering
    SELECT name INTO v_new_base_name FROM avatar_bases WHERE id = p_base_id;

    -- Restore outfit for new base (if saved before)
    IF v_outfits ? p_base_id::text THEN
        SELECT ARRAY(
            SELECT (jsonb_array_elements_text(v_outfits -> p_base_id::text))::UUID
        ) INTO v_restore_ids;

        IF v_restore_ids IS NOT NULL THEN
            FOREACH v_item_id IN ARRAY v_restore_ids LOOP
                IF EXISTS (SELECT 1 FROM user_avatar_items WHERE user_id = v_user_id AND item_id = v_item_id) THEN
                    SELECT ai.category_id INTO v_category_id
                    FROM avatar_items ai WHERE ai.id = v_item_id;

                    UPDATE user_avatar_items SET is_equipped = false
                    WHERE user_id = v_user_id AND is_equipped = true
                      AND item_id IN (SELECT id FROM avatar_items WHERE category_id = v_category_id);

                    UPDATE user_avatar_items SET is_equipped = true
                    WHERE user_id = v_user_id AND item_id = v_item_id;
                END IF;
            END LOOP;
        END IF;
    END IF;

    -- Fill empty required categories with random free gender-compatible items
    FOR v_cat IN SELECT * FROM avatar_item_categories WHERE is_required = true LOOP
        IF NOT EXISTS (
            SELECT 1 FROM user_avatar_items uai
            JOIN avatar_items ai ON ai.id = uai.item_id
            WHERE uai.user_id = v_user_id AND uai.is_equipped = true
              AND ai.category_id = v_cat.id
        ) THEN
            SELECT id INTO v_random_item FROM avatar_items
            WHERE category_id = v_cat.id AND is_active = true AND coin_price = 0
              AND (gender = 'unisex' OR gender = v_new_base_name)
            ORDER BY random() LIMIT 1;

            IF v_random_item IS NOT NULL THEN
                INSERT INTO user_avatar_items (user_id, item_id, is_equipped, purchased_at)
                VALUES (v_user_id, v_random_item, true, now())
                ON CONFLICT (user_id, item_id) DO UPDATE SET is_equipped = true;
            END IF;
        END IF;
    END LOOP;

    -- Rebuild cache
    PERFORM _rebuild_avatar_cache(v_user_id);
END;
$$;

COMMENT ON FUNCTION set_avatar_base IS 'Set base (male/female), charge 500 coins for gender change, save/restore outfits, random-fill empty required categories.';

-- =============================================
-- 6. UPDATED RPC: buy_avatar_item
-- Adds: gender guard (item must match base gender or be unisex)
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
    v_base_name TEXT;
BEGIN
    SELECT id, display_name, coin_price, is_active, category_id, gender INTO v_item
    FROM avatar_items WHERE id = p_item_id;

    IF v_item.id IS NULL THEN
        RAISE EXCEPTION 'Avatar item not found';
    END IF;

    IF NOT v_item.is_active THEN
        RAISE EXCEPTION 'Avatar item is not available';
    END IF;

    -- Gender guard
    IF v_item.gender != 'unisex' THEN
        SELECT ab.name INTO v_base_name
        FROM profiles p JOIN avatar_bases ab ON ab.id = p.avatar_base_id
        WHERE p.id = v_user_id;

        IF v_base_name IS NULL OR v_item.gender != v_base_name THEN
            RAISE EXCEPTION 'Item not available for your avatar gender';
        END IF;
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

    INSERT INTO user_avatar_items (user_id, item_id, is_equipped)
    VALUES (v_user_id, p_item_id, false);

    -- Auto-equip: unequip same category, equip new item
    UPDATE user_avatar_items SET is_equipped = false
    WHERE user_id = v_user_id AND is_equipped = true
      AND item_id IN (SELECT id FROM avatar_items WHERE category_id = v_item.category_id);

    UPDATE user_avatar_items SET is_equipped = true
    WHERE user_id = v_user_id AND item_id = p_item_id;

    PERFORM _rebuild_avatar_cache(v_user_id);

    SELECT coins INTO v_coins_remaining FROM profiles WHERE id = v_user_id;

    RETURN jsonb_build_object(
        'coins_remaining', v_coins_remaining,
        'item_id', p_item_id
    );
END;
$$;

COMMENT ON FUNCTION buy_avatar_item IS 'Purchase avatar item with gender guard, auto-equip, rebuild cache.';

-- =============================================
-- 7. UPDATED RPC: equip_avatar_item
-- Adds: gender guard
-- =============================================
CREATE OR REPLACE FUNCTION equip_avatar_item(p_item_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_category_id UUID;
    v_item_gender TEXT;
    v_base_name TEXT;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM user_avatar_items WHERE user_id = v_user_id AND item_id = p_item_id) THEN
        RAISE EXCEPTION 'Item not owned';
    END IF;

    -- Gender guard
    SELECT category_id, gender INTO v_category_id, v_item_gender
    FROM avatar_items WHERE id = p_item_id;

    IF v_item_gender != 'unisex' THEN
        SELECT ab.name INTO v_base_name
        FROM profiles p JOIN avatar_bases ab ON ab.id = p.avatar_base_id
        WHERE p.id = v_user_id;

        IF v_base_name IS NULL OR v_item_gender != v_base_name THEN
            RAISE EXCEPTION 'Item not available for your avatar gender';
        END IF;
    END IF;

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
-- 8. UPDATED RPC: unequip_avatar_item
-- Adds: required-category guard
-- =============================================
CREATE OR REPLACE FUNCTION unequip_avatar_item(p_item_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_required BOOLEAN;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM user_avatar_items WHERE user_id = v_user_id AND item_id = p_item_id) THEN
        RAISE EXCEPTION 'Item not owned';
    END IF;

    -- Required-category guard
    SELECT c.is_required INTO v_is_required
    FROM avatar_item_categories c
    JOIN avatar_items i ON i.category_id = c.id
    WHERE i.id = p_item_id;

    IF v_is_required THEN
        RAISE EXCEPTION 'Cannot unequip required category item';
    END IF;

    UPDATE user_avatar_items SET is_equipped = false
    WHERE user_id = v_user_id AND item_id = p_item_id;

    PERFORM _rebuild_avatar_cache(v_user_id);
    PERFORM _save_current_outfit(v_user_id);
END;
$$;
