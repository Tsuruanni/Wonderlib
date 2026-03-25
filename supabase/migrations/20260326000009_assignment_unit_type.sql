-- =============================================================================
-- 1. Replace 'mixed' with 'unit' in assignments.type CHECK constraint
-- =============================================================================
ALTER TABLE assignments DROP CONSTRAINT assignments_type_check;
ALTER TABLE assignments ADD CONSTRAINT assignments_type_check
  CHECK (type IN ('book', 'vocabulary', 'unit'));

-- =============================================================================
-- 2. RPC: get_assignment_detail_with_stats (replaces 2-query approach)
-- =============================================================================
CREATE OR REPLACE FUNCTION get_assignment_detail_with_stats(p_assignment_id UUID)
RETURNS TABLE (
  id UUID,
  teacher_id UUID,
  class_id UUID,
  class_name VARCHAR,
  type VARCHAR,
  title VARCHAR,
  description TEXT,
  content_config JSONB,
  start_date TIMESTAMPTZ,
  due_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ,
  total_students BIGINT,
  completed_students BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_teacher_id UUID;
BEGIN
  -- Get the teacher_id for auth check
  SELECT a.teacher_id INTO v_teacher_id
  FROM assignments a WHERE a.id = p_assignment_id;

  IF v_teacher_id IS NULL THEN
    RAISE EXCEPTION 'Assignment not found: %', p_assignment_id;
  END IF;

  -- Auth: caller must be the teacher or admin
  IF auth.uid() != v_teacher_id AND NOT EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN QUERY
  SELECT
    a.id,
    a.teacher_id,
    a.class_id,
    c.name::VARCHAR AS class_name,
    a.type::VARCHAR,
    a.title::VARCHAR,
    a.description,
    a.content_config,
    a.start_date,
    a.due_date,
    a.created_at,
    COUNT(asn.id) AS total_students,
    COUNT(asn.id) FILTER (WHERE asn.status = 'completed') AS completed_students
  FROM assignments a
  LEFT JOIN classes c ON c.id = a.class_id
  LEFT JOIN assignment_students asn ON asn.assignment_id = a.id
  WHERE a.id = p_assignment_id
  GROUP BY a.id, a.teacher_id, a.class_id, c.name, a.type, a.title,
           a.description, a.content_config, a.start_date, a.due_date, a.created_at;
END;
$$;

-- =============================================================================
-- 3. RPC: get_class_learning_path_units (teacher picks a unit to assign)
-- =============================================================================
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
        (SELECT ARRAY_AGG(vw.word ORDER BY vw.word)
         FROM word_list_items wli
         JOIN vocabulary_words vw ON vw.id = wli.word_id
         WHERE wli.word_list_id = sui.word_list_id)
      ELSE NULL
    END AS words,
    sui.book_id,
    b.title::VARCHAR AS book_title,
    CASE
      WHEN sui.book_id IS NOT NULL THEN
        (SELECT COUNT(*) FROM chapters ch WHERE ch.book_id = sui.book_id)
      ELSE NULL
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

-- =============================================================================
-- 4. RPC: get_unit_assignment_items (student sees item list with completion)
-- =============================================================================
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
  -- Auth: caller must be the student
  IF auth.uid() != p_student_id THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN QUERY
  SELECT
    sui.item_type::VARCHAR,
    sui.sort_order,
    sui.word_list_id,
    wl.name::VARCHAR AS word_list_name,
    CASE
      WHEN sui.word_list_id IS NOT NULL THEN
        (SELECT COUNT(*) FROM word_list_items wli WHERE wli.word_list_id = sui.word_list_id)
      ELSE NULL
    END AS word_count,
    CASE
      WHEN sui.word_list_id IS NOT NULL THEN
        EXISTS (
          SELECT 1 FROM user_word_list_progress uwlp
          WHERE uwlp.user_id = p_student_id
            AND uwlp.word_list_id = sui.word_list_id
            AND uwlp.completed_at IS NOT NULL
        )
      ELSE NULL
    END AS is_word_list_completed,
    sui.book_id,
    b.title::VARCHAR AS book_title,
    CASE
      WHEN sui.book_id IS NOT NULL THEN
        (SELECT COUNT(*) FROM chapters ch WHERE ch.book_id = sui.book_id)
      ELSE NULL
    END AS total_chapters,
    CASE
      WHEN sui.book_id IS NOT NULL THEN
        (SELECT COALESCE(array_length(rp.completed_chapter_ids, 1), 0)
         FROM reading_progress rp
         WHERE rp.user_id = p_student_id AND rp.book_id = sui.book_id)
      ELSE NULL
    END AS completed_chapters,
    CASE
      WHEN sui.book_id IS NOT NULL THEN
        (SELECT COALESCE(array_length(rp.completed_chapter_ids, 1), 0) >=
                (SELECT COUNT(*) FROM chapters ch WHERE ch.book_id = sui.book_id)
         FROM reading_progress rp
         WHERE rp.user_id = p_student_id AND rp.book_id = sui.book_id)
      ELSE NULL
    END AS is_book_completed
  FROM scope_unit_items sui
  LEFT JOIN word_lists wl ON wl.id = sui.word_list_id
  LEFT JOIN books b ON b.id = sui.book_id
  WHERE sui.scope_lp_unit_id = p_scope_lp_unit_id
  ORDER BY sui.sort_order;
END;
$$;

-- =============================================================================
-- 5. RPC: calculate_unit_assignment_progress (server-side progress calc)
-- =============================================================================
CREATE OR REPLACE FUNCTION calculate_unit_assignment_progress(
  p_assignment_id UUID,
  p_student_id UUID
)
RETURNS TABLE (progress NUMERIC, completed_count BIGINT, total_count BIGINT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_scope_lp_unit_id UUID;
  v_total BIGINT;
  v_completed BIGINT;
  v_progress NUMERIC;
BEGIN
  -- Auth: caller must be the student
  IF auth.uid() != p_student_id THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  -- Get scopeLpUnitId from assignment's content_config
  SELECT (a.content_config->>'scopeLpUnitId')::UUID INTO v_scope_lp_unit_id
  FROM assignments a WHERE a.id = p_assignment_id;

  IF v_scope_lp_unit_id IS NULL THEN
    RAISE EXCEPTION 'Not a unit assignment or assignment not found';
  END IF;

  -- Count total trackable items (word_list + book only)
  SELECT COUNT(*) INTO v_total
  FROM scope_unit_items sui
  WHERE sui.scope_lp_unit_id = v_scope_lp_unit_id
    AND sui.item_type IN ('word_list', 'book');

  IF v_total = 0 THEN
    v_progress := 100;
    v_completed := 0;

    RETURN QUERY SELECT v_progress, v_completed, v_total;
    RETURN;
  END IF;

  -- Count completed items
  SELECT COUNT(*) INTO v_completed
  FROM scope_unit_items sui
  WHERE sui.scope_lp_unit_id = v_scope_lp_unit_id
    AND sui.item_type IN ('word_list', 'book')
    AND (
      -- Word list: completed_at is set
      (sui.item_type = 'word_list' AND EXISTS (
        SELECT 1 FROM user_word_list_progress uwlp
        WHERE uwlp.user_id = p_student_id
          AND uwlp.word_list_id = sui.word_list_id
          AND uwlp.completed_at IS NOT NULL
      ))
      OR
      -- Book: all chapters read
      (sui.item_type = 'book' AND (
        SELECT COALESCE(array_length(rp.completed_chapter_ids, 1), 0)
        FROM reading_progress rp
        WHERE rp.user_id = p_student_id AND rp.book_id = sui.book_id
      ) >= (
        SELECT COUNT(*) FROM chapters ch WHERE ch.book_id = sui.book_id
      ))
    );

  v_progress := ROUND((v_completed::NUMERIC / v_total) * 100, 1);

  -- Update assignment_students row
  IF v_progress >= 100 THEN
    UPDATE assignment_students
    SET status = 'completed', progress = 100, score = NULL,
        completed_at = NOW()
    WHERE assignment_id = p_assignment_id AND student_id = p_student_id
      AND status != 'completed';
  ELSE
    UPDATE assignment_students
    SET progress = v_progress,
        status = CASE WHEN status = 'pending' THEN 'in_progress' ELSE status END,
        started_at = CASE WHEN started_at IS NULL THEN NOW() ELSE started_at END
    WHERE assignment_id = p_assignment_id AND student_id = p_student_id;
  END IF;

  RETURN QUERY SELECT v_progress, v_completed, v_total;
END;
$$;
