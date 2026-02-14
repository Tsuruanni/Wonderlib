-- ============================================================
-- Fix RLS Policy Issues
--
-- This migration fixes three categories of RLS problems:
--
-- 1. unit_book_assignments admin policy was too permissive
--    (USING true / WITH CHECK true let any authenticated user manage records)
--
-- 2. inline_activity_results lacked a teacher read policy
--    (teachers couldn't view student inline activity results)
--
-- 3. Role string inconsistency: profiles CHECK constraint only
--    allows 'head' but several newer policies/functions used
--    'head_teacher' which would never match any row.
--    Affected: book_quizzes, book_quiz_questions, book_quiz_results
--              policies + get_student_quiz_results,
--              get_student_vocab_stats, get_student_word_list_progress
--              RPC functions.
-- ============================================================

-- =============================================
-- FIX 1: unit_book_assignments admin policy
-- Was: USING (true) WITH CHECK (true) — any authenticated user
-- Now: restricted to teachers and admins via is_teacher_or_higher()
-- =============================================

DROP POLICY IF EXISTS "Admins can manage unit book assignments" ON unit_book_assignments;

CREATE POLICY "Teachers and admins can manage unit book assignments"
  ON unit_book_assignments FOR ALL
  TO authenticated
  USING (is_teacher_or_higher())
  WITH CHECK (is_teacher_or_higher());

-- =============================================
-- FIX 2: Add teacher read policy for inline_activity_results
-- Teachers could see activity_results but not inline_activity_results
-- =============================================

CREATE POLICY "Teachers can read student inline activity results"
  ON inline_activity_results FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() OR is_teacher_or_higher());

-- =============================================
-- FIX 3: Fix 'head_teacher' → 'head' in RLS policies
-- The profiles table CHECK constraint (migration 20260131000002)
-- only allows role = 'head', but these policies used 'head_teacher'
-- which would never match. is_teacher_or_higher() correctly uses
-- 'head', so we align everything.
-- =============================================

-- 3a. book_quizzes: "Admin can manage quizzes"
DROP POLICY IF EXISTS "Admin can manage quizzes" ON book_quizzes;

CREATE POLICY "Admin can manage quizzes" ON book_quizzes
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'head'))
  );

-- 3b. book_quiz_questions: "Admin can manage quiz questions"
DROP POLICY IF EXISTS "Admin can manage quiz questions" ON book_quiz_questions;

CREATE POLICY "Admin can manage quiz questions" ON book_quiz_questions
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'head'))
  );

-- 3c. book_quiz_results: "Teachers can read student quiz results"
DROP POLICY IF EXISTS "Teachers can read student quiz results" ON book_quiz_results;

CREATE POLICY "Teachers can read student quiz results" ON book_quiz_results
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM profiles teacher
      WHERE teacher.id = auth.uid()
      AND teacher.role IN ('teacher', 'head', 'admin')
      AND teacher.school_id = (SELECT school_id FROM profiles WHERE id = book_quiz_results.user_id)
    )
  );

-- 3d. Fix RPC function: get_student_quiz_results
-- Was using 'head_teacher' in authorization check
CREATE OR REPLACE FUNCTION get_student_quiz_results(p_student_id UUID)
RETURNS TABLE (
    book_id UUID,
    book_title TEXT,
    quiz_title TEXT,
    best_score DECIMAL,
    max_score DECIMAL,
    best_percentage DECIMAL,
    is_passing BOOLEAN,
    total_attempts BIGINT,
    first_attempt_at TIMESTAMPTZ,
    best_attempt_at TIMESTAMPTZ
) AS $$
DECLARE
    v_caller_school UUID;
    v_student_school UUID;
BEGIN
    -- Authorization: caller must be teacher/head/admin in same school
    SELECT p.school_id INTO v_caller_school
    FROM profiles p
    WHERE p.id = auth.uid() AND p.role IN ('teacher', 'head', 'admin');

    SELECT p.school_id INTO v_student_school
    FROM profiles p
    WHERE p.id = p_student_id AND p.role = 'student';

    IF v_caller_school IS NULL OR v_student_school IS NULL OR v_caller_school != v_student_school THEN
        RETURN;
    END IF;

    RETURN QUERY
    WITH best_results AS (
        SELECT DISTINCT ON (bqr.book_id)
            bqr.book_id,
            bqr.score AS best_score,
            bqr.max_score,
            bqr.percentage AS best_percentage,
            bqr.completed_at AS best_attempt_at
        FROM book_quiz_results bqr
        WHERE bqr.user_id = p_student_id
        ORDER BY bqr.book_id, bqr.percentage DESC
    ),
    attempt_counts AS (
        SELECT
            bqr.book_id,
            COUNT(*) AS total_attempts,
            MIN(bqr.completed_at) AS first_attempt_at
        FROM book_quiz_results bqr
        WHERE bqr.user_id = p_student_id
        GROUP BY bqr.book_id
    )
    SELECT
        br.book_id,
        b.title::TEXT AS book_title,
        bq.title::TEXT AS quiz_title,
        br.best_score,
        br.max_score,
        br.best_percentage,
        br.best_percentage >= bq.passing_score AS is_passing,
        ac.total_attempts,
        ac.first_attempt_at,
        br.best_attempt_at
    FROM best_results br
    JOIN books b ON b.id = br.book_id
    JOIN book_quizzes bq ON bq.book_id = br.book_id
    JOIN attempt_counts ac ON ac.book_id = br.book_id
    ORDER BY br.best_attempt_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_student_quiz_results(UUID) TO authenticated;

