-- Migration: Book Final Quiz System
-- Adds quiz tables for end-of-book reading comprehension quizzes

-- =============================================
-- BOOK QUIZZES (one per book)
-- =============================================
CREATE TABLE book_quizzes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL DEFAULT 'Final Quiz',
    instructions TEXT,
    passing_score DECIMAL(5,2) NOT NULL DEFAULT 70.00,
    total_points INTEGER NOT NULL DEFAULT 10,
    is_published BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(book_id)
);

COMMENT ON TABLE book_quizzes IS 'End-of-book reading comprehension quizzes';
COMMENT ON COLUMN book_quizzes.passing_score IS 'Minimum percentage to mark book as completed (default 70%)';

-- =============================================
-- BOOK QUIZ QUESTIONS (polymorphic via JSONB)
-- =============================================
CREATE TABLE book_quiz_questions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quiz_id UUID NOT NULL REFERENCES book_quizzes(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL
        CHECK (type IN ('multiple_choice', 'fill_blank', 'event_sequencing',
                        'matching', 'who_says_what')),
    order_index INTEGER NOT NULL,
    question TEXT NOT NULL,
    -- Polymorphic content stored as JSONB, format depends on type:
    -- multiple_choice:   {"options": ["A","B","C","D"], "correct_answer": "B"}
    -- fill_blank:        {"sentence": "The ___ ran away.", "correct_answer": "fox", "accept_alternatives": ["Fox"]}
    -- event_sequencing:  {"events": ["First","Second","Third"], "correct_order": [0,1,2]}
    -- matching:          {"left": ["item1","item2"], "right": ["match1","match2"], "correct_pairs": {"0":"1","1":"0"}}
    -- who_says_what:     {"characters": ["Alice","Bob"], "quotes": ["Hello","Bye"], "correct_pairs": {"0":"0","1":"1"}}
    content JSONB NOT NULL,
    explanation TEXT,
    points INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(quiz_id, order_index)
);

COMMENT ON TABLE book_quiz_questions IS 'Questions within a book quiz';
COMMENT ON COLUMN book_quiz_questions.content IS 'Polymorphic question content, format varies by type';

-- =============================================
-- BOOK QUIZ RESULTS (multiple attempts allowed)
-- =============================================
CREATE TABLE book_quiz_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    quiz_id UUID NOT NULL REFERENCES book_quizzes(id) ON DELETE CASCADE,
    book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    score DECIMAL(5,2) NOT NULL,
    max_score DECIMAL(5,2) NOT NULL,
    percentage DECIMAL(5,2) NOT NULL,
    is_passing BOOLEAN NOT NULL,
    -- Format: {"question_id": {"answer": ..., "is_correct": true, "points_earned": 1}}
    answers JSONB NOT NULL,
    time_spent INTEGER, -- in seconds
    attempt_number INTEGER NOT NULL DEFAULT 1,
    completed_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE book_quiz_results IS 'Student quiz attempt results. Multiple attempts allowed, best score counts.';

-- =============================================
-- INDEXES
-- =============================================
CREATE INDEX idx_book_quiz_results_user ON book_quiz_results(user_id);
CREATE INDEX idx_book_quiz_results_book ON book_quiz_results(book_id);
CREATE INDEX idx_book_quiz_results_user_quiz ON book_quiz_results(user_id, quiz_id);
CREATE INDEX idx_book_quiz_questions_quiz ON book_quiz_questions(quiz_id);

-- =============================================
-- ROW LEVEL SECURITY
-- =============================================
ALTER TABLE book_quizzes ENABLE ROW LEVEL SECURITY;
ALTER TABLE book_quiz_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE book_quiz_results ENABLE ROW LEVEL SECURITY;

-- Quizzes: everyone can read published, admin can manage
CREATE POLICY "Anyone can read published quizzes" ON book_quizzes
    FOR SELECT USING (is_published = true);

CREATE POLICY "Admin can manage quizzes" ON book_quizzes
    FOR ALL USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'head_teacher'))
    );

-- Questions: visible if quiz is published or user is admin
CREATE POLICY "Anyone can read published quiz questions" ON book_quiz_questions
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM book_quizzes WHERE id = quiz_id AND is_published = true)
    );

CREATE POLICY "Admin can manage quiz questions" ON book_quiz_questions
    FOR ALL USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'head_teacher'))
    );

-- Results: users see own, teachers see students in same school
CREATE POLICY "Users can read own quiz results" ON book_quiz_results
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can insert own quiz results" ON book_quiz_results
    FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Teachers can read student quiz results" ON book_quiz_results
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM profiles teacher
            WHERE teacher.id = auth.uid()
            AND teacher.role IN ('teacher', 'head_teacher', 'admin')
            AND teacher.school_id = (SELECT school_id FROM profiles WHERE id = book_quiz_results.user_id)
        )
    );
