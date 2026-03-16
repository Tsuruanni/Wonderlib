-- Add case-insensitive unique index for vocabulary_words
-- The existing UNIQUE(word, meaning_tr) is case-sensitive

-- Normalize existing data
UPDATE vocabulary_words SET word = LOWER(word) WHERE word != LOWER(word);

-- Drop the old case-sensitive constraint
DO $$
DECLARE
    v_constraint_name TEXT;
BEGIN
    SELECT conname INTO v_constraint_name
    FROM pg_constraint
    WHERE conrelid = 'vocabulary_words'::regclass
    AND contype = 'u'
    AND array_length(conkey, 1) = 2;

    IF v_constraint_name IS NOT NULL THEN
        EXECUTE format('ALTER TABLE vocabulary_words DROP CONSTRAINT %I', v_constraint_name);
    END IF;
END $$;

-- Create case-insensitive unique index
CREATE UNIQUE INDEX IF NOT EXISTS idx_vocabulary_words_word_meaning_ci
    ON vocabulary_words (LOWER(word), meaning_tr);
