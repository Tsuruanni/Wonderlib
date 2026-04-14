-- Fix: get_class_learning_path_units returns type mismatch error (42804)
-- vocabulary_words.word is VARCHAR(100), ARRAY_AGG produces VARCHAR[],
-- but RETURNS TABLE declares words as TEXT[].
-- Cast the aggregation to TEXT[] to match the function signature.

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
DECLARE
  v_school_id UUID;
  v_grade INTEGER;
  v_caller_school_id UUID;
BEGIN
  -- Get caller's school
  SELECT pr.school_id INTO v_caller_school_id
  FROM profiles pr WHERE pr.id = auth.uid();

  -- Auth: caller must be teacher/admin
  IF NOT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role IN ('teacher', 'admin')
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT cl.school_id, cl.grade INTO v_school_id, v_grade
  FROM classes cl WHERE cl.id = p_class_id;

  IF v_school_id IS NULL THEN
    RAISE EXCEPTION 'Class not found: %', p_class_id;
  END IF;

  -- Verify teacher is in same school (admin can access any)
  IF v_caller_school_id != v_school_id AND NOT EXISTS (
    SELECT 1 FROM profiles pr WHERE pr.id = auth.uid() AND pr.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Not authorized for this class';
  END IF;

  RETURN QUERY
  WITH word_list_words AS (
    SELECT wli.word_list_id, ARRAY_AGG(vw.word::TEXT ORDER BY vw.word) AS words
    FROM word_list_items wli
    JOIN vocabulary_words vw ON vw.id = wli.word_id
    GROUP BY wli.word_list_id
  ),
  book_chapters AS (
    SELECT ch.book_id, COUNT(*)::BIGINT AS chapter_count
    FROM chapters ch
    GROUP BY ch.book_id
  )
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
    wlw.words,
    sui.book_id,
    b.title::VARCHAR AS book_title,
    bc.chapter_count AS book_chapter_count
  FROM scope_learning_paths slp
  JOIN scope_learning_path_units slpu ON slpu.scope_learning_path_id = slp.id
  JOIN vocabulary_units vu ON vu.id = slpu.unit_id
  LEFT JOIN scope_unit_items sui ON sui.scope_lp_unit_id = slpu.id
  LEFT JOIN word_lists wl ON wl.id = sui.word_list_id
  LEFT JOIN books b ON b.id = sui.book_id
  LEFT JOIN word_list_words wlw ON wlw.word_list_id = sui.word_list_id
  LEFT JOIN book_chapters bc ON bc.book_id = sui.book_id
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
