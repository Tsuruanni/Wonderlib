-- Add CHECK constraint to vocabulary_progress.status
-- Enforces valid status values at the database level
-- Valid values: new_word, learning, reviewing, mastered

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'vocabulary_progress_status_check'
    ) THEN
        ALTER TABLE vocabulary_progress
            ADD CONSTRAINT vocabulary_progress_status_check
            CHECK (status IN ('new_word', 'learning', 'reviewing', 'mastered'));
    END IF;
END $$;
