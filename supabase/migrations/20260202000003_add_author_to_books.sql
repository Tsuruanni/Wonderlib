-- Add author and cover_image_url columns to books table
-- The admin panel expects these column names

-- Add author column
ALTER TABLE books
    ADD COLUMN IF NOT EXISTS author VARCHAR(255);

-- Add cover_image_url column (admin panel uses this name instead of cover_url)
ALTER TABLE books
    ADD COLUMN IF NOT EXISTS cover_image_url VARCHAR(500);

-- Migrate existing data
UPDATE books
SET
    author = COALESCE(author, metadata->>'author'),
    cover_image_url = COALESCE(cover_image_url, cover_url)
WHERE metadata->>'author' IS NOT NULL OR cover_url IS NOT NULL;

COMMENT ON COLUMN books.author IS 'Book author name';
COMMENT ON COLUMN books.cover_image_url IS 'URL to book cover image';
