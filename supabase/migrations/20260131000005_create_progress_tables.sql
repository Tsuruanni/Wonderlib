-- Migration 5: Progress Tables
-- ReadEng (Wonderlib) Database Schema

-- =============================================
-- READING PROGRESS
-- =============================================
CREATE TABLE reading_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    chapter_id UUID REFERENCES chapters(id) ON DELETE SET NULL,
    current_page INTEGER DEFAULT 1,
    is_completed BOOLEAN DEFAULT FALSE,
    completion_percentage DECIMAL(5,2) DEFAULT 0,
    total_reading_time INTEGER DEFAULT 0,  -- in seconds
    completed_chapter_ids UUID[] DEFAULT '{}',
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(user_id, book_id)
);

COMMENT ON TABLE reading_progress IS 'User reading progress per book';
COMMENT ON COLUMN reading_progress.total_reading_time IS 'Total time spent reading in seconds';
COMMENT ON COLUMN reading_progress.completed_chapter_ids IS 'Array of completed chapter UUIDs';

-- =============================================
-- ACTIVITY RESULTS
-- =============================================
CREATE TABLE activity_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    activity_id UUID NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
    score DECIMAL(5,2) NOT NULL,
    max_score DECIMAL(5,2) NOT NULL,
    answers JSONB NOT NULL,
    time_spent INTEGER,  -- in seconds
    attempt_number INTEGER DEFAULT 1,
    completed_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE activity_results IS 'Results of end-of-chapter activities';

-- =============================================
-- INLINE ACTIVITY RESULTS
-- =============================================
CREATE TABLE inline_activity_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    inline_activity_id UUID NOT NULL REFERENCES inline_activities(id) ON DELETE CASCADE,
    is_correct BOOLEAN NOT NULL,
    xp_earned INTEGER DEFAULT 0,
    words_learned TEXT[] DEFAULT '{}',
    answered_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(user_id, inline_activity_id)
);

COMMENT ON TABLE inline_activity_results IS 'Results of inline microlearning activities';

-- =============================================
-- VOCABULARY PROGRESS (Spaced Repetition SM-2)
-- =============================================
CREATE TABLE vocabulary_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    word_id UUID NOT NULL REFERENCES vocabulary_words(id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'new_word'
        CHECK (status IN ('new_word', 'learning', 'reviewing', 'mastered')),
    ease_factor DECIMAL(4,2) DEFAULT 2.50,
    interval_days INTEGER DEFAULT 0,
    repetitions INTEGER DEFAULT 0,
    next_review_at TIMESTAMPTZ,
    last_reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(user_id, word_id)
);

COMMENT ON TABLE vocabulary_progress IS 'SM-2 spaced repetition progress per word per user';
COMMENT ON COLUMN vocabulary_progress.ease_factor IS 'SM-2 ease factor (1.3 - 2.5+)';
COMMENT ON COLUMN vocabulary_progress.interval_days IS 'Days until next review';
