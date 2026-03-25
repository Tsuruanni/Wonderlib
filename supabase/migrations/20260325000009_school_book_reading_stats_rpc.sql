-- =============================================
-- Reading Progress Report: per-book stats scoped to a school
-- Returns reader counts and avg progress for each book,
-- considering only students in the teacher's school.
-- =============================================

CREATE OR REPLACE FUNCTION get_school_book_reading_stats(p_school_id UUID)
RETURNS TABLE (
  book_id UUID,
  title TEXT,
  cover_url TEXT,
  level TEXT,
  total_readers INT,
  completed_readers INT,
  avg_progress NUMERIC
) AS $$
DECLARE
  v_caller_school_id UUID;
BEGIN
  -- Authorization
  IF NOT is_teacher_or_higher() THEN
    RAISE EXCEPTION 'Unauthorized: teacher or higher role required';
  END IF;

  -- School-scope
  SELECT school_id INTO v_caller_school_id
  FROM profiles WHERE id = auth.uid();

  IF v_caller_school_id IS DISTINCT FROM p_school_id THEN
    RAISE EXCEPTION 'Unauthorized: cannot access another school data';
  END IF;

  RETURN QUERY
  SELECT
    b.id as book_id,
    b.title::TEXT,
    b.cover_url::TEXT,
    b.level::TEXT,
    COALESCE(COUNT(DISTINCT rp.user_id)::INT, 0) as total_readers,
    COALESCE(COUNT(DISTINCT rp.user_id) FILTER (WHERE rp.is_completed = true)::INT, 0) as completed_readers,
    COALESCE(AVG(rp.completion_percentage), 0) as avg_progress
  FROM books b
  LEFT JOIN reading_progress rp ON rp.book_id = b.id
    AND rp.user_id IN (
      SELECT p.id FROM profiles p
      WHERE p.school_id = p_school_id AND p.role = 'student'
    )
  GROUP BY b.id, b.title, b.cover_url, b.level
  ORDER BY total_readers DESC, b.title;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
