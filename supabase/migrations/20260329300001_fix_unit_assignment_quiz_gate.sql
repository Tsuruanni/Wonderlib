-- Fix: Unit assignment RPCs check chapter count instead of is_completed for books.
-- This means quiz-gated books are counted as "complete" when all chapters are read,
-- even if the quiz hasn't been passed. Fix all 5 RPCs to use reading_progress.is_completed.

-- 1. Fix get_unit_assignment_items: use is_completed for book completion display
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
#variable_conflict use_column
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
      ELSE NULL::BIGINT
    END AS word_count,
    CASE
      WHEN sui.word_list_id IS NOT NULL THEN
        EXISTS (
          SELECT 1 FROM user_word_list_progress uwlp
          WHERE uwlp.user_id = p_student_id
            AND uwlp.word_list_id = sui.word_list_id
            AND uwlp.completed_at IS NOT NULL
        )
      ELSE NULL::BOOLEAN
    END AS is_word_list_completed,
    sui.book_id,
    b.title::VARCHAR AS book_title,
    CASE
      WHEN sui.book_id IS NOT NULL THEN
        (SELECT COUNT(*)::BIGINT FROM chapters ch WHERE ch.book_id = sui.book_id)
      ELSE NULL::BIGINT
    END AS total_chapters,
    CASE
      WHEN sui.book_id IS NOT NULL THEN
        (SELECT COALESCE(array_length(rp.completed_chapter_ids, 1), 0)::BIGINT
         FROM reading_progress rp
         WHERE rp.user_id = p_student_id AND rp.book_id = sui.book_id)
      ELSE NULL::BIGINT
    END AS completed_chapters,
    -- Use is_completed instead of chapter count comparison.
    -- is_completed respects quiz gates: only true when no quiz OR quiz passed.
    CASE
      WHEN sui.book_id IS NOT NULL THEN
        COALESCE(
          (SELECT rp.is_completed
           FROM reading_progress rp
           WHERE rp.user_id = p_student_id AND rp.book_id = sui.book_id),
          false
        )
      ELSE NULL::BOOLEAN
    END AS is_book_completed
  FROM scope_unit_items sui
  LEFT JOIN word_lists wl ON wl.id = sui.word_list_id
  LEFT JOIN books b ON b.id = sui.book_id
  WHERE sui.scope_lp_unit_id = p_scope_lp_unit_id
  ORDER BY sui.sort_order;
END;
$$;

-- 2. Fix calculate_unit_assignment_progress: use is_completed for book completion
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
  -- Auth: caller must be the student
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
      -- Use is_completed instead of chapter count comparison.
      -- is_completed respects quiz gates: only true when no quiz OR quiz passed.
      (sui.item_type = 'book' AND EXISTS (
        SELECT 1 FROM reading_progress rp
        WHERE rp.user_id = p_student_id
          AND rp.book_id = sui.book_id
          AND rp.is_completed = true
      ))
    );

  v_progress := ROUND((v_completed::NUMERIC / v_total) * 100, 1);

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

