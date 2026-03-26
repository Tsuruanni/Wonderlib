-- =============================================
-- Enrich get_classes_with_stats with deeper metrics
-- Adds: avg_xp, avg_streak, total_reading_time, completed_books,
--        active_last_30d, total_vocab_words
-- =============================================

DROP FUNCTION IF EXISTS get_classes_with_stats(UUID);
CREATE FUNCTION get_classes_with_stats(p_school_id UUID)
RETURNS TABLE (
  id UUID,
  name TEXT,
  grade INT,
  academic_year TEXT,
  description TEXT,
  student_count BIGINT,
  avg_progress NUMERIC,
  avg_xp NUMERIC,
  avg_streak NUMERIC,
  total_reading_time BIGINT,
  completed_books BIGINT,
  active_last_30d BIGINT,
  total_vocab_words BIGINT,
  created_at TIMESTAMPTZ
) AS $$
DECLARE
  v_caller_school_id UUID;
BEGIN
  IF NOT is_teacher_or_higher() THEN
    RAISE EXCEPTION 'Unauthorized: teacher or higher role required';
  END IF;

  SELECT pr.school_id INTO v_caller_school_id
  FROM profiles pr WHERE pr.id = auth.uid();

  IF v_caller_school_id IS DISTINCT FROM p_school_id THEN
    RAISE EXCEPTION 'Unauthorized: cannot access classes from another school';
  END IF;

  RETURN QUERY
  SELECT
    c.id,
    c.name::TEXT,
    c.grade,
    c.academic_year::TEXT,
    c.description::TEXT,
    COUNT(DISTINCT p.id) as student_count,
    COALESCE(AVG(rp_avg.avg_completion), 0) as avg_progress,
    COALESCE(AVG(p.xp), 0) as avg_xp,
    COALESCE(AVG(p.current_streak), 0) as avg_streak,
    COALESCE(SUM(rp_time.total_time), 0)::BIGINT as total_reading_time,
    COALESCE(SUM(rp_complete.book_count), 0)::BIGINT as completed_books,
    COUNT(DISTINCT CASE
      WHEN p.last_login_at >= NOW() - INTERVAL '30 days' THEN p.id
    END) as active_last_30d,
    COALESCE(SUM(vocab_ct.word_count), 0)::BIGINT as total_vocab_words,
    c.created_at
  FROM classes c
  LEFT JOIN profiles p ON p.class_id = c.id AND p.role = 'student'
  -- Avg reading progress per student
  LEFT JOIN LATERAL (
    SELECT AVG(rp.completion_percentage) as avg_completion
    FROM reading_progress rp WHERE rp.user_id = p.id
  ) rp_avg ON true
  -- Total reading time per student
  LEFT JOIN LATERAL (
    SELECT COALESCE(SUM(rp.total_reading_time), 0) as total_time
    FROM reading_progress rp WHERE rp.user_id = p.id
  ) rp_time ON true
  -- Completed books per student
  LEFT JOIN LATERAL (
    SELECT COUNT(*)::BIGINT as book_count
    FROM reading_progress rp WHERE rp.user_id = p.id AND rp.is_completed = true
  ) rp_complete ON true
  -- Vocabulary words learned per student
  LEFT JOIN LATERAL (
    SELECT COUNT(DISTINCT vp.word_id)::BIGINT as word_count
    FROM vocabulary_progress vp WHERE vp.user_id = p.id AND vp.mastery_level >= 3
  ) vocab_ct ON true
  WHERE c.school_id = p_school_id
  GROUP BY c.id, c.name, c.grade, c.academic_year, c.description, c.created_at
  ORDER BY c.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
