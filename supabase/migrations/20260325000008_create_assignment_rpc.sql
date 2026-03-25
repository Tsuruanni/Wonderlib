-- =============================================
-- Atomic createAssignment RPC
-- Problem: Flutter client does 3 separate queries (insert assignment,
-- select students, bulk insert assignment_students). If any step fails
-- after the first, we get an orphan assignment with 0 students.
-- Fix: Single RPC function that runs in an implicit transaction.
-- =============================================

CREATE OR REPLACE FUNCTION create_assignment_with_students(
  p_teacher_id UUID,
  p_class_id UUID,
  p_type TEXT,
  p_title TEXT,
  p_description TEXT,
  p_content_config JSONB,
  p_start_date TIMESTAMPTZ,
  p_due_date TIMESTAMPTZ,
  p_student_ids UUID[] DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_assignment_id UUID;
  v_student_ids UUID[];
BEGIN
  -- Authorization
  IF auth.uid() != p_teacher_id THEN
    RAISE EXCEPTION 'Unauthorized: can only create own assignments';
  END IF;

  IF NOT is_teacher_or_higher() THEN
    RAISE EXCEPTION 'Unauthorized: teacher or higher role required';
  END IF;

  -- 1. Insert assignment
  INSERT INTO assignments (teacher_id, class_id, type, title, description, content_config, start_date, due_date)
  VALUES (p_teacher_id, p_class_id, p_type, p_title, p_description, p_content_config, p_start_date, p_due_date)
  RETURNING id INTO v_assignment_id;

  -- 2. Determine student list
  IF p_student_ids IS NOT NULL AND array_length(p_student_ids, 1) > 0 THEN
    v_student_ids := p_student_ids;
  ELSIF p_class_id IS NOT NULL THEN
    SELECT array_agg(id) INTO v_student_ids
    FROM profiles
    WHERE class_id = p_class_id AND role = 'student';
  END IF;

  -- 3. Bulk insert assignment_students
  IF v_student_ids IS NOT NULL AND array_length(v_student_ids, 1) > 0 THEN
    INSERT INTO assignment_students (assignment_id, student_id, status, progress)
    SELECT v_assignment_id, unnest(v_student_ids), 'pending', 0;
  END IF;

  RETURN v_assignment_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
