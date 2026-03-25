-- =============================================
-- 1. FIX: Unequip all items when changing base animal
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

    -- Unequip all currently equipped items (new animal = fresh start)
    UPDATE user_avatar_items
    SET is_equipped = false
    WHERE user_id = v_user_id AND is_equipped = true;

    -- Update profile
    UPDATE profiles SET avatar_base_id = p_base_id WHERE id = v_user_id;

    -- Rebuild cache (will have base only, no layers)
    PERFORM _rebuild_avatar_cache(v_user_id);
END;
$$;

COMMENT ON FUNCTION set_avatar_base IS 'Set avatar base animal. Unequips all items since accessories may not fit new animal.';

-- =============================================
-- 2. Rename "hand" category to "neck" (better for bust avatars)
-- =============================================
UPDATE avatar_item_categories
SET name = 'neck',
    display_name = 'Neck',
    z_index = 15,
    sort_order = 3
WHERE name = 'hand';

-- Also fix sort_order for face and head (shifted by neck insertion)
UPDATE avatar_item_categories SET sort_order = 4 WHERE name = 'face';
UPDATE avatar_item_categories SET sort_order = 5 WHERE name = 'head';
