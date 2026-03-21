-- Add audio segment columns to vocabulary_words for wordlist batch audio
ALTER TABLE vocabulary_words
  ADD COLUMN IF NOT EXISTS audio_start_ms INTEGER,
  ADD COLUMN IF NOT EXISTS audio_end_ms INTEGER;

COMMENT ON COLUMN vocabulary_words.audio_start_ms IS 'Start offset within the wordlist batch audio file (ms)';
COMMENT ON COLUMN vocabulary_words.audio_end_ms IS 'End offset within the wordlist batch audio file (ms)';
