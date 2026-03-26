-- Add p_grade parameter to update_class RPC
CREATE OR REPLACE FUNCTION update_class(
  p_class_id UUID,
  p_name TEXT,
  p_grade INTEGER,
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

  UPDATE classes
  SET name = p_name, grade = p_grade, description = p_description
  WHERE classes.id = p_class_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
