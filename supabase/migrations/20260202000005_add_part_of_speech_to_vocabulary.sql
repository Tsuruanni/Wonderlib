-- Migration: Add part_of_speech column to vocabulary_words
-- For word-tap feature - shows word type (noun, verb, etc.) in popup

-- Add part_of_speech column with CHECK constraint
ALTER TABLE vocabulary_words
ADD COLUMN part_of_speech VARCHAR(20)
CHECK (part_of_speech IS NULL OR part_of_speech IN (
  'noun', 'verb', 'adjective', 'adverb',
  'preposition', 'conjunction', 'pronoun',
  'interjection', 'determiner', 'article'
));

COMMENT ON COLUMN vocabulary_words.part_of_speech IS 'Part of speech: noun, verb, adjective, etc.';

-- Add index on word column for fast lookups
CREATE INDEX IF NOT EXISTS idx_vocabulary_words_word_lower
ON vocabulary_words (LOWER(word));
