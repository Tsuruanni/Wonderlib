-- Add quiz_passed column to reading_progress
-- Book completion now requires: all chapters read + quiz passed (if quiz exists)
-- Books without quizzes maintain existing behavior (is_completed = all chapters read)

ALTER TABLE reading_progress
    ADD COLUMN quiz_passed BOOLEAN DEFAULT FALSE;

COMMENT ON COLUMN reading_progress.quiz_passed IS
    'Whether student passed the book final quiz. Required for completion if quiz exists.';
