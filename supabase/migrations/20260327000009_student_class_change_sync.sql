-- =============================================
-- Student Class Change → Assignment Sync
--
-- When a student's class_id changes on profiles:
-- 1. Withdraw (soft-delete) from old class's non-completed assignments
-- 2. Enroll in new class's active, non-expired assignments
-- 3. Backfill unit assignment progress from existing LP work
--
-- Also updates stats RPCs to exclude 'withdrawn' from counts,
-- and sync RPC to skip withdrawn students.
-- =============================================

-- 1. Expand assignment_students status CHECK to include 'withdrawn'
ALTER TABLE assignment_students
  DROP CONSTRAINT IF EXISTS assignment_students_status_check;

ALTER TABLE assignment_students
  ADD CONSTRAINT assignment_students_status_check
  CHECK (status IN ('pending', 'in_progress', 'completed', 'overdue', 'withdrawn'));

-- 2. Internal helper: backfill a single student's unit assignment progress
--    Mirrors the per-student logic from sync_unit_assignment_progress,
--    but without auth checks (called from trigger context).
CREATE OR REPLACE FUNCTION _backfill_student_unit_progress(
  p_assignment_id UUID,
  p_student_id UUID
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_scope_lp_unit_id UUID;
  v_total BIGINT;
  v_completed BIGINT;
  v_progress NUMERIC;
BEGIN
  -- Get the scope LP unit ID from the assignment's content_config
  SELECT (a.content_config->>'scopeLpUnitId')::UUID INTO v_scope_lp_unit_id
  FROM assignments a
  WHERE a.id = p_assignment_id AND a.type = 'unit';

  IF v_scope_lp_unit_id IS NULL THEN RETURN; END IF;

  -- Count total trackable items (word_list + book only; game/treasure are not graded)
  SELECT COUNT(*) INTO v_total
  FROM scope_unit_items sui
  WHERE sui.scope_lp_unit_id = v_scope_lp_unit_id
    AND sui.item_type IN ('word_list', 'book');

  IF v_total = 0 THEN RETURN; END IF;

  -- Count completed items for this student
  SELECT COUNT(*) INTO v_completed
  FROM scope_unit_items sui
  WHERE sui.scope_lp_unit_id = v_scope_lp_unit_id
    AND sui.item_type IN ('word_list', 'book')
    AND (
      (sui.item_type = 'word_list' AND EXISTS (
        SELECT 1 FROM user_word_list_progress uwlp
        WHERE uwlp.user_id = p_student_id
          AND uwlp.word_list_id = sui.word_list_id
          AND uwlp.completed_at IS NOT NULL
      ))
      OR
      (sui.item_type = 'book' AND COALESCE(
        (SELECT array_length(rp.completed_chapter_ids, 1)
         FROM reading_progress rp
         WHERE rp.user_id = p_student_id AND rp.book_id = sui.book_id),
        0
      ) >= (SELECT COUNT(*)::INT FROM chapters ch WHERE ch.book_id = sui.book_id))
    );

  IF v_completed = 0 THEN RETURN; END IF;

  v_progress := ROUND((v_completed::NUMERIC / v_total) * 100, 1);

  -- Update the assignment_students row with backfilled progress
  IF v_progress >= 100 THEN
    UPDATE assignment_students
    SET status = 'completed', progress = 100, completed_at = NOW(), started_at = COALESCE(started_at, NOW())
    WHERE assignment_id = p_assignment_id AND student_id = p_student_id
      AND status != 'completed';
  ELSE
    UPDATE assignment_students
    SET progress = v_progress,
        status = 'in_progress',
        started_at = COALESCE(started_at, NOW())
    WHERE assignment_id = p_assignment_id AND student_id = p_student_id;
  END IF;
END;
$$;

-- 3. Main trigger function
CREATE OR REPLACE FUNCTION handle_student_class_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_assignment RECORD;
BEGIN
  -- Only process students
  IF NEW.role != 'student' THEN RETURN NEW; END IF;

  -- Only fire when class_id actually changes
  IF OLD.class_id IS NOT DISTINCT FROM NEW.class_id THEN RETURN NEW; END IF;

  -- STEP 1: Withdraw from old class's non-completed assignments
  --         Completed assignments are left untouched (student earned them).
  IF OLD.class_id IS NOT NULL THEN
    UPDATE assignment_students AS asn
    SET status = 'withdrawn'
    WHERE asn.student_id = NEW.id
      AND asn.status IN ('pending', 'in_progress')
      AND asn.assignment_id IN (
        SELECT a.id FROM assignments a WHERE a.class_id = OLD.class_id
      );
  END IF;

  -- STEP 2: Enroll in new class's active, non-expired assignments
  IF NEW.class_id IS NOT NULL THEN
    INSERT INTO assignment_students (assignment_id, student_id, status, progress)
    SELECT a.id, NEW.id, 'pending', 0
    FROM assignments a
    WHERE a.class_id = NEW.class_id
      AND a.due_date > NOW()
    ON CONFLICT (assignment_id, student_id) DO UPDATE
    SET status = 'pending',
        progress = 0,
        score = NULL,
        started_at = NULL,
        completed_at = NULL
    WHERE assignment_students.status = 'withdrawn';

    -- STEP 3: Backfill progress for unit-type assignments
    --         If the student already completed items on the learning path,
    --         reflect that in the assignment progress.
    FOR v_assignment IN
      SELECT a.id
      FROM assignments a
      WHERE a.class_id = NEW.class_id
        AND a.due_date > NOW()
        AND a.type = 'unit'
    LOOP
      PERFORM _backfill_student_unit_progress(v_assignment.id, NEW.id);
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$;

-- 4. Create trigger (fires only when class_id column is in the UPDATE SET clause)
DROP TRIGGER IF EXISTS on_student_class_change ON profiles;
CREATE TRIGGER on_student_class_change
  AFTER UPDATE OF class_id ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_student_class_change();

-- 5. Update get_assignments_with_stats: exclude withdrawn from counts
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
    SELECT pr.role = 'admin' FROM profiles pr WHERE pr.id = auth.uid()
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
    COUNT(asst.id) FILTER (WHERE asst.status != 'withdrawn') as total_students,
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

-- 6. Update get_assignment_detail_with_stats: exclude withdrawn from counts
DROP FUNCTION IF EXISTS get_assignment_detail_with_stats(UUID);

CREATE FUNCTION get_assignment_detail_with_stats(p_assignment_id UUID)
RETURNS TABLE (
  id UUID,
  teacher_id UUID,
  class_id UUID,
  class_name VARCHAR,
  type VARCHAR,
  title VARCHAR,
  description TEXT,
  content_config JSONB,
  start_date TIMESTAMPTZ,
  due_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ,
  total_students BIGINT,
  completed_students BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
#variable_conflict use_column
DECLARE
  v_teacher_id UUID;
BEGIN
  SELECT a.teacher_id INTO v_teacher_id
  FROM assignments a WHERE a.id = p_assignment_id;

  IF v_teacher_id IS NULL THEN
    RAISE EXCEPTION 'Assignment not found: %', p_assignment_id;
  END IF;

  IF auth.uid() != v_teacher_id AND NOT EXISTS (
    SELECT 1 FROM profiles pr WHERE pr.id = auth.uid() AND pr.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN QUERY
  SELECT
    a.id,
    a.teacher_id,
    a.class_id,
    c.name::VARCHAR AS class_name,
    a.type::VARCHAR,
    a.title::VARCHAR,
    a.description,
    a.content_config,
    a.start_date,
    a.due_date,
    a.created_at,
    COUNT(asn.id) FILTER (WHERE asn.status != 'withdrawn') AS total_students,
    COUNT(asn.id) FILTER (WHERE asn.status = 'completed') AS completed_students
  FROM assignments a
  LEFT JOIN classes c ON c.id = a.class_id
  LEFT JOIN assignment_students asn ON asn.assignment_id = a.id
  WHERE a.id = p_assignment_id
  GROUP BY a.id, a.teacher_id, a.class_id, c.name, a.type, a.title,
           a.description, a.content_config, a.start_date, a.due_date, a.created_at;
END;
$$;

-- 7. Update sync_unit_assignment_progress: skip withdrawn students
CREATE OR REPLACE FUNCTION sync_unit_assignment_progress(p_assignment_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
#variable_conflict use_column
DECLARE
  v_teacher_id UUID;
  v_scope_lp_unit_id UUID;
  v_student RECORD;
  v_total BIGINT;
  v_completed BIGINT;
  v_progress NUMERIC;
BEGIN
  SELECT a.teacher_id, (a.content_config->>'scopeLpUnitId')::UUID
  INTO v_teacher_id, v_scope_lp_unit_id
  FROM assignments a WHERE a.id = p_assignment_id;

  IF v_teacher_id IS NULL THEN
    RAISE EXCEPTION 'Assignment not found';
  END IF;
  IF v_scope_lp_unit_id IS NULL THEN
    RAISE EXCEPTION 'Not a unit assignment';
  END IF;

  IF auth.uid() != v_teacher_id AND NOT EXISTS (
    SELECT 1 FROM profiles pr WHERE pr.id = auth.uid() AND pr.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT COUNT(*) INTO v_total
  FROM scope_unit_items sui
  WHERE sui.scope_lp_unit_id = v_scope_lp_unit_id
    AND sui.item_type IN ('word_list', 'book');

  IF v_total = 0 THEN RETURN; END IF;

  FOR v_student IN
    SELECT asn.student_id FROM assignment_students asn
    WHERE asn.assignment_id = p_assignment_id
      AND asn.status NOT IN ('completed', 'withdrawn')
  LOOP
    SELECT COUNT(*) INTO v_completed
    FROM scope_unit_items sui
    WHERE sui.scope_lp_unit_id = v_scope_lp_unit_id
      AND sui.item_type IN ('word_list', 'book')
      AND (
        (sui.item_type = 'word_list' AND EXISTS (
          SELECT 1 FROM user_word_list_progress uwlp
          WHERE uwlp.user_id = v_student.student_id
            AND uwlp.word_list_id = sui.word_list_id
            AND uwlp.completed_at IS NOT NULL
        ))
        OR
        (sui.item_type = 'book' AND COALESCE(
          (SELECT array_length(rp.completed_chapter_ids, 1)
           FROM reading_progress rp
           WHERE rp.user_id = v_student.student_id AND rp.book_id = sui.book_id),
          0
        ) >= (SELECT COUNT(*)::INT FROM chapters ch WHERE ch.book_id = sui.book_id))
      );

    v_progress := ROUND((v_completed::NUMERIC / v_total) * 100, 1);

    IF v_progress >= 100 THEN
      UPDATE assignment_students
      SET status = 'completed', progress = 100, score = NULL, completed_at = NOW()
      WHERE assignment_id = p_assignment_id AND student_id = v_student.student_id
        AND status != 'completed';
    ELSIF v_completed > 0 THEN
      UPDATE assignment_students
      SET progress = v_progress,
          status = CASE WHEN status = 'pending' THEN 'in_progress' ELSE status END,
          started_at = CASE WHEN started_at IS NULL THEN NOW() ELSE started_at END
      WHERE assignment_id = p_assignment_id AND student_id = v_student.student_id;
    END IF;
  END LOOP;
END;
$$;
