-- Migration: Multi-meaning vocabulary support
-- Allows same word to have multiple meanings from different books

-- 1. Drop existing constraint (word + level uniqueness)
ALTER TABLE vocabulary_words DROP CONSTRAINT IF EXISTS vocabulary_words_word_level_key;

-- 2. Add source_book_id column to track which book the meaning came from
ALTER TABLE vocabulary_words
ADD COLUMN IF NOT EXISTS source_book_id UUID REFERENCES books(id) ON DELETE SET NULL;

-- 3. Add part_of_speech column if missing (for extracted vocabulary)
ALTER TABLE vocabulary_words
ADD COLUMN IF NOT EXISTS part_of_speech VARCHAR(20);

-- 4. Add new unique constraint: same word can have different meanings, but not duplicate meanings
-- Using (word, meaning_tr) ensures:
--   - "bank" with meaning "kıyı" from Book A → OK
--   - "bank" with meaning "banka" from Book B → OK (different meaning)
--   - "bank" with meaning "kıyı" from Book B → SKIP (same meaning already exists)
ALTER TABLE vocabulary_words
ADD CONSTRAINT vocabulary_words_word_meaning_unique
UNIQUE (word, meaning_tr);

-- 5. Create index for book-based queries
CREATE INDEX IF NOT EXISTS idx_vocabulary_words_source_book
ON vocabulary_words(source_book_id);

-- 6. Create index for word lookups (already exists but ensure it)
CREATE INDEX IF NOT EXISTS idx_vocabulary_words_word
ON vocabulary_words(word);

COMMENT ON COLUMN vocabulary_words.source_book_id IS 'Book from which this meaning was extracted';
COMMENT ON COLUMN vocabulary_words.part_of_speech IS 'Part of speech: noun, verb, adjective, etc.';
