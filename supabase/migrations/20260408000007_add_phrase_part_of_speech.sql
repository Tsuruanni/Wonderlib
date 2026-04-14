-- Add 'phrase' to part_of_speech CHECK constraint for multi-word vocabulary entries
ALTER TABLE vocabulary_words
DROP CONSTRAINT vocabulary_words_part_of_speech_check;

ALTER TABLE vocabulary_words
ADD CONSTRAINT vocabulary_words_part_of_speech_check
CHECK (part_of_speech IS NULL OR part_of_speech IN (
  'noun', 'verb', 'adjective', 'adverb',
  'preposition', 'conjunction', 'pronoun',
  'interjection', 'determiner', 'article', 'phrase'
));
