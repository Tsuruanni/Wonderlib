-- Fix "column reference is ambiguous" in get_class_learning_path_units:
-- RETURNS TABLE column names clash with table column references.
-- Add #variable_conflict use_column to prefer table columns over output params.

CREATE OR REPLACE FUNCTION get_class_learning_path_units(p_class_id UUID)
RETURNS TABLE (
  path_id UUID,
  path_name VARCHAR,
  unit_id UUID,
  scope_lp_unit_id UUID,
  unit_name VARCHAR,
  unit_color VARCHAR,
  unit_icon VARCHAR,
  unit_sort_order INTEGER,
  item_type VARCHAR,
  item_id UUID,
  item_sort_order INTEGER,
  word_list_id UUID,
  word_list_name VARCHAR,
  words TEXT[],
  book_id UUID,
  book_title VARCHAR,
  book_chapter_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
#variable_conflict use_column
DECLARE
  v_school_id UUID;
  v_grade INTEGER;
BEGIN
  -- Auth: caller must be teacher/admin
  IF NOT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role IN ('teacher', 'admin')
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
    slp.id AS path_id,
    slp.name::VARCHAR AS path_name,
    vu.id AS unit_id,
    slpu.id AS scope_lp_unit_id,
    vu.name::VARCHAR AS unit_name,
    vu.color::VARCHAR AS unit_color,
    vu.icon::VARCHAR AS unit_icon,
    slpu.sort_order AS unit_sort_order,
    sui.item_type::VARCHAR,
    sui.id AS item_id,
    sui.sort_order AS item_sort_order,
    sui.word_list_id,
    wl.name::VARCHAR AS word_list_name,
    CASE
      WHEN sui.word_list_id IS NOT NULL THEN
        (SELECT ARRAY_AGG(vw.word::TEXT ORDER BY vw.word)
         FROM word_list_items wli
         JOIN vocabulary_words vw ON vw.id = wli.word_id
         WHERE wli.word_list_id = sui.word_list_id)
      ELSE NULL::TEXT[]
    END AS words,
    sui.book_id,
    b.title::VARCHAR AS book_title,
    CASE
      WHEN sui.book_id IS NOT NULL THEN
        (SELECT COUNT(*)::BIGINT FROM chapters ch WHERE ch.book_id = sui.book_id)
      ELSE NULL::BIGINT
    END AS book_chapter_count
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
