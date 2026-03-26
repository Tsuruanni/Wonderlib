-- Fix ambiguous column references: DROP and recreate with out_ prefixed columns
-- to avoid clash between RETURNS TABLE params and table column names.

DROP FUNCTION IF EXISTS get_class_learning_path_units(UUID);

CREATE FUNCTION get_class_learning_path_units(p_class_id UUID)
RETURNS TABLE (
  out_path_id UUID,
  out_path_name VARCHAR,
  out_unit_id UUID,
  out_scope_lp_unit_id UUID,
  out_unit_name VARCHAR,
  out_unit_color VARCHAR,
  out_unit_icon VARCHAR,
  out_unit_sort_order INTEGER,
  out_item_type VARCHAR,
  out_item_id UUID,
  out_item_sort_order INTEGER,
  out_word_list_id UUID,
  out_word_list_name VARCHAR,
  out_words TEXT[],
  out_book_id UUID,
  out_book_title VARCHAR,
  out_book_chapter_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_school_id UUID;
  v_grade INTEGER;
BEGIN
  -- Auth: caller must be teacher/admin
  IF NOT EXISTS (
    SELECT 1 FROM profiles pr
    WHERE pr.id = auth.uid() AND pr.role IN ('teacher', 'admin')
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  -- Get school_id and grade from the class
  SELECT cl.school_id, cl.grade INTO v_school_id, v_grade
  FROM classes cl WHERE cl.id = p_class_id;

  IF v_school_id IS NULL THEN
    RAISE EXCEPTION 'Class not found: %', p_class_id;
  END IF;

  RETURN QUERY
  SELECT
    slp.id,
    slp.name::VARCHAR,
    vu.id,
    slpu.id,
    vu.name::VARCHAR,
    vu.color::VARCHAR,
    vu.icon::VARCHAR,
    slpu.sort_order,
    sui.item_type::VARCHAR,
    sui.id,
    sui.sort_order,
    sui.word_list_id,
    wl.name::VARCHAR,
    CASE
      WHEN sui.word_list_id IS NOT NULL THEN
        (SELECT ARRAY_AGG(vw.word::TEXT ORDER BY vw.word)
         FROM word_list_items wli
         JOIN vocabulary_words vw ON vw.id = wli.word_id
         WHERE wli.word_list_id = sui.word_list_id)
      ELSE NULL::TEXT[]
    END,
    sui.book_id,
    b.title::VARCHAR,
    CASE
      WHEN sui.book_id IS NOT NULL THEN
        (SELECT COUNT(*)::BIGINT FROM chapters ch WHERE ch.book_id = sui.book_id)
      ELSE NULL::BIGINT
    END
  FROM scope_learning_paths slp
  JOIN scope_learning_path_units slpu ON slpu.scope_learning_path_id = slp.id
  JOIN vocabulary_units vu ON vu.id = slpu.unit_id
  LEFT JOIN scope_unit_items sui ON sui.scope_lp_unit_id = slpu.id
  LEFT JOIN word_lists wl ON wl.id = sui.word_list_id
  LEFT JOIN books b ON b.id = sui.book_id
  WHERE slp.school_id = v_school_id
    AND (
      (slp.grade IS NULL AND slp.class_id IS NULL)
      OR (slp.grade = v_grade AND slp.class_id IS NULL)
      OR (slp.class_id = p_class_id)
    )
    AND vu.is_active = true
  ORDER BY slp.sort_order, slpu.sort_order, sui.sort_order;
END;
$$;
