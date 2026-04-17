-- =============================================
-- Teacher Rankings feature
-- 1. Extend get_school_students_for_teacher with league_tier
-- 2. New get_school_summary(p_school_id)
-- 3. New get_global_student_averages()
-- =============================================

-- 1. Extend get_school_students_for_teacher to return league_tier
DROP FUNCTION IF EXISTS get_school_students_for_teacher(UUID);
CREATE OR REPLACE FUNCTION get_school_students_for_teacher(p_school_id UUID)
RETURNS TABLE (
  id UUID,
  first_name TEXT,
  last_name TEXT,
  student_number TEXT,
  username TEXT,
  email TEXT,
  avatar_url TEXT,
  password_plain TEXT,
  xp INT,
  level INT,
  streak INT,
  books_read INT,
  avg_progress NUMERIC,
  league_tier TEXT
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
    RAISE EXCEPTION 'Unauthorized: cannot access students from another school';
  END IF;

  RETURN QUERY
  SELECT
    p.id,
    p.first_name::TEXT,
    p.last_name::TEXT,
    p.student_number::TEXT,
    p.username::TEXT,
    u.email::TEXT,
    p.avatar_url::TEXT,
    p.password_plain::TEXT,
    p.xp,
    p.level,
    p.current_streak,
    COALESCE((
      SELECT COUNT(DISTINCT rp.book_id)::INT
      FROM reading_progress rp
      WHERE rp.user_id = p.id AND rp.is_completed = true
    ), 0) as books_read,
    COALESCE((
      SELECT AVG(rp2.completion_percentage)
      FROM reading_progress rp2
      WHERE rp2.user_id = p.id
    ), 0) as avg_progress,
    p.league_tier::TEXT
  FROM profiles p
  LEFT JOIN auth.users u ON p.id = u.id
  WHERE p.school_id = p_school_id AND p.role = 'student'
  ORDER BY p.xp DESC, p.last_name, p.first_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2. get_school_summary — aggregates for teacher's own school
CREATE OR REPLACE FUNCTION get_school_summary(p_school_id UUID)
RETURNS TABLE (
  total_students INT,
  active_last_30d INT,
  total_xp BIGINT,
  avg_xp NUMERIC,
  avg_streak NUMERIC,
  avg_progress NUMERIC,
  total_reading_time BIGINT,
  total_books_read INT,
  total_vocab_words INT
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
    RAISE EXCEPTION 'Unauthorized: cannot access another school';
  END IF;

  RETURN QUERY
  SELECT
    COUNT(DISTINCT p.id)::INT as total_students,
    COUNT(DISTINCT CASE
      WHEN p.last_login_at >= NOW() - INTERVAL '30 days' THEN p.id
    END)::INT as active_last_30d,
    COALESCE(SUM(p.xp), 0)::BIGINT as total_xp,
    COALESCE(AVG(p.xp), 0) as avg_xp,
    COALESCE(AVG(p.current_streak), 0) as avg_streak,
    COALESCE(AVG(rp_avg.avg_completion), 0) as avg_progress,
    COALESCE(SUM(rp_time.total_time), 0)::BIGINT as total_reading_time,
    COALESCE(SUM(rp_complete.book_count), 0)::INT as total_books_read,
    COALESCE(SUM(vocab_ct.word_count), 0)::INT as total_vocab_words
  FROM profiles p
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
  -- Vocabulary words mastered per student
  LEFT JOIN LATERAL (
    SELECT COUNT(DISTINCT vp.word_id)::BIGINT as word_count
    FROM vocabulary_progress vp WHERE vp.user_id = p.id AND vp.mastery_level >= 3
  ) vocab_ct ON true
  WHERE p.school_id = p_school_id AND p.role = 'student';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 3. get_global_student_averages — platform-wide averages across all schools
CREATE OR REPLACE FUNCTION get_global_student_averages()
RETURNS TABLE (
  avg_xp NUMERIC,
  avg_streak NUMERIC,
  avg_progress NUMERIC,
  avg_reading_time NUMERIC,
  avg_books_read NUMERIC
) AS $$
BEGIN
  -- Any authenticated user can read aggregated averages (no identifiable data).
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: authentication required';
  END IF;

  RETURN QUERY
  SELECT
    COALESCE(AVG(p.xp), 0) as avg_xp,
    COALESCE(AVG(p.current_streak), 0) as avg_streak,
    COALESCE(AVG(rp_avg.avg_completion), 0) as avg_progress,
    COALESCE(AVG(rp_time.total_time), 0) as avg_reading_time,
    COALESCE(AVG(rp_complete.book_count), 0) as avg_books_read
  FROM profiles p
  LEFT JOIN LATERAL (
    SELECT AVG(rp.completion_percentage) as avg_completion
    FROM reading_progress rp WHERE rp.user_id = p.id
  ) rp_avg ON true
  LEFT JOIN LATERAL (
    SELECT COALESCE(SUM(rp.total_reading_time), 0) as total_time
    FROM reading_progress rp WHERE rp.user_id = p.id
  ) rp_time ON true
  LEFT JOIN LATERAL (
    SELECT COUNT(*)::BIGINT as book_count
    FROM reading_progress rp WHERE rp.user_id = p.id AND rp.is_completed = true
  ) rp_complete ON true
  WHERE p.role = 'student';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
