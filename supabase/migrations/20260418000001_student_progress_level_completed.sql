-- =============================================
-- Expose book.level (CEFR) and reading_progress.is_completed from
-- get_student_progress_with_books so the teacher's student-detail
-- cards can show the CEFR badge and sort in-progress books first.
-- =============================================

DROP FUNCTION IF EXISTS get_student_progress_with_books(UUID);
CREATE FUNCTION get_student_progress_with_books(p_student_id UUID)
RETURNS TABLE (
  book_id UUID,
  book_title TEXT,
  book_cover_url TEXT,
  book_level TEXT,
  completion_percentage NUMERIC,
  total_reading_time INT,
  completed_chapters INT,
  total_chapters BIGINT,
  is_completed BOOLEAN,
  last_read_at TIMESTAMPTZ
) AS $$
DECLARE
  v_caller_school_id UUID;
  v_student_school_id UUID;
BEGIN
  IF auth.uid() = p_student_id THEN
    NULL;
  ELSIF is_teacher_or_higher() THEN
    SELECT school_id INTO v_caller_school_id FROM profiles WHERE id = auth.uid();
    SELECT school_id INTO v_student_school_id FROM profiles WHERE id = p_student_id;
    IF v_caller_school_id IS DISTINCT FROM v_student_school_id THEN
      RAISE EXCEPTION 'Unauthorized: student is not in your school';
    END IF;
  ELSE
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  RETURN QUERY
  SELECT
    b.id as book_id,
    b.title::TEXT as book_title,
    b.cover_url::TEXT as book_cover_url,
    b.level::TEXT as book_level,
    COALESCE(rp.completion_percentage, 0) as completion_percentage,
    COALESCE(rp.total_reading_time, 0) as total_reading_time,
    COALESCE(array_length(rp.completed_chapter_ids, 1), 0) as completed_chapters,
    (SELECT COUNT(*) FROM chapters ch WHERE ch.book_id = b.id) as total_chapters,
    COALESCE(rp.is_completed, false) as is_completed,
    rp.updated_at as last_read_at
  FROM reading_progress rp
  JOIN books b ON b.id = rp.book_id
  WHERE rp.user_id = p_student_id
  ORDER BY rp.updated_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_student_progress_with_books(UUID) TO authenticated;
