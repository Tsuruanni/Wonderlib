-- N+1 fix: replace correlated subqueries with CTEs that pre-aggregate once.
--
-- get_class_learning_path_units had 2 correlated subqueries per row:
--   - ARRAY_AGG(words) per word_list_id
--   - COUNT(*) chapters per book_id
-- For a path with 30 items that was 60+ extra round-trips.
--
-- get_unit_assignment_items had 5 correlated subqueries per row:
--   - word_count, is_word_list_completed, total_chapters, completed_chapters, is_book_completed
-- All replaced with CTEs joined once.
--
-- Return type signatures are UNCHANGED — Flutter depends on exact column names and types.

-- ─── 1. get_class_learning_path_units ────────────────────────────────────────

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
    SELECT wli.word_list_id, ARRAY_AGG(vw.word ORDER BY vw.word) AS words
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

-- ─── 2. get_unit_assignment_items ────────────────────────────────────────────
-- Preserves is_completed from reading_progress for is_book_completed
-- (introduced in 20260329300001_fix_unit_assignment_quiz_gate.sql).

CREATE OR REPLACE FUNCTION get_unit_assignment_items(
  p_scope_lp_unit_id UUID,
  p_student_id UUID
)
RETURNS TABLE (
  item_type VARCHAR,
  sort_order INTEGER,
  word_list_id UUID,
  word_list_name VARCHAR,
  word_count BIGINT,
  is_word_list_completed BOOLEAN,
  book_id UUID,
  book_title VARCHAR,
  total_chapters BIGINT,
  completed_chapters BIGINT,
  is_book_completed BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF auth.uid() != p_student_id THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN QUERY
  WITH word_counts AS (
    SELECT wli.word_list_id, COUNT(*)::BIGINT AS cnt
    FROM word_list_items wli
    GROUP BY wli.word_list_id
  ),
  wl_completions AS (
    SELECT uwlp.word_list_id
    FROM user_word_list_progress uwlp
    WHERE uwlp.user_id = p_student_id AND uwlp.completed_at IS NOT NULL
  ),
  chapter_counts AS (
    SELECT ch.book_id, COUNT(*)::BIGINT AS total
    FROM chapters ch
    GROUP BY ch.book_id
  ),
  reading AS (
    SELECT rp.book_id,
           COALESCE(array_length(rp.completed_chapter_ids, 1), 0)::BIGINT AS completed,
           rp.is_completed
    FROM reading_progress rp
    WHERE rp.user_id = p_student_id
  )
  SELECT
    sui.item_type::VARCHAR,
    sui.sort_order,
    sui.word_list_id,
    wl.name::VARCHAR AS word_list_name,
    wc.cnt AS word_count,
    (wlc.word_list_id IS NOT NULL) AS is_word_list_completed,
    sui.book_id,
    b.title::VARCHAR AS book_title,
    cc.total AS total_chapters,
    r.completed AS completed_chapters,
    -- Use reading_progress.is_completed so quiz-gated books are only
    -- counted as complete when the quiz has been passed (not just all
    -- chapters read). Matches the fix from 20260329300001.
    CASE
      WHEN sui.book_id IS NOT NULL THEN COALESCE(r.is_completed, false)
      ELSE NULL::BOOLEAN
    END AS is_book_completed
  FROM scope_unit_items sui
  LEFT JOIN word_lists wl ON wl.id = sui.word_list_id
  LEFT JOIN books b ON b.id = sui.book_id
  LEFT JOIN word_counts wc ON wc.word_list_id = sui.word_list_id
  LEFT JOIN wl_completions wlc ON wlc.word_list_id = sui.word_list_id
  LEFT JOIN chapter_counts cc ON cc.book_id = sui.book_id
  LEFT JOIN reading r ON r.book_id = sui.book_id
  WHERE sui.scope_lp_unit_id = p_scope_lp_unit_id
  ORDER BY sui.sort_order;
END;
$$;
