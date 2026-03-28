-- start_assignment: validates enrollment + status before transitioning
CREATE OR REPLACE FUNCTION start_assignment(
  p_student_id UUID,
  p_assignment_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_status TEXT;
  v_start_date TIMESTAMPTZ;
BEGIN
  -- Auth check
  IF auth.uid() != p_student_id THEN
    RAISE EXCEPTION 'unauthorized';
  END IF;

  -- Get current state
  SELECT asst.status, a.start_date
  INTO v_current_status, v_start_date
  FROM assignment_students asst
  JOIN assignments a ON a.id = asst.assignment_id
  WHERE asst.student_id = p_student_id
    AND asst.assignment_id = p_assignment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'assignment_not_found';
  END IF;

  -- Already in_progress or completed — idempotent no-op
  IF v_current_status IN ('in_progress', 'completed') THEN
    RETURN;
  END IF;

  -- Can't start a withdrawn assignment
  IF v_current_status = 'withdrawn' THEN
    RAISE EXCEPTION 'assignment_withdrawn';
  END IF;

  -- Can't start before start_date
  IF NOW() < v_start_date THEN
    RAISE EXCEPTION 'assignment_not_yet_available';
  END IF;

  -- Transition pending → in_progress
  UPDATE assignment_students
  SET status = 'in_progress',
      started_at = NOW()
  WHERE student_id = p_student_id
    AND assignment_id = p_assignment_id;
END;
$$;

-- complete_assignment: validates enrollment + status + score range
CREATE OR REPLACE FUNCTION complete_assignment(
  p_student_id UUID,
  p_assignment_id UUID,
  p_score DECIMAL DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_status TEXT;
BEGIN
  -- Auth check
  IF auth.uid() != p_student_id THEN
    RAISE EXCEPTION 'unauthorized';
  END IF;

  -- Get current state
  SELECT status INTO v_current_status
  FROM assignment_students
  WHERE student_id = p_student_id
    AND assignment_id = p_assignment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'assignment_not_found';
  END IF;

  -- Already completed — idempotent no-op
  IF v_current_status = 'completed' THEN
    RETURN;
  END IF;

  -- Can't complete a withdrawn assignment
  IF v_current_status = 'withdrawn' THEN
    RAISE EXCEPTION 'assignment_withdrawn';
  END IF;

  -- Validate score range
  IF p_score IS NOT NULL AND (p_score < 0 OR p_score > 100) THEN
    RAISE EXCEPTION 'invalid_score';
  END IF;

  -- Complete the assignment
  UPDATE assignment_students
  SET status = 'completed',
      progress = 100,
      score = p_score,
      completed_at = NOW(),
      started_at = COALESCE(started_at, NOW())
  WHERE student_id = p_student_id
    AND assignment_id = p_assignment_id;
END;
$$;
