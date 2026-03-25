-- =============================================
-- Atomic updateAssignmentProgress RPC
-- Problem: Flutter client does SELECT then UPDATE (race condition).
-- Fix: Single function with conditional logic in one transaction.
-- =============================================

CREATE OR REPLACE FUNCTION update_assignment_progress(
  p_student_id UUID,
  p_assignment_id UUID,
  p_progress DOUBLE PRECISION
)
RETURNS VOID AS $$
BEGIN
  -- Authorization: student can only update own progress
  IF auth.uid() != p_student_id THEN
    RAISE EXCEPTION 'Unauthorized: can only update own assignment progress';
  END IF;

  -- Atomic update: if pending and progress > 0, also set status to in_progress
  UPDATE assignment_students
  SET
    progress = p_progress,
    status = CASE
      WHEN status = 'pending' AND p_progress > 0 THEN 'in_progress'
      ELSE status
    END,
    started_at = CASE
      WHEN status = 'pending' AND p_progress > 0 AND started_at IS NULL THEN NOW()
      ELSE started_at
    END
  WHERE student_id = p_student_id
    AND assignment_id = p_assignment_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
