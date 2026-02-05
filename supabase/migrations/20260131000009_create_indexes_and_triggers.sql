-- Migration 9: Indexes and Triggers
-- ReadEng (Wonderlib) Database Schema

-- =============================================
-- INDEXES
-- =============================================

-- Profile indexes
CREATE INDEX idx_profiles_school ON profiles(school_id);
CREATE INDEX idx_profiles_class ON profiles(class_id);
CREATE INDEX idx_profiles_role ON profiles(role);
CREATE INDEX idx_profiles_xp ON profiles(xp DESC);

-- Book indexes
CREATE INDEX idx_books_level ON books(level);
CREATE INDEX idx_books_status ON books(status);
CREATE INDEX idx_books_genre ON books(genre);
CREATE INDEX idx_books_age_group ON books(age_group);

-- Content indexes
CREATE INDEX idx_chapters_book ON chapters(book_id);
CREATE INDEX idx_chapters_order ON chapters(book_id, order_index);
CREATE INDEX idx_activities_chapter ON activities(chapter_id);
CREATE INDEX idx_inline_activities_chapter ON inline_activities(chapter_id);

-- Vocabulary indexes
CREATE INDEX idx_vocabulary_level ON vocabulary_words(level);
CREATE INDEX idx_vocabulary_word ON vocabulary_words(word);
CREATE INDEX idx_vocabulary_word_trgm ON vocabulary_words USING gin(word gin_trgm_ops);

-- Word list indexes
CREATE INDEX idx_word_lists_category ON word_lists(category);
CREATE INDEX idx_word_lists_level ON word_lists(level);
CREATE INDEX idx_word_list_items_list ON word_list_items(word_list_id);

-- Progress indexes
CREATE INDEX idx_reading_progress_user ON reading_progress(user_id);
CREATE INDEX idx_reading_progress_book ON reading_progress(book_id);
CREATE INDEX idx_reading_progress_user_book ON reading_progress(user_id, book_id);
CREATE INDEX idx_activity_results_user ON activity_results(user_id);
CREATE INDEX idx_activity_results_activity ON activity_results(activity_id);
CREATE INDEX idx_vocabulary_progress_user ON vocabulary_progress(user_id);
CREATE INDEX idx_vocabulary_progress_review ON vocabulary_progress(user_id, next_review_at)
    WHERE status != 'mastered';

-- Gamification indexes
CREATE INDEX idx_xp_logs_user ON xp_logs(user_id);
CREATE INDEX idx_xp_logs_created ON xp_logs(created_at DESC);
CREATE INDEX idx_user_badges_user ON user_badges(user_id);

-- Assignment indexes
CREATE INDEX idx_assignments_teacher ON assignments(teacher_id);
CREATE INDEX idx_assignments_class ON assignments(class_id);
CREATE INDEX idx_assignments_due ON assignments(due_date);
CREATE INDEX idx_assignment_students_student ON assignment_students(student_id);
CREATE INDEX idx_assignment_students_status ON assignment_students(status);

-- =============================================
-- FULL-TEXT SEARCH
-- =============================================

-- Books full-text search
ALTER TABLE books ADD COLUMN IF NOT EXISTS fts tsvector
    GENERATED ALWAYS AS (
        setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(description, '')), 'B')
    ) STORED;

CREATE INDEX idx_books_fts ON books USING GIN(fts);

-- Vocabulary full-text search
ALTER TABLE vocabulary_words ADD COLUMN IF NOT EXISTS fts tsvector
    GENERATED ALWAYS AS (
        setweight(to_tsvector('english', coalesce(word, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(meaning_en, '')), 'B')
    ) STORED;

CREATE INDEX idx_vocabulary_fts ON vocabulary_words USING GIN(fts);

-- =============================================
-- AUTO-UPDATE TIMESTAMPS
-- =============================================

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all tables with updated_at
CREATE TRIGGER update_schools_updated_at
    BEFORE UPDATE ON schools
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_classes_updated_at
    BEFORE UPDATE ON classes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_books_updated_at
    BEFORE UPDATE ON books
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_chapters_updated_at
    BEFORE UPDATE ON chapters
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_activities_updated_at
    BEFORE UPDATE ON activities
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_inline_activities_updated_at
    BEFORE UPDATE ON inline_activities
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_word_lists_updated_at
    BEFORE UPDATE ON word_lists
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_reading_progress_updated_at
    BEFORE UPDATE ON reading_progress
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_user_word_list_progress_updated_at
    BEFORE UPDATE ON user_word_list_progress
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_assignments_updated_at
    BEFORE UPDATE ON assignments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- =============================================
-- CHAPTER COUNT TRIGGER
-- =============================================

CREATE OR REPLACE FUNCTION update_book_chapter_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE books SET chapter_count = chapter_count + 1 WHERE id = NEW.book_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE books SET chapter_count = GREATEST(chapter_count - 1, 0) WHERE id = OLD.book_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_chapter_count_trigger
    AFTER INSERT OR DELETE ON chapters
    FOR EACH ROW EXECUTE FUNCTION update_book_chapter_count();
