-- Migration: Teacher Student Vocabulary Visibility
-- Adds RPC functions for teachers to view student vocabulary progress

-- =============================================
-- 1. GET STUDENT VOCAB STATS (summary counts)
-- =============================================
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
  WHERE id = auth.uid() AND role IN ('teacher', 'head_teacher', 'admin');

  SELECT school_id INTO v_student_school
  FROM profiles
  WHERE id = p_student_id AND role = 'student';

  IF v_caller_school IS NULL OR v_student_school IS NULL OR v_caller_school != v_student_school THEN
    RETURN QUERY SELECT 0::BIGINT, 0::BIGINT, 0::BIGINT, 0::BIGINT, 0::BIGINT, 0::BIGINT, 0::BIGINT, 0::BIGINT;
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    -- Word-level stats from vocabulary_progress
    COALESCE((SELECT COUNT(*) FROM vocabulary_progress vp WHERE vp.user_id = p_student_id), 0) as total_words,
    COALESCE((SELECT COUNT(*) FROM vocabulary_progress vp WHERE vp.user_id = p_student_id AND vp.status = 'new_word'), 0) as new_count,
    COALESCE((SELECT COUNT(*) FROM vocabulary_progress vp WHERE vp.user_id = p_student_id AND vp.status = 'learning'), 0) as learning_count,
    COALESCE((SELECT COUNT(*) FROM vocabulary_progress vp WHERE vp.user_id = p_student_id AND vp.status = 'reviewing'), 0) as reviewing_count,
    COALESCE((SELECT COUNT(*) FROM vocabulary_progress vp WHERE vp.user_id = p_student_id AND vp.status = 'mastered'), 0) as mastered_count,
    -- List-level stats from user_word_list_progress
    COALESCE((SELECT COUNT(*) FROM user_word_list_progress wlp WHERE wlp.user_id = p_student_id AND wlp.started_at IS NOT NULL), 0) as lists_started,
    COALESCE((SELECT COUNT(*) FROM user_word_list_progress wlp WHERE wlp.user_id = p_student_id AND wlp.completed_at IS NOT NULL), 0) as lists_completed,
    COALESCE((SELECT SUM(wlp.total_sessions) FROM user_word_list_progress wlp WHERE wlp.user_id = p_student_id), 0) as total_sessions;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_student_vocab_stats(UUID) TO authenticated;

COMMENT ON FUNCTION get_student_vocab_stats IS
  'Returns student vocabulary summary stats. Authorization: caller must be teacher/head/admin in same school.';

-- =============================================
-- 2. GET STUDENT WORD LIST PROGRESS (per-list)
-- =============================================
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
  WHERE id = auth.uid() AND role IN ('teacher', 'head_teacher', 'admin');

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

COMMENT ON FUNCTION get_student_word_list_progress IS
  'Returns student word list progress with list details. Authorization: caller must be teacher/head/admin in same school.';
