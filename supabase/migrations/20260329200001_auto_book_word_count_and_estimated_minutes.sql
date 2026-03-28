-- =============================================
-- AUTO-CALCULATE book word_count, estimated_minutes, and chapter_count
-- from chapter data on every chapter INSERT/UPDATE/DELETE.
-- Also one-time fix for all existing books.
-- =============================================

-- Replace the old chapter_count-only trigger with a comprehensive one
-- that recalculates word_count, estimated_minutes, AND chapter_count.
DROP TRIGGER IF EXISTS update_chapter_count_trigger ON chapters;

CREATE OR REPLACE FUNCTION recalculate_book_stats()
RETURNS TRIGGER AS $$
DECLARE
  target_book_id UUID;
  total_words INT;
  total_chapters INT;
BEGIN
  -- Determine which book to update
  IF TG_OP = 'DELETE' THEN
    target_book_id := OLD.book_id;
  ELSE
    target_book_id := NEW.book_id;
  END IF;

  -- Recalculate from all chapters of this book
  SELECT
    COALESCE(COUNT(*), 0),
    COALESCE(SUM(word_count), 0)
  INTO total_chapters, total_words
  FROM chapters
  WHERE book_id = target_book_id;

  -- Update the book: word_count, estimated_minutes (150 wpm for ESL readers), chapter_count
  UPDATE books
  SET
    word_count = total_words,
    estimated_minutes = CASE WHEN total_words > 0 THEN GREATEST(CEIL(total_words / 150.0), 1) ELSE NULL END,
    chapter_count = total_chapters
  WHERE id = target_book_id;

  -- Handle book_id change (chapter moved to different book)
  IF TG_OP = 'UPDATE' AND OLD.book_id IS DISTINCT FROM NEW.book_id THEN
    SELECT
      COALESCE(COUNT(*), 0),
      COALESCE(SUM(word_count), 0)
    INTO total_chapters, total_words
    FROM chapters
    WHERE book_id = OLD.book_id;

    UPDATE books
    SET
      word_count = total_words,
      estimated_minutes = CASE WHEN total_words > 0 THEN GREATEST(CEIL(total_words / 150.0), 1) ELSE NULL END,
      chapter_count = total_chapters
    WHERE id = OLD.book_id;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER recalculate_book_stats_trigger
    AFTER INSERT OR UPDATE OR DELETE ON chapters
    FOR EACH ROW EXECUTE FUNCTION recalculate_book_stats();

-- =============================================
-- ONE-TIME FIX: Recalculate all existing books
-- =============================================
UPDATE books b
SET
  word_count = sub.total_words,
  estimated_minutes = CASE WHEN sub.total_words > 0 THEN GREATEST(CEIL(sub.total_words / 150.0), 1) ELSE NULL END,
  chapter_count = sub.total_chapters
FROM (
  SELECT
    book_id,
    COUNT(*) AS total_chapters,
    COALESCE(SUM(word_count), 0) AS total_words
  FROM chapters
  GROUP BY book_id
) sub
WHERE b.id = sub.book_id;
