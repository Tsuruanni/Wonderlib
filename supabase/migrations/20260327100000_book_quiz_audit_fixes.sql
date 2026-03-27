-- Book Quiz Audit Fixes
-- Fixes: #2 (get_best_book_quiz_result missing auth), #3 (book_has_quiz 0-question check), #13 (composite index)

-- =============================================
-- FIX #3: book_has_quiz must require at least one question
-- A published quiz with 0 questions should not gate book completion
-- =============================================
CREATE OR REPLACE FUNCTION book_has_quiz(p_book_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM book_quizzes bq
        WHERE bq.book_id = p_book_id
        AND bq.is_published = true
        AND EXISTS (
            SELECT 1 FROM book_quiz_questions bqq
            WHERE bqq.quiz_id = bq.id
        )
    );
END;
$$ LANGUAGE plpgsql STABLE;

-- =============================================
-- FIX #2: get_best_book_quiz_result must enforce authorization
-- Caller must be the user themselves, or a teacher/admin/head in the same school
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
DECLARE
    v_caller_id UUID;
    v_caller_role TEXT;
    v_caller_school UUID;
    v_target_school UUID;
BEGIN
    v_caller_id := auth.uid();

    -- Allow users to query their own results
    IF v_caller_id = p_user_id THEN
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
        RETURN;
    END IF;

    -- For other users: caller must be teacher/admin/head in same school
    SELECT p.role, p.school_id INTO v_caller_role, v_caller_school
    FROM profiles p
    WHERE p.id = v_caller_id;

    IF v_caller_role NOT IN ('teacher', 'head', 'admin') THEN
        RETURN;
    END IF;

    SELECT p.school_id INTO v_target_school
    FROM profiles p
    WHERE p.id = p_user_id;

    IF v_caller_school IS NULL OR v_target_school IS NULL OR v_caller_school != v_target_school THEN
        RETURN;
    END IF;

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

-- =============================================
-- FIX #13: Add composite index for (user_id, book_id) queries
-- Used by getUserQuizResults and get_best_book_quiz_result
-- =============================================
CREATE INDEX IF NOT EXISTS idx_book_quiz_results_user_book
    ON book_quiz_results(user_id, book_id);
