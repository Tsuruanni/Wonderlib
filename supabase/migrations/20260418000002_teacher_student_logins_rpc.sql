-- =============================================
-- Teacher report: monthly login/freeze dates for a specific student.
-- daily_logins has RLS that blocks teachers from reading other students'
-- rows directly. This RPC wraps the lookup under SECURITY DEFINER with an
-- explicit "same school" check.
-- =============================================

CREATE OR REPLACE FUNCTION get_student_monthly_logins(
  p_student_id UUID,
  p_year INT,
  p_month INT
)
RETURNS TABLE (
  login_date DATE,
  is_freeze BOOLEAN
) AS $$
DECLARE
  v_caller_school_id UUID;
  v_student_school_id UUID;
  v_from DATE;
  v_next_month DATE;
BEGIN
  IF auth.uid() = p_student_id THEN
    -- A student pulling their own data.
    NULL;
  ELSIF is_teacher_or_higher() THEN
    SELECT school_id INTO v_caller_school_id
    FROM profiles WHERE id = auth.uid();
    SELECT school_id INTO v_student_school_id
    FROM profiles WHERE id = p_student_id;
    IF v_caller_school_id IS DISTINCT FROM v_student_school_id THEN
      RAISE EXCEPTION 'Unauthorized: student is not in your school';
    END IF;
  ELSE
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  v_from := make_date(p_year, p_month, 1);
  v_next_month := (v_from + INTERVAL '1 month')::DATE;

  RETURN QUERY
  SELECT dl.login_date, COALESCE(dl.is_freeze, false) as is_freeze
  FROM daily_logins dl
  WHERE dl.user_id = p_student_id
    AND dl.login_date >= v_from
    AND dl.login_date < v_next_month
  ORDER BY dl.login_date;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_student_monthly_logins(UUID, INT, INT) TO authenticated;
