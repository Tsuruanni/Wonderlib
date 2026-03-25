-- =============================================
-- Class Management RPCs
-- 1. delete_class — safe delete (only if no students)
-- 2. bulk_move_students — atomic multi-student transfer
-- 3. update_class — edit class name/description
-- 4. Modify get_students_in_class — add password_plain
-- =============================================

-- 1. Safe class deletion
CREATE OR REPLACE FUNCTION delete_class(p_class_id UUID)
RETURNS VOID AS $$
DECLARE
  v_caller_school_id UUID;
  v_class_school_id UUID;
  v_student_count INT;
BEGIN
  IF NOT is_teacher_or_higher() THEN
    RAISE EXCEPTION 'Unauthorized: teacher or higher role required';
  END IF;

  SELECT pr.school_id INTO v_caller_school_id
  FROM profiles pr WHERE pr.id = auth.uid();

  SELECT cl.school_id INTO v_class_school_id
  FROM classes cl WHERE cl.id = p_class_id;

  IF v_class_school_id IS NULL THEN
    RAISE EXCEPTION 'Class not found';
  END IF;

  IF v_caller_school_id IS DISTINCT FROM v_class_school_id THEN
    RAISE EXCEPTION 'Unauthorized: class is not in your school';
  END IF;

  SELECT COUNT(*)::INT INTO v_student_count
  FROM profiles pr WHERE pr.class_id = p_class_id AND pr.role = 'student';

  IF v_student_count > 0 THEN
    RAISE EXCEPTION 'Cannot delete class with % students. Move all students first.', v_student_count;
  END IF;

  DELETE FROM classes WHERE classes.id = p_class_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Atomic bulk student transfer
CREATE OR REPLACE FUNCTION bulk_move_students(
  p_student_ids UUID[],
  p_target_class_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_caller_school_id UUID;
  v_target_school_id UUID;
  v_invalid_count INT;
BEGIN
  IF NOT is_teacher_or_higher() THEN
    RAISE EXCEPTION 'Unauthorized: teacher or higher role required';
  END IF;

  SELECT pr.school_id INTO v_caller_school_id
  FROM profiles pr WHERE pr.id = auth.uid();

  SELECT cl.school_id INTO v_target_school_id
  FROM classes cl WHERE cl.id = p_target_class_id;

  IF v_target_school_id IS NULL THEN
    RAISE EXCEPTION 'Target class not found';
  END IF;

  IF v_caller_school_id IS DISTINCT FROM v_target_school_id THEN
    RAISE EXCEPTION 'Unauthorized: target class is not in your school';
  END IF;

  SELECT COUNT(*)::INT INTO v_invalid_count
  FROM profiles pr
  WHERE pr.id = ANY(p_student_ids)
    AND (pr.school_id IS DISTINCT FROM v_caller_school_id OR pr.role != 'student');

  IF v_invalid_count > 0 THEN
    RAISE EXCEPTION 'Some students are not in your school';
  END IF;

  UPDATE profiles SET class_id = p_target_class_id
  WHERE profiles.id = ANY(p_student_ids);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Update class name/description
CREATE OR REPLACE FUNCTION update_class(
  p_class_id UUID,
  p_name TEXT,
  p_description TEXT DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
  v_caller_school_id UUID;
  v_class_school_id UUID;
BEGIN
  IF NOT is_teacher_or_higher() THEN
    RAISE EXCEPTION 'Unauthorized: teacher or higher role required';
  END IF;

  SELECT pr.school_id INTO v_caller_school_id
  FROM profiles pr WHERE pr.id = auth.uid();

  SELECT cl.school_id INTO v_class_school_id
  FROM classes cl WHERE cl.id = p_class_id;

  IF v_class_school_id IS NULL THEN
    RAISE EXCEPTION 'Class not found';
  END IF;

  IF v_caller_school_id IS DISTINCT FROM v_class_school_id THEN
    RAISE EXCEPTION 'Unauthorized: class is not in your school';
  END IF;

  UPDATE classes SET name = p_name, description = p_description
  WHERE classes.id = p_class_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Add password_plain to get_students_in_class
DROP FUNCTION IF EXISTS get_students_in_class(UUID);
CREATE OR REPLACE FUNCTION get_students_in_class(p_class_id UUID)
RETURNS TABLE (
  id UUID,
  first_name TEXT,
  last_name TEXT,
  student_number TEXT,
  email TEXT,
  avatar_url TEXT,
  password_plain TEXT,
  xp INT,
  level INT,
  streak INT,
  books_read INT,
  avg_progress NUMERIC
) AS $$
DECLARE
  v_caller_school_id UUID;
  v_class_school_id UUID;
BEGIN
  IF NOT is_teacher_or_higher() THEN
    RAISE EXCEPTION 'Unauthorized: teacher or higher role required';
  END IF;

  SELECT pr.school_id INTO v_caller_school_id
  FROM profiles pr WHERE pr.id = auth.uid();

  SELECT cl.school_id INTO v_class_school_id
  FROM classes cl WHERE cl.id = p_class_id;

  IF v_caller_school_id IS DISTINCT FROM v_class_school_id THEN
    RAISE EXCEPTION 'Unauthorized: cannot access students from another school';
  END IF;

  RETURN QUERY
  SELECT
    p.id,
    p.first_name::TEXT,
    p.last_name::TEXT,
    p.student_number::TEXT,
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
    ), 0) as avg_progress
  FROM profiles p
  LEFT JOIN auth.users u ON p.id = u.id
  WHERE p.class_id = p_class_id
  ORDER BY p.last_name, p.first_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
