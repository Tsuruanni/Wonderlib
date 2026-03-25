-- =============================================
-- Recent Activity for Teacher Dashboard
-- Aggregates recent XP events from students in the teacher's school.
-- Uses xp_logs as the primary activity source.
-- =============================================

CREATE OR REPLACE FUNCTION get_recent_school_activity(
  p_school_id UUID,
  p_limit INT DEFAULT 20
)
RETURNS TABLE (
  student_id UUID,
  student_first_name TEXT,
  student_last_name TEXT,
  avatar_url TEXT,
  activity_type TEXT,
  description TEXT,
  xp_amount INT,
  created_at TIMESTAMPTZ
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
    xl.user_id as student_id,
    p.first_name::TEXT as student_first_name,
    p.last_name::TEXT as student_last_name,
    p.avatar_url::TEXT,
    xl.source::TEXT as activity_type,
    xl.description::TEXT,
    xl.amount as xp_amount,
    xl.created_at
  FROM xp_logs xl
  JOIN profiles p ON xl.user_id = p.id
  WHERE p.school_id = p_school_id
    AND p.role = 'student'
    AND xl.created_at >= NOW() - INTERVAL '7 days'
  ORDER BY xl.created_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
