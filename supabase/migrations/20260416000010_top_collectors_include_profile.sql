-- Enrich get_class_top_collectors with profile fields so the card panel can
-- render avatars and open the StudentProfileDialog on tap.

CREATE OR REPLACE FUNCTION get_class_top_collectors(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_class_id UUID;
  v_top3 JSONB;
  v_caller JSONB;
BEGIN
  SELECT class_id INTO v_class_id
  FROM profiles WHERE id = p_user_id;

  IF v_class_id IS NULL THEN
    RETURN jsonb_build_object('top3', '[]'::jsonb, 'caller', NULL);
  END IF;

  WITH ranked AS (
    SELECT
      p.id AS user_id,
      p.first_name,
      p.last_name,
      p.avatar_url,
      p.avatar_equipped_cache,
      p.xp,
      p.level,
      p.league_tier,
      COUNT(DISTINCT uc.card_id) AS unique_cards,
      ROW_NUMBER() OVER (ORDER BY COUNT(DISTINCT uc.card_id) DESC, p.first_name) AS rank
    FROM profiles p
    LEFT JOIN user_cards uc ON uc.user_id = p.id
    WHERE p.class_id = v_class_id
      AND p.role = 'student'
    GROUP BY p.id, p.first_name, p.last_name, p.avatar_url,
             p.avatar_equipped_cache, p.xp, p.level, p.league_tier
  ),
  top3 AS (
    SELECT * FROM ranked WHERE rank <= 3
  ),
  caller AS (
    SELECT * FROM ranked WHERE user_id = p_user_id
  )
  SELECT
    (SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'user_id', user_id,
      'first_name', first_name,
      'last_name', last_name,
      'avatar_url', avatar_url,
      'avatar_equipped_cache', avatar_equipped_cache,
      'total_xp', xp,
      'level', level,
      'league_tier', league_tier,
      'unique_cards', unique_cards,
      'rank', rank
    )), '[]'::jsonb) FROM top3),
    (SELECT jsonb_build_object(
      'user_id', user_id,
      'first_name', first_name,
      'last_name', last_name,
      'avatar_url', avatar_url,
      'avatar_equipped_cache', avatar_equipped_cache,
      'total_xp', xp,
      'level', level,
      'league_tier', league_tier,
      'unique_cards', unique_cards,
      'rank', rank
    ) FROM caller)
  INTO v_top3, v_caller;

  RETURN jsonb_build_object('top3', v_top3, 'caller', v_caller);
END;
$$;
