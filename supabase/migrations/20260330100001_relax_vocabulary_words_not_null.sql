-- Allow meaning_tr to be nullable so words can be created with just the word
-- and filled in later via AI or manual editing
ALTER TABLE vocabulary_words ALTER COLUMN meaning_tr DROP NOT NULL;