-- 3e. Fix RPC function: get_student_vocab_stats
-- Was using 'head_teacher' in authorization check
CREATE OR REPLACE FUNCTION get_student_vocab_stats(p_student_id UUID)
RETURNS TABLE (
  total_words BIGINT,
  new_count BIGINT,
  learning_count BIGINT,
  reviewing_count BIGINT,
  mastered_count BIGINT,
  lists_started BIGINT,
  lists_completed BIGINT,
  total_sessions BIGINT
) AS $$
DECLARE
  v_caller_school UUID;
  v_student_school UUID;
BEGIN
  -- Authorization: caller must be teacher/head/admin in same school
  SELECT school_id INTO v_caller_school
  FROM profiles
  WHERE id = auth.uid() AND role IN ('teacher', 'head', 'admin');

  SELECT school_id INTO v_student_school
  FROM profiles
  WHERE id = p_student_id AND role = 'student';

  IF v_caller_school IS NULL OR v_student_school IS NULL OR v_caller_school != v_student_school THEN
    RETURN QUERY SELECT 0::BIGINT, 0::BIGINT, 0::BIGINT, 0::BIGINT, 0::BIGINT, 0::BIGINT, 0::BIGINT, 0::BIGINT;
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    COALESCE((SELECT COUNT(*) FROM vocabulary_progress vp WHERE vp.user_id = p_student_id), 0) as total_words,
    COALESCE((SELECT COUNT(*) FROM vocabulary_progress vp WHERE vp.user_id = p_student_id AND vp.status = 'new_word'), 0) as new_count,
    COALESCE((SELECT COUNT(*) FROM vocabulary_progress vp WHERE vp.user_id = p_student_id AND vp.status = 'learning'), 0) as learning_count,
    COALESCE((SELECT COUNT(*) FROM vocabulary_progress vp WHERE vp.user_id = p_student_id AND vp.status = 'reviewing'), 0) as reviewing_count,
    COALESCE((SELECT COUNT(*) FROM vocabulary_progress vp WHERE vp.user_id = p_student_id AND vp.status = 'mastered'), 0) as mastered_count,
    COALESCE((SELECT COUNT(*) FROM user_word_list_progress wlp WHERE wlp.user_id = p_student_id AND wlp.started_at IS NOT NULL), 0) as lists_started,
    COALESCE((SELECT COUNT(*) FROM user_word_list_progress wlp WHERE wlp.user_id = p_student_id AND wlp.completed_at IS NOT NULL), 0) as lists_completed,
    COALESCE((SELECT SUM(wlp.total_sessions) FROM user_word_list_progress wlp WHERE wlp.user_id = p_student_id), 0) as total_sessions;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_student_vocab_stats(UUID) TO authenticated;

-- 3f. Fix RPC function: get_student_word_list_progress
-- Was using 'head_teacher' in authorization check
CREATE OR REPLACE FUNCTION get_student_word_list_progress(p_student_id UUID)
RETURNS TABLE (
  word_list_id UUID,
  word_list_name TEXT,
  word_list_level TEXT,
  word_list_category TEXT,
  word_count INT,
  best_score INT,
  best_accuracy NUMERIC,
  total_sessions INT,
  last_session_at TIMESTAMPTZ,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ
) AS $$
DECLARE
  v_caller_school UUID;
  v_student_school UUID;
BEGIN
  -- Authorization: caller must be teacher/head/admin in same school
  SELECT school_id INTO v_caller_school
  FROM profiles
  WHERE id = auth.uid() AND role IN ('teacher', 'head', 'admin');

  SELECT school_id INTO v_student_school
  FROM profiles
  WHERE id = p_student_id AND role = 'student';

  IF v_caller_school IS NULL OR v_student_school IS NULL OR v_caller_school != v_student_school THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    wl.id as word_list_id,
    wl.name::TEXT as word_list_name,
    wl.level::TEXT as word_list_level,
    wl.category::TEXT as word_list_category,
    wl.word_count,
    wlp.best_score,
    wlp.best_accuracy,
    wlp.total_sessions,
    wlp.last_session_at,
    wlp.started_at,
    wlp.completed_at
  FROM user_word_list_progress wlp
  JOIN word_lists wl ON wl.id = wlp.word_list_id
  WHERE wlp.user_id = p_student_id
  ORDER BY wlp.last_session_at DESC NULLS LAST;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_student_word_list_progress(UUID) TO authenticated;
