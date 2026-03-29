-- Add tile_theme_id to get_user_learning_paths RPC output
DROP FUNCTION IF EXISTS get_user_learning_paths(UUID);

CREATE OR REPLACE FUNCTION get_user_learning_paths(p_user_id UUID)
RETURNS TABLE (
  learning_path_id        UUID,
  learning_path_name      VARCHAR,
  lp_sort_order           INTEGER,
  sequential_lock         BOOLEAN,
  books_exempt_from_lock  BOOLEAN,
  unit_id                 UUID,
  unit_name               VARCHAR,
  unit_color              VARCHAR,
  unit_icon               VARCHAR,
  unit_sort_order         INTEGER,
  tile_theme_id           UUID,
  item_type               VARCHAR,
  item_id                 UUID,
  item_sort_order         INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_school_id UUID;
  v_grade INTEGER;
  v_class_id UUID;
BEGIN
  -- Auth check: user can only fetch own paths
  IF auth.uid() != p_user_id THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT p.school_id, c.grade, p.class_id
  INTO v_school_id, v_grade, v_class_id
  FROM profiles p
  LEFT JOIN classes c ON c.id = p.class_id
  WHERE p.id = p_user_id;

  IF v_school_id IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    slp.id AS learning_path_id,
    slp.name::VARCHAR AS learning_path_name,
    slp.sort_order AS lp_sort_order,
    slp.sequential_lock,
    slp.books_exempt_from_lock,
    vu.id AS unit_id,
    vu.name::VARCHAR AS unit_name,
    vu.color::VARCHAR AS unit_color,
    vu.icon::VARCHAR AS unit_icon,
    slpu.sort_order AS unit_sort_order,
    vu.tile_theme_id,
    sui.item_type::VARCHAR AS item_type,
    COALESCE(sui.word_list_id, sui.book_id) AS item_id,
    sui.sort_order AS item_sort_order
  FROM scope_learning_paths slp
  JOIN scope_learning_path_units slpu ON slpu.scope_learning_path_id = slp.id
  JOIN vocabulary_units vu ON vu.id = slpu.unit_id
  LEFT JOIN scope_unit_items sui ON sui.scope_lp_unit_id = slpu.id
  WHERE slp.school_id = v_school_id
    AND (
      (slp.grade IS NULL AND slp.class_id IS NULL)
      OR (slp.grade = v_grade AND slp.class_id IS NULL)
      OR (slp.class_id = v_class_id)
    )
    AND vu.is_active = true
  ORDER BY slp.sort_order, slpu.sort_order, sui.sort_order;
END;
$$;