-- 3. Fix sync_unit_assignment_progress: use is_completed for book completion
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
  -- Get assignment info
  SELECT a.teacher_id, (a.content_config->>'scopeLpUnitId')::UUID
  INTO v_teacher_id, v_scope_lp_unit_id
  FROM assignments a WHERE a.id = p_assignment_id;

  IF v_teacher_id IS NULL THEN
    RAISE EXCEPTION 'Assignment not found';
  END IF;

  IF v_scope_lp_unit_id IS NULL THEN
    RAISE EXCEPTION 'Not a unit assignment';
  END IF;

  -- Auth: caller must be the teacher or admin
  IF auth.uid() != v_teacher_id AND NOT EXISTS (
    SELECT 1 FROM profiles pr WHERE pr.id = auth.uid() AND pr.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  -- Count total trackable items
  SELECT COUNT(*) INTO v_total
  FROM scope_unit_items sui
  WHERE sui.scope_lp_unit_id = v_scope_lp_unit_id
    AND sui.item_type IN ('word_list', 'book');

  IF v_total = 0 THEN
    RETURN;
  END IF;

  -- Loop each student
  FOR v_student IN
    SELECT asn.student_id
    FROM assignment_students asn
    WHERE asn.assignment_id = p_assignment_id
      AND asn.status != 'completed'
  LOOP
    -- Count completed items for this student
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
        -- Use is_completed instead of chapter count comparison.
        (sui.item_type = 'book' AND EXISTS (
          SELECT 1 FROM reading_progress rp
          WHERE rp.user_id = v_student.student_id
            AND rp.book_id = sui.book_id
            AND rp.is_completed = true
        ))
      );

    v_progress := ROUND((v_completed::NUMERIC / v_total) * 100, 1);

    IF v_progress >= 100 THEN
      UPDATE assignment_students
      SET status = 'completed', progress = 100, score = NULL,
          completed_at = NOW()
      WHERE assignment_id = p_assignment_id
        AND student_id = v_student.student_id
        AND status != 'completed';
    ELSIF v_completed > 0 THEN
      UPDATE assignment_students
      SET progress = v_progress,
          status = CASE WHEN status = 'pending' THEN 'in_progress' ELSE status END,
          started_at = CASE WHEN started_at IS NULL THEN NOW() ELSE started_at END
      WHERE assignment_id = p_assignment_id
        AND student_id = v_student.student_id;
    END IF;
  END LOOP;
END;
$$;

-- 4. Fix _backfill_student_unit_progress (class-change trigger helper)
CREATE OR REPLACE FUNCTION _backfill_student_unit_progress(
  p_assignment_id UUID,
  p_student_id UUID
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_scope_lp_unit_id UUID;
  v_total BIGINT;
  v_completed BIGINT;
  v_progress NUMERIC;
BEGIN
  SELECT (a.content_config->>'scopeLpUnitId')::UUID INTO v_scope_lp_unit_id
  FROM assignments a
  WHERE a.id = p_assignment_id AND a.type = 'unit';

  IF v_scope_lp_unit_id IS NULL THEN RETURN; END IF;

  SELECT COUNT(*) INTO v_total
  FROM scope_unit_items sui
  WHERE sui.scope_lp_unit_id = v_scope_lp_unit_id
    AND sui.item_type IN ('word_list', 'book');

  IF v_total = 0 THEN RETURN; END IF;

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
      (sui.item_type = 'book' AND EXISTS (
        SELECT 1 FROM reading_progress rp
        WHERE rp.user_id = p_student_id
          AND rp.book_id = sui.book_id
          AND rp.is_completed = true
      ))
    );

  IF v_completed = 0 THEN RETURN; END IF;

  v_progress := ROUND((v_completed::NUMERIC / v_total) * 100, 1);

  IF v_progress >= 100 THEN
    UPDATE assignment_students
    SET status = 'completed', progress = 100, completed_at = NOW(), started_at = COALESCE(started_at, NOW())
    WHERE assignment_id = p_assignment_id AND student_id = p_student_id
      AND status != 'completed';
  ELSE
    UPDATE assignment_students
    SET progress = v_progress,
        status = 'in_progress',
        started_at = COALESCE(started_at, NOW())
    WHERE assignment_id = p_assignment_id AND student_id = p_student_id;
  END IF;
END;
$$;

