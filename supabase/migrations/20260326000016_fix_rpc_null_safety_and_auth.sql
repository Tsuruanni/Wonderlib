-- I1: Fix NULL safety in book completion checks (wrap outer subquery with COALESCE)
-- I3: Fix get_class_learning_path_units auth to verify teacher is in same school

-- Fix calculate_unit_assignment_progress: COALESCE book subquery
CREATE OR REPLACE FUNCTION calculate_unit_assignment_progress(
  p_assignment_id UUID,
  p_student_id UUID
)
RETURNS TABLE (progress NUMERIC, completed_count BIGINT, total_count BIGINT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
#variable_conflict use_column
DECLARE
  v_scope_lp_unit_id UUID;
  v_total BIGINT;
  v_completed BIGINT;
  v_progress NUMERIC;
BEGIN
  IF auth.uid() != p_student_id THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT (a.content_config->>'scopeLpUnitId')::UUID INTO v_scope_lp_unit_id
  FROM assignments a WHERE a.id = p_assignment_id;

  IF v_scope_lp_unit_id IS NULL THEN
    RAISE EXCEPTION 'Not a unit assignment or assignment not found';
  END IF;

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

  SELECT COUNT(*) INTO v_completed
  FROM scope_unit_items sui
  WHERE sui.scope_lp_unit_id = v_scope_lp_unit_id
    AND sui.item_type IN ('word_list', 'book')
    AND (
      (sui.item_type = 'word_list' AND EXISTS (
        SELECT 1 FROM user_word_list_progress uwlp
        WHERE uwlp.user_id = p_student_id
          AND uwlp.word_list_id = sui.word_list_id
          AND uwlp.completed_at IS NOT NULL
      ))
      OR
      (sui.item_type = 'book' AND COALESCE(
        (SELECT array_length(rp.completed_chapter_ids, 1)
         FROM reading_progress rp
         WHERE rp.user_id = p_student_id AND rp.book_id = sui.book_id),
        0
      ) >= (SELECT COUNT(*)::INT FROM chapters ch WHERE ch.book_id = sui.book_id))
    );

  v_progress := ROUND((v_completed::NUMERIC / v_total) * 100, 1);

  IF v_progress >= 100 THEN
    UPDATE assignment_students
    SET status = 'completed', progress = 100, score = NULL, completed_at = NOW()
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

-- Fix sync_unit_assignment_progress: same COALESCE fix
CREATE OR REPLACE FUNCTION sync_unit_assignment_progress(p_assignment_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
#variable_conflict use_column
DECLARE
  v_teacher_id UUID;
  v_scope_lp_unit_id UUID;
  v_student RECORD;
  v_total BIGINT;
  v_completed BIGINT;
  v_progress NUMERIC;
BEGIN
  SELECT a.teacher_id, (a.content_config->>'scopeLpUnitId')::UUID
  INTO v_teacher_id, v_scope_lp_unit_id
  FROM assignments a WHERE a.id = p_assignment_id;

  IF v_teacher_id IS NULL THEN
    RAISE EXCEPTION 'Assignment not found';
  END IF;
  IF v_scope_lp_unit_id IS NULL THEN
    RAISE EXCEPTION 'Not a unit assignment';
  END IF;

  IF auth.uid() != v_teacher_id AND NOT EXISTS (
    SELECT 1 FROM profiles pr WHERE pr.id = auth.uid() AND pr.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT COUNT(*) INTO v_total
  FROM scope_unit_items sui
  WHERE sui.scope_lp_unit_id = v_scope_lp_unit_id
    AND sui.item_type IN ('word_list', 'book');

  IF v_total = 0 THEN RETURN; END IF;

  FOR v_student IN
    SELECT asn.student_id FROM assignment_students asn
    WHERE asn.assignment_id = p_assignment_id AND asn.status != 'completed'
  LOOP
    SELECT COUNT(*) INTO v_completed
    FROM scope_unit_items sui
    WHERE sui.scope_lp_unit_id = v_scope_lp_unit_id
      AND sui.item_type IN ('word_list', 'book')
      AND (
        (sui.item_type = 'word_list' AND EXISTS (
          SELECT 1 FROM user_word_list_progress uwlp
          WHERE uwlp.user_id = v_student.student_id
            AND uwlp.word_list_id = sui.word_list_id
            AND uwlp.completed_at IS NOT NULL
        ))
        OR
        (sui.item_type = 'book' AND COALESCE(
          (SELECT array_length(rp.completed_chapter_ids, 1)
           FROM reading_progress rp
           WHERE rp.user_id = v_student.student_id AND rp.book_id = sui.book_id),
          0
        ) >= (SELECT COUNT(*)::INT FROM chapters ch WHERE ch.book_id = sui.book_id))
      );

    v_progress := ROUND((v_completed::NUMERIC / v_total) * 100, 1);

    IF v_progress >= 100 THEN
      UPDATE assignment_students
      SET status = 'completed', progress = 100, score = NULL, completed_at = NOW()
      WHERE assignment_id = p_assignment_id AND student_id = v_student.student_id
        AND status != 'completed';
    ELSIF v_completed > 0 THEN
      UPDATE assignment_students
      SET progress = v_progress,
          status = CASE WHEN status = 'pending' THEN 'in_progress' ELSE status END,
          started_at = CASE WHEN started_at IS NULL THEN NOW() ELSE started_at END
      WHERE assignment_id = p_assignment_id AND student_id = v_student.student_id;
    END IF;
  END LOOP;
END;
$$;

-- I3: Fix get_class_learning_path_units auth — verify teacher is in same school
DROP FUNCTION IF EXISTS get_class_learning_path_units(UUID);

CREATE FUNCTION get_class_learning_path_units(p_class_id UUID)
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
  v_caller_school_id UUID;
BEGIN
  -- Get caller's school
  SELECT pr.school_id INTO v_caller_school_id
  FROM profiles pr WHERE pr.id = auth.uid();

  -- Auth: caller must be teacher/admin in same school
  IF NOT EXISTS (
    SELECT 1 FROM profiles pr
    WHERE pr.id = auth.uid() AND pr.role IN ('teacher', 'admin')
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
  SELECT
    slp.id AS path_id,
    slp.name::VARCHAR AS path_name,
    vu.id AS unit_id,
    slpu.id AS scope_lp_unit_id,
    vu.name::VARCHAR AS unit_name,
    vu.color::VARCHAR AS unit_color,
    vu.icon::VARCHAR AS unit_icon,
    slpu.sort_order AS unit_sort_order,
    sui.item_type::VARCHAR AS item_type,
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
