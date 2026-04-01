-- Card panel sidebar RPCs

-- 1. Top collectors in the caller's class (top 3 + caller rank)
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
      COUNT(DISTINCT uc.card_id) AS unique_cards,
      ROW_NUMBER() OVER (ORDER BY COUNT(DISTINCT uc.card_id) DESC, p.first_name) AS rank
    FROM profiles p
    LEFT JOIN user_cards uc ON uc.user_id = p.id
    WHERE p.class_id = v_class_id
      AND p.role = 'student'
    GROUP BY p.id, p.first_name
  ),
  top3 AS (
    SELECT * FROM ranked WHERE rank <= 3
  ),
  caller AS (
    SELECT * FROM ranked WHERE user_id = p_user_id
  )
  SELECT
    (SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'user_id', user_id, 'first_name', first_name,
      'unique_cards', unique_cards, 'rank', rank
    )), '[]'::jsonb) FROM top3),
    (SELECT jsonb_build_object(
      'user_id', user_id, 'first_name', first_name,
      'unique_cards', unique_cards, 'rank', rank
    ) FROM caller)
  INTO v_top3, v_caller;

  RETURN jsonb_build_object('top3', v_top3, 'caller', v_caller);
END;
$$;

-- 2. Cards only the caller owns in their class (up to 2, rarest first)
CREATE OR REPLACE FUNCTION get_exclusive_cards(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_class_id UUID;
  v_result JSONB;
BEGIN
  SELECT class_id INTO v_class_id
  FROM profiles WHERE id = p_user_id;

  IF v_class_id IS NULL THEN
    RETURN '[]'::jsonb;
  END IF;

  WITH class_card_owners AS (
    SELECT uc.card_id, COUNT(DISTINCT uc.user_id) AS owner_count
    FROM user_cards uc
    JOIN profiles p ON p.id = uc.user_id
    WHERE p.class_id = v_class_id
      AND p.role = 'student'
    GROUP BY uc.card_id
  ),
  exclusive AS (
    SELECT mc.id, mc.name, mc.category, mc.rarity, mc.power, mc.image_url, mc.card_no
    FROM class_card_owners cco
    JOIN myth_cards mc ON mc.id = cco.card_id
    JOIN user_cards uc ON uc.card_id = cco.card_id AND uc.user_id = p_user_id
    WHERE cco.owner_count = 1
    ORDER BY
      CASE mc.rarity
        WHEN 'legendary' THEN 1
        WHEN 'epic' THEN 2
        WHEN 'rare' THEN 3
        WHEN 'common' THEN 4
      END,
      mc.power DESC
    LIMIT 2
  )
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', id,
    'name', name,
    'category', category,
    'rarity', rarity,
    'power', power,
    'image_url', image_url,
    'card_no', card_no
  )), '[]'::jsonb) INTO v_result
  FROM exclusive;

  RETURN v_result;
END;
$$;