-- 5. Fix get_student_unit_progress (teacher detail view): use is_completed
CREATE OR REPLACE FUNCTION get_student_unit_progress(
  p_assignment_id UUID,
  p_student_id UUID
)
RETURNS TABLE (
  out_item_type VARCHAR,
  out_sort_order INTEGER,
  out_word_list_id UUID,
  out_word_list_name VARCHAR,
  out_word_count BIGINT,
  out_is_word_list_completed BOOLEAN,
  out_best_score NUMERIC,
  out_best_accuracy NUMERIC,
  out_total_sessions INTEGER,
  out_book_id UUID,
  out_book_title VARCHAR,
  out_total_chapters BIGINT,
  out_completed_chapters BIGINT,
  out_is_book_completed BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_teacher_id UUID;
  v_scope_lp_unit_id UUID;
BEGIN
  SELECT a.teacher_id, (a.content_config->>'scopeLpUnitId')::UUID
  INTO v_teacher_id, v_scope_lp_unit_id
  FROM assignments a WHERE a.id = p_assignment_id;

  IF v_teacher_id IS NULL THEN
    RAISE EXCEPTION 'Assignment not found';
  END IF;

  IF auth.uid() != v_teacher_id AND NOT EXISTS (
    SELECT 1 FROM profiles pr WHERE pr.id = auth.uid() AND pr.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN QUERY
  SELECT
    sui.item_type::VARCHAR,
    sui.sort_order,
    sui.word_list_id,
    wl.name::VARCHAR,
    CASE
      WHEN sui.word_list_id IS NOT NULL THEN
        (SELECT COUNT(*) FROM word_list_items wli WHERE wli.word_list_id = sui.word_list_id)
      ELSE NULL::BIGINT
    END,
    CASE
      WHEN sui.word_list_id IS NOT NULL THEN
        EXISTS (
          SELECT 1 FROM user_word_list_progress uwlp
          WHERE uwlp.user_id = p_student_id
            AND uwlp.word_list_id = sui.word_list_id
            AND uwlp.completed_at IS NOT NULL
        )
      ELSE NULL::BOOLEAN
    END,
    CASE
      WHEN sui.word_list_id IS NOT NULL THEN
        (SELECT uwlp.best_score FROM user_word_list_progress uwlp
         WHERE uwlp.user_id = p_student_id AND uwlp.word_list_id = sui.word_list_id)
      ELSE NULL::NUMERIC
    END,
    CASE
      WHEN sui.word_list_id IS NOT NULL THEN
        (SELECT uwlp.best_accuracy FROM user_word_list_progress uwlp
         WHERE uwlp.user_id = p_student_id AND uwlp.word_list_id = sui.word_list_id)
      ELSE NULL::NUMERIC
    END,
    CASE
      WHEN sui.word_list_id IS NOT NULL THEN
        (SELECT uwlp.total_sessions::INTEGER FROM user_word_list_progress uwlp
         WHERE uwlp.user_id = p_student_id AND uwlp.word_list_id = sui.word_list_id)
      ELSE NULL::INTEGER
    END,
    sui.book_id,
    b.title::VARCHAR,
    CASE
      WHEN sui.book_id IS NOT NULL THEN
        (SELECT COUNT(*)::BIGINT FROM chapters ch WHERE ch.book_id = sui.book_id)
      ELSE NULL::BIGINT
    END,
    CASE
      WHEN sui.book_id IS NOT NULL THEN
        (SELECT COALESCE(array_length(rp.completed_chapter_ids, 1), 0)::BIGINT
         FROM reading_progress rp
         WHERE rp.user_id = p_student_id AND rp.book_id = sui.book_id)
      ELSE NULL::BIGINT
    END,
    -- Use is_completed instead of chapter count comparison
    CASE
      WHEN sui.book_id IS NOT NULL THEN
        COALESCE(
          (SELECT rp.is_completed
           FROM reading_progress rp
           WHERE rp.user_id = p_student_id AND rp.book_id = sui.book_id),
          false
        )
      ELSE NULL::BOOLEAN
    END
  FROM scope_unit_items sui
  LEFT JOIN word_lists wl ON wl.id = sui.word_list_id
  LEFT JOIN books b ON b.id = sui.book_id
  WHERE sui.scope_lp_unit_id = v_scope_lp_unit_id
  ORDER BY sui.sort_order;
END;
$$;
