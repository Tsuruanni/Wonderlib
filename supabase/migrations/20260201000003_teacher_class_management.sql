-- Migration: Teacher Class Management Functions
-- Adds RPC functions for teacher class management features
-- Optimized to eliminate N+1 query patterns

-- =============================================
-- 1. GET STUDENTS IN CLASS (with avg_progress)
-- =============================================
CREATE OR REPLACE FUNCTION get_students_in_class(p_class_id UUID)
RETURNS TABLE (
  id UUID,
  first_name TEXT,
  last_name TEXT,
  student_number TEXT,
  email TEXT,
  xp INT,
  level INT,
  streak INT,
  books_read INT,
  avg_progress NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id,
    p.first_name::TEXT,
    p.last_name::TEXT,
    p.student_number::TEXT,
    u.email::TEXT,
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
    ), 0) as avg_progress
  FROM profiles p
  LEFT JOIN auth.users u ON p.id = u.id
  WHERE p.class_id = p_class_id
  ORDER BY p.last_name, p.first_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_students_in_class(UUID) TO authenticated;

COMMENT ON FUNCTION get_students_in_class IS
  'Returns students in a class with email, stats, and avg progress. Eliminates N+1 queries.';

-- =============================================
-- 2. GET CLASSES WITH STATS
-- =============================================
CREATE OR REPLACE FUNCTION get_classes_with_stats(p_school_id UUID)
RETURNS TABLE (
  id UUID,
  name TEXT,
  grade INT,
  academic_year TEXT,
  description TEXT,
  student_count BIGINT,
  avg_progress NUMERIC,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.id,
    c.name::TEXT,
    c.grade,
    c.academic_year::TEXT,
    c.description::TEXT,
    COUNT(DISTINCT p.id) as student_count,
    COALESCE(AVG(rp.completion_percentage), 0) as avg_progress,
    c.created_at
  FROM classes c
  LEFT JOIN profiles p ON p.class_id = c.id AND p.role = 'student'
  LEFT JOIN reading_progress rp ON rp.user_id = p.id
  WHERE c.school_id = p_school_id
  GROUP BY c.id, c.name, c.grade, c.academic_year, c.description, c.created_at
  ORDER BY c.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_classes_with_stats(UUID) TO authenticated;

COMMENT ON FUNCTION get_classes_with_stats IS
  'Returns classes with student count and avg progress in single query. Eliminates N+1.';

-- =============================================
-- 3. GET TEACHER STATS
-- =============================================
CREATE OR REPLACE FUNCTION get_teacher_stats(p_teacher_id UUID)
RETURNS TABLE (
  total_students BIGINT,
  total_classes BIGINT,
  active_assignments BIGINT,
  avg_progress NUMERIC
) AS $$
DECLARE
  v_school_id UUID;
BEGIN
  -- Get teacher's school
  SELECT school_id INTO v_school_id
  FROM profiles
  WHERE id = p_teacher_id;

  IF v_school_id IS NULL THEN
    RETURN QUERY SELECT 0::BIGINT, 0::BIGINT, 0::BIGINT, 0::NUMERIC;
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM profiles WHERE school_id = v_school_id AND role = 'student') as total_students,
    (SELECT COUNT(*) FROM classes WHERE school_id = v_school_id) as total_classes,
    (SELECT COUNT(*) FROM assignments WHERE teacher_id = p_teacher_id AND due_date >= NOW()) as active_assignments,
    COALESCE((
      SELECT AVG(rp.completion_percentage)
      FROM reading_progress rp
      JOIN profiles p ON rp.user_id = p.id
      WHERE p.school_id = v_school_id AND p.role = 'student'
    ), 0) as avg_progress;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_teacher_stats(UUID) TO authenticated;

COMMENT ON FUNCTION get_teacher_stats IS
  'Returns teacher dashboard stats in single query. Eliminates N+1.';

-- =============================================
-- 4. GET STUDENT PROGRESS WITH BOOKS
-- =============================================
CREATE OR REPLACE FUNCTION get_student_progress_with_books(p_student_id UUID)
RETURNS TABLE (
  book_id UUID,
  book_title TEXT,
  book_cover_url TEXT,
  completion_percentage NUMERIC,
  total_reading_time INT,
  completed_chapters INT,
  total_chapters BIGINT,
  last_read_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    b.id as book_id,
    b.title::TEXT as book_title,
    b.cover_url::TEXT as book_cover_url,
    COALESCE(rp.completion_percentage, 0) as completion_percentage,
    COALESCE(rp.total_reading_time, 0) as total_reading_time,
    COALESCE(array_length(rp.completed_chapter_ids, 1), 0) as completed_chapters,
    (SELECT COUNT(*) FROM chapters ch WHERE ch.book_id = b.id) as total_chapters,
    rp.updated_at as last_read_at
  FROM reading_progress rp
  JOIN books b ON b.id = rp.book_id
  WHERE rp.user_id = p_student_id
  ORDER BY rp.updated_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_student_progress_with_books(UUID) TO authenticated;

COMMENT ON FUNCTION get_student_progress_with_books IS
  'Returns student reading progress with book details and chapter counts. Eliminates N+1.';

-- =============================================
-- 5. GET ASSIGNMENTS WITH STATS
-- =============================================
CREATE OR REPLACE FUNCTION get_assignments_with_stats(p_teacher_id UUID)
RETURNS TABLE (
  id UUID,
  teacher_id UUID,
  class_id UUID,
  class_name TEXT,
  type TEXT,
  title TEXT,
  description TEXT,
  content_config JSONB,
  start_date TIMESTAMPTZ,
  due_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ,
  total_students BIGINT,
  completed_students BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    a.id,
    a.teacher_id,
    a.class_id,
    c.name::TEXT as class_name,
    a.type::TEXT,
    a.title::TEXT,
    a.description::TEXT,
    a.content_config,
    a.start_date,
    a.due_date,
    a.created_at,
    COUNT(asst.id) as total_students,
    COUNT(asst.id) FILTER (WHERE asst.status = 'completed') as completed_students
  FROM assignments a
  LEFT JOIN classes c ON c.id = a.class_id
  LEFT JOIN assignment_students asst ON asst.assignment_id = a.id
  WHERE a.teacher_id = p_teacher_id
  GROUP BY a.id, a.teacher_id, a.class_id, c.name, a.type, a.title,
           a.description, a.content_config, a.start_date, a.due_date, a.created_at
  ORDER BY a.due_date ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_assignments_with_stats(UUID) TO authenticated;

COMMENT ON FUNCTION get_assignments_with_stats IS
  'Returns assignments with student completion stats. Eliminates N+1.';
