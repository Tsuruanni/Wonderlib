-- Fix get_classes_with_stats function to not require description column
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
    NULL::TEXT as description,  -- Column doesn't exist, return NULL
    COUNT(DISTINCT p.id) as student_count,
    COALESCE(AVG(rp.completion_percentage), 0) as avg_progress,
    c.created_at
  FROM classes c
  LEFT JOIN profiles p ON p.class_id = c.id AND p.role = 'student'
  LEFT JOIN reading_progress rp ON rp.user_id = p.id
  WHERE c.school_id = p_school_id
  GROUP BY c.id, c.name, c.grade, c.academic_year, c.created_at
  ORDER BY c.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_classes_with_stats IS 'Get classes with student counts and average progress for a school';
