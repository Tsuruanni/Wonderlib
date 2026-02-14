-- RPC functions for book quiz system

-- =============================================
-- CHECK IF BOOK HAS A PUBLISHED QUIZ
-- =============================================
CREATE OR REPLACE FUNCTION book_has_quiz(p_book_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM book_quizzes
        WHERE book_id = p_book_id
        AND is_published = true
    );
END;
$$ LANGUAGE plpgsql STABLE;

GRANT EXECUTE ON FUNCTION book_has_quiz(UUID) TO authenticated;

-- =============================================
-- GET BEST QUIZ RESULT FOR USER+BOOK
-- =============================================
CREATE OR REPLACE FUNCTION get_best_book_quiz_result(
    p_user_id UUID,
    p_book_id UUID
)
RETURNS TABLE (
    result_id UUID,
    quiz_id UUID,
    score DECIMAL,
    max_score DECIMAL,
    percentage DECIMAL,
    is_passing BOOLEAN,
    attempt_number INTEGER,
    time_spent INTEGER,
    completed_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        bqr.id,
        bqr.quiz_id,
        bqr.score,
        bqr.max_score,
        bqr.percentage,
        bqr.is_passing,
        bqr.attempt_number,
        bqr.time_spent,
        bqr.completed_at
    FROM book_quiz_results bqr
    WHERE bqr.user_id = p_user_id
    AND bqr.book_id = p_book_id
    ORDER BY bqr.percentage DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_best_book_quiz_result(UUID, UUID) TO authenticated;

-- =============================================
-- GET STUDENT QUIZ RESULTS (for teacher reporting)
-- Returns best result per book for a student
-- Authorization: caller must be teacher/head/admin in same school
-- =============================================
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
    WHERE p.id = auth.uid() AND p.role IN ('teacher', 'head_teacher', 'admin');

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
