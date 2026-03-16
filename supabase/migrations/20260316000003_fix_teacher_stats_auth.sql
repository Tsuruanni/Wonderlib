-- Fix get_teacher_stats: verify caller is requesting their OWN stats
-- Previously: any teacher could pass any teacher_id and see their school's stats
-- Now: enforces auth.uid() = p_teacher_id

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
  -- Security check: caller must be requesting their own stats
  IF auth.uid() != p_teacher_id THEN
    RAISE EXCEPTION 'Unauthorized: can only view own stats';
  END IF;

  IF NOT is_teacher_or_higher() THEN
    RAISE EXCEPTION 'Unauthorized: teacher role required';
  END IF;

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
