-- Migration 4: Word List Tables
-- ReadEng (Wonderlib) Database Schema

-- =============================================
-- WORD LISTS
-- =============================================
CREATE TABLE word_lists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    level VARCHAR(10)
        CHECK (level IS NULL OR level IN ('A1', 'A2', 'B1', 'B2', 'C1', 'C2')),
    category VARCHAR(50) NOT NULL
        CHECK (category IN ('common_words', 'grade_level', 'test_prep', 'thematic', 'story_vocab')),
    word_count INTEGER DEFAULT 0,
    cover_image_url VARCHAR(500),
    is_system BOOLEAN DEFAULT TRUE,
    source_book_id UUID REFERENCES books(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE word_lists IS 'Collections of vocabulary words for study';
COMMENT ON COLUMN word_lists.is_system IS 'True = admin created, False = user/story created';
COMMENT ON COLUMN word_lists.source_book_id IS 'For story vocabulary lists, links to source book';

-- =============================================
-- WORD LIST ITEMS (Junction table)
-- =============================================
CREATE TABLE word_list_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    word_list_id UUID NOT NULL REFERENCES word_lists(id) ON DELETE CASCADE,
    word_id UUID NOT NULL REFERENCES vocabulary_words(id) ON DELETE CASCADE,
    order_index INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(word_list_id, word_id)
);

COMMENT ON TABLE word_list_items IS 'Many-to-many relationship between word lists and vocabulary words';

-- =============================================
-- USER WORD LIST PROGRESS
-- =============================================
CREATE TABLE user_word_list_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    word_list_id UUID NOT NULL REFERENCES word_lists(id) ON DELETE CASCADE,
    phase1_complete BOOLEAN DEFAULT FALSE,
    phase2_complete BOOLEAN DEFAULT FALSE,
    phase3_complete BOOLEAN DEFAULT FALSE,
    phase4_complete BOOLEAN DEFAULT FALSE,
    phase4_score INTEGER,
    phase4_total INTEGER,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(user_id, word_list_id)
);

COMMENT ON TABLE user_word_list_progress IS '4-phase vocabulary learning progress per user per list';
COMMENT ON COLUMN user_word_list_progress.phase1_complete IS 'Phase 1: Learn Vocabulary';
COMMENT ON COLUMN user_word_list_progress.phase2_complete IS 'Phase 2: Spelling Practice';
COMMENT ON COLUMN user_word_list_progress.phase3_complete IS 'Phase 3: Flashcard Review';
COMMENT ON COLUMN user_word_list_progress.phase4_complete IS 'Phase 4: Final Assessment';

-- Trigger to update word_count on word_list_items changes
CREATE OR REPLACE FUNCTION update_word_list_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE word_lists
        SET word_count = word_count + 1, updated_at = NOW()
        WHERE id = NEW.word_list_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE word_lists
        SET word_count = GREATEST(word_count - 1, 0), updated_at = NOW()
        WHERE id = OLD.word_list_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_word_list_count_trigger
    AFTER INSERT OR DELETE ON word_list_items
    FOR EACH ROW EXECUTE FUNCTION update_word_list_count();
