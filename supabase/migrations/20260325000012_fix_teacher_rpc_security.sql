-- =============================================
-- FIX: updateStudentClass broken (RLS blocks teacher UPDATE on profiles)
-- FIX: get_student_progress_with_books missing school-scope check
-- FIX: get_assignments_with_stats missing school-scope check
-- =============================================

-- 1. New RPC for changing student's class (teacher action)
CREATE OR REPLACE FUNCTION update_student_class(
  p_student_id UUID,
  p_new_class_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_caller_school_id UUID;
  v_student_school_id UUID;
  v_class_school_id UUID;
BEGIN
  IF NOT is_teacher_or_higher() THEN
    RAISE EXCEPTION 'Unauthorized: teacher or higher role required';
  END IF;

  SELECT school_id INTO v_caller_school_id
  FROM profiles WHERE id = auth.uid();

  SELECT school_id INTO v_student_school_id
  FROM profiles WHERE id = p_student_id AND role = 'student';

  IF v_student_school_id IS NULL THEN
    RAISE EXCEPTION 'Student not found';
  END IF;

  IF v_caller_school_id IS DISTINCT FROM v_student_school_id THEN
    RAISE EXCEPTION 'Unauthorized: student is not in your school';
  END IF;

  SELECT school_id INTO v_class_school_id
  FROM classes WHERE id = p_new_class_id;

  IF v_class_school_id IS NULL THEN
    RAISE EXCEPTION 'Class not found';
  END IF;

  IF v_caller_school_id IS DISTINCT FROM v_class_school_id THEN
    RAISE EXCEPTION 'Unauthorized: class is not in your school';
  END IF;

  UPDATE profiles SET class_id = p_new_class_id WHERE id = p_student_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Fix get_student_progress_with_books: add school-scope for teachers
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
DECLARE
  v_caller_school_id UUID;
  v_student_school_id UUID;
BEGIN
  IF auth.uid() = p_student_id THEN
    -- Own data: always allowed
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

-- 3. Fix get_assignments_with_stats: enforce own assignments only
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
  IF auth.uid() != p_teacher_id AND NOT (
    SELECT role = 'admin' FROM profiles WHERE id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Unauthorized: can only view own assignments';
  END IF;

  IF NOT is_teacher_or_higher() THEN
    RAISE EXCEPTION 'Unauthorized: teacher or higher role required';
  END IF;

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
