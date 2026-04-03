-- =============================================
-- HAIR COLOR SUPPORT
-- Stores selected hair color hex on profile.
-- Included in avatar_equipped_cache for rendering.
-- =============================================

ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS hair_color TEXT DEFAULT NULL;

-- Update cache rebuild to include hair_color
CREATE OR REPLACE FUNCTION _rebuild_avatar_cache(p_user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_base_url TEXT;
    v_layers JSONB;
    v_hair_color TEXT;
BEGIN
    -- Get base URL
    SELECT ab.image_url INTO v_base_url
    FROM profiles p
    JOIN avatar_bases ab ON ab.id = p.avatar_base_id
    WHERE p.id = p_user_id;

    -- Get equipped item layers sorted by z_index
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object('z', aic.z_index, 'url', ai.image_url, 'cat', aic.name)
        ORDER BY aic.z_index
    ), '[]'::jsonb) INTO v_layers
    FROM user_avatar_items uai
    JOIN avatar_items ai ON ai.id = uai.item_id
    JOIN avatar_item_categories aic ON aic.id = ai.category_id
    WHERE uai.user_id = p_user_id AND uai.is_equipped = true;

    -- Get hair color
    SELECT hair_color INTO v_hair_color FROM profiles WHERE id = p_user_id;

    -- Update cache
    UPDATE profiles
    SET avatar_equipped_cache = jsonb_build_object(
        'base_url', v_base_url,
        'layers', v_layers,
        'hair_color', v_hair_color
    )
    WHERE id = p_user_id;
END;
$$;

-- RPC to set hair color
CREATE OR REPLACE FUNCTION set_hair_color(p_color TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    UPDATE profiles SET hair_color = p_color WHERE id = v_user_id;
    PERFORM _rebuild_avatar_cache(v_user_id);
END;
$$;
