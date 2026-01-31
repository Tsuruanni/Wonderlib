-- Migration 3: Content Tables (books, chapters, activities, vocabulary)
-- ReadEng (Wonderlib) Database Schema

-- =============================================
-- BOOKS
-- =============================================
CREATE TABLE books (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    cover_url VARCHAR(500),
    level VARCHAR(10) NOT NULL
        CHECK (level IN ('A1', 'A2', 'B1', 'B2', 'C1', 'C2')),
    genre VARCHAR(50),
    age_group VARCHAR(20)
        CHECK (age_group IS NULL OR age_group IN ('elementary', 'middle', 'high')),
    estimated_minutes INTEGER,
    word_count INTEGER,
    chapter_count INTEGER DEFAULT 0,
    status VARCHAR(20) DEFAULT 'draft'
        CHECK (status IN ('draft', 'published', 'archived')),
    metadata JSONB DEFAULT '{}',
    published_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE books IS 'Books/stories available for reading';
COMMENT ON COLUMN books.level IS 'CEFR language proficiency level';
COMMENT ON COLUMN books.metadata IS 'Flexible metadata: author, year, tags, etc.';

-- =============================================
-- CHAPTERS
-- =============================================
CREATE TABLE chapters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    order_index INTEGER NOT NULL,
    content TEXT,
    audio_url VARCHAR(500),
    image_urls JSONB DEFAULT '[]',
    word_count INTEGER,
    estimated_minutes INTEGER,
    -- Embedded vocabulary with position info
    vocabulary JSONB DEFAULT '[]',
    -- Format: [{"word": "magnificent", "meaning": "...", "phonetic": "...", "startIndex": 10, "endIndex": 21}]
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(book_id, order_index)
);

COMMENT ON TABLE chapters IS 'Chapters within books';
COMMENT ON COLUMN chapters.vocabulary IS 'Embedded vocabulary words with positions in content';

-- =============================================
-- ACTIVITIES (End-of-chapter)
-- =============================================
CREATE TABLE activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chapter_id UUID NOT NULL REFERENCES chapters(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL
        CHECK (type IN ('multiple_choice', 'true_false', 'matching',
                        'ordering', 'fill_blank', 'short_answer')),
    order_index INTEGER NOT NULL,
    title VARCHAR(255),
    instructions TEXT,
    questions JSONB NOT NULL DEFAULT '[]',
    -- Format: [{"id": "q1", "question": "...", "options": [...], "correctAnswer": "...", "points": 2}]
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE activities IS 'End-of-chapter quiz activities';

-- =============================================
-- INLINE ACTIVITIES (Microlearning during reading)
-- =============================================
CREATE TABLE inline_activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chapter_id UUID NOT NULL REFERENCES chapters(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL
        CHECK (type IN ('true_false', 'word_translation', 'find_words')),
    after_paragraph_index INTEGER NOT NULL,
    content JSONB NOT NULL,
    -- true_false: {"statement": "...", "correctAnswer": true}
    -- word_translation: {"word": "...", "correctAnswer": "...", "options": [...]}
    -- find_words: {"instruction": "...", "options": [...], "correctAnswers": [...]}
    xp_reward INTEGER DEFAULT 5,
    vocabulary_words TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE inline_activities IS 'Microlearning activities during reading';

-- =============================================
-- VOCABULARY WORDS
-- =============================================
CREATE TABLE vocabulary_words (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    word VARCHAR(100) NOT NULL,
    phonetic VARCHAR(100),
    meaning_tr TEXT NOT NULL,
    meaning_en TEXT,
    example_sentences TEXT[] DEFAULT '{}',
    audio_url VARCHAR(500),
    image_url VARCHAR(500),
    level VARCHAR(10)
        CHECK (level IS NULL OR level IN ('A1', 'A2', 'B1', 'B2', 'C1', 'C2')),
    categories TEXT[] DEFAULT '{}',
    synonyms TEXT[] DEFAULT '{}',
    antonyms TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),

    -- Ensure unique word per level for deduplication
    UNIQUE(word, level)
);

COMMENT ON TABLE vocabulary_words IS 'Master vocabulary word dictionary';
COMMENT ON COLUMN vocabulary_words.example_sentences IS 'Up to 2 example sentences';

-- Chapter-Word junction for content vocabulary (optional, for advanced queries)
CREATE TABLE chapter_vocabulary (
    chapter_id UUID REFERENCES chapters(id) ON DELETE CASCADE,
    word_id UUID REFERENCES vocabulary_words(id) ON DELETE CASCADE,
    PRIMARY KEY (chapter_id, word_id)
);

COMMENT ON TABLE chapter_vocabulary IS 'Junction table linking chapters to vocabulary words';
