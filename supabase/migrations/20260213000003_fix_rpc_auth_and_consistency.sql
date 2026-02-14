-- =============================================
-- FIX: RPC Authorization + Schema Consistency
-- Combines: Teacher RPC auth checks, content_blocks RLS,
-- user_node_completions FK, missing indexes, stale comments
-- =============================================

-- =============================================
-- PHASE 2: Teacher RPC Authorization
-- Problem: SECURITY DEFINER + GRANT TO authenticated means
-- any user (including students) can call teacher-only functions.
-- Fix: Add is_teacher_or_higher() check at function entry.
-- =============================================

-- 1. get_students_in_class
CREATE OR REPLACE FUNCTION get_students_in_class(p_class_id UUID)
RETURNS TABLE (
  id UUID,
  first_name TEXT,
  last_name TEXT,
  student_number TEXT,
  email TEXT,
  xp INT,
  level INT,
  streak INT,
  books_read INT,
  avg_progress NUMERIC
) AS $$
BEGIN
  -- Authorization: teacher or higher only
  IF NOT is_teacher_or_higher() THEN
    RAISE EXCEPTION 'Unauthorized: teacher or higher role required';
  END IF;

  RETURN QUERY
  SELECT
    p.id,
    p.first_name::TEXT,
    p.last_name::TEXT,
    p.student_number::TEXT,
    u.email::TEXT,
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

-- 2. get_classes_with_stats
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
  -- Authorization: teacher or higher only
  IF NOT is_teacher_or_higher() THEN
    RAISE EXCEPTION 'Unauthorized: teacher or higher role required';
  END IF;

  RETURN QUERY
  SELECT
    c.id,
    c.name::TEXT,
    c.grade,
    c.academic_year::TEXT,
    c.description::TEXT,
    COUNT(DISTINCT p.id) as student_count,
    COALESCE(AVG(rp.completion_percentage), 0) as avg_progress,
    c.created_at
  FROM classes c
  LEFT JOIN profiles p ON p.class_id = c.id AND p.role = 'student'
  LEFT JOIN reading_progress rp ON rp.user_id = p.id
  WHERE c.school_id = p_school_id
  GROUP BY c.id, c.name, c.grade, c.academic_year, c.description, c.created_at
  ORDER BY c.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. get_teacher_stats
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
  -- Authorization: teacher or higher only
  IF NOT is_teacher_or_higher() THEN
    RAISE EXCEPTION 'Unauthorized: teacher or higher role required';
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

-- 4. get_student_progress_with_books: Allow own access + teacher access
CREATE OR REPLACE FUNCTION get_student_progress_with_books(p_student_id UUID)
RETURNS TABLE (
  book_id UUID,
  book_title TEXT,
  book_cover_url TEXT,
  completion_percentage NUMERIC,
  total_reading_time INT,
  completed_chapters INT,
  total_chapters BIGINT,
  last_read_at TIMESTAMPTZ
) AS $$
BEGIN
  -- Authorization: own data or teacher+
  IF auth.uid() != p_student_id AND NOT is_teacher_or_higher() THEN
    RAISE EXCEPTION 'Unauthorized: can only view own progress or requires teacher role';
  END IF;

  RETURN QUERY
  SELECT
    b.id as book_id,
    b.title::TEXT as book_title,
    b.cover_url::TEXT as book_cover_url,
    COALESCE(rp.completion_percentage, 0) as completion_percentage,
    COALESCE(rp.total_reading_time, 0) as total_reading_time,
    COALESCE(array_length(rp.completed_chapter_ids, 1), 0) as completed_chapters,
    (SELECT COUNT(*) FROM chapters ch WHERE ch.book_id = b.id) as total_chapters,
    rp.updated_at as last_read_at
  FROM reading_progress rp
  JOIN books b ON b.id = rp.book_id
  WHERE rp.user_id = p_student_id
  ORDER BY rp.updated_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. get_assignments_with_stats: Only the owning teacher or admin
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
  -- Authorization: own assignments or admin
  IF auth.uid() != p_teacher_id AND NOT is_teacher_or_higher() THEN
    RAISE EXCEPTION 'Unauthorized: can only view own assignments or requires teacher role';
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
    COUNT(asst.id) as total_students,
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

-- =============================================
-- PHASE 3: content_blocks RLS Consistency
-- ALREADY FIXED in 20260208000001 and 20260208000003.
-- The raw_user_meta_data policy was dropped and replaced with
-- proper profiles.role checks. No action needed.
-- =============================================

-- =============================================
-- PHASE 4: FK Consistency — user_node_completions
-- Problem: References auth.users(id) instead of profiles(id).
-- All other tables reference profiles(id).
-- =============================================

ALTER TABLE user_node_completions
  DROP CONSTRAINT IF EXISTS user_node_completions_user_id_fkey;

ALTER TABLE user_node_completions
  ADD CONSTRAINT user_node_completions_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- =============================================
-- PHASE 5: Missing Indexes
-- =============================================

-- content_blocks.activity_id — joins for activity blocks
CREATE INDEX IF NOT EXISTS idx_content_blocks_activity
  ON content_blocks(activity_id) WHERE activity_id IS NOT NULL;

-- vocabulary_progress(user_id, status) — status filtering queries
CREATE INDEX IF NOT EXISTS idx_vocabulary_progress_user_status
  ON vocabulary_progress(user_id, status);

-- profiles.last_activity_date — streak calculation
CREATE INDEX IF NOT EXISTS idx_profiles_last_activity
  ON profiles(last_activity_date) WHERE last_activity_date IS NOT NULL;

-- =============================================
-- PHASE 6: Stale Comment Fix
-- =============================================

COMMENT ON TABLE user_word_list_progress IS 'Session-based vocabulary learning progress per user per list';
