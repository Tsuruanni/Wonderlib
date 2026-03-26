-- Teacher-callable RPC to see a student's per-item progress in a unit assignment.
-- Returns same columns as get_unit_assignment_items but with teacher auth.
-- Also includes best_score and best_accuracy for word lists.

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
  -- Get assignment info
  SELECT a.teacher_id, (a.content_config->>'scopeLpUnitId')::UUID
  INTO v_teacher_id, v_scope_lp_unit_id
  FROM assignments a WHERE a.id = p_assignment_id;

  IF v_teacher_id IS NULL THEN
    RAISE EXCEPTION 'Assignment not found';
  END IF;

  -- Auth: caller must be the teacher or admin
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
    CASE
      WHEN sui.book_id IS NOT NULL THEN
        COALESCE(
          (SELECT array_length(rp.completed_chapter_ids, 1) >=
                  (SELECT COUNT(*)::INT FROM chapters ch WHERE ch.book_id = sui.book_id)
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
