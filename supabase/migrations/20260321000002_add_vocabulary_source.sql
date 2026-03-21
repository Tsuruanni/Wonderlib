-- Add source tracking for vocabulary words
ALTER TABLE vocabulary_words
ADD COLUMN source VARCHAR(20) DEFAULT 'manual';

COMMENT ON COLUMN vocabulary_words.source IS 'Origin of the word: manual, import, activity';
