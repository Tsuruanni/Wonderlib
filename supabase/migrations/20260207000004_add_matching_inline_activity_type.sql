-- Add 'matching' to the inline_activities type CHECK constraint
ALTER TABLE inline_activities
  DROP CONSTRAINT IF EXISTS inline_activities_type_check;

ALTER TABLE inline_activities
  ADD CONSTRAINT inline_activities_type_check
  CHECK (type IN ('true_false', 'word_translation', 'find_words', 'matching'));
