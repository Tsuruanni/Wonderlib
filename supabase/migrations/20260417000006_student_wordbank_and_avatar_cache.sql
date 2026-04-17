-- =============================================
-- Add per-student wordbank size + avatar_equipped_cache to the teacher RPC.
-- - Wordbank chip now lives on the student card, not the class card.
-- - Avatar cache lets the teacher student card render composite avatars
--   instead of showing only the first-letter fallback.
-- =============================================

DROP FUNCTION IF EXISTS get_school_students_for_teacher(UUID);
CREATE FUNCTION get_school_students_for_teacher(p_school_id UUID)
RETURNS TABLE (
  id UUID,
  first_name TEXT,
  last_name TEXT,
  student_number TEXT,
  username TEXT,
  email TEXT,
  avatar_url TEXT,
  avatar_equipped_cache JSONB,
  password_plain TEXT,
  xp INT,
  level INT,
  streak INT,
  books_read INT,
  avg_progress NUMERIC,
  league_tier TEXT,
  wordbank_size INT
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
    p.avatar_equipped_cache,
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
    p.league_tier::TEXT,
    COALESCE((
      SELECT COUNT(DISTINCT vp.word_id)::INT
      FROM vocabulary_progress vp
      WHERE vp.user_id = p.id
    ), 0) as wordbank_size
  FROM profiles p
  LEFT JOIN auth.users u ON p.id = u.id
  WHERE p.school_id = p_school_id AND p.role = 'student'
  ORDER BY p.xp DESC, p.last_name, p.first_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_school_students_for_teacher(UUID) TO authenticated;
