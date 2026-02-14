-- Add Lexile score to books table
-- Lexile scores typically range from 0L to 2000L
ALTER TABLE books ADD COLUMN lexile_score INTEGER;
