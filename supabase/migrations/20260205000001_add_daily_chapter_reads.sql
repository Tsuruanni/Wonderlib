-- Migration: Add daily_chapter_reads table for tracking daily reading progress
-- This fixes the bug where getWordsReadTodayCount was counting ALL completed chapters
-- from books touched today, instead of just chapters completed today.

-- Minimal table: just track which chapters were read on which day
CREATE TABLE daily_chapter_reads (
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    chapter_id UUID NOT NULL REFERENCES chapters(id) ON DELETE CASCADE,
    read_date DATE NOT NULL DEFAULT CURRENT_DATE,
    PRIMARY KEY (user_id, chapter_id, read_date)
);

-- Note: CURRENT_DATE uses database server timezone (UTC on Supabase).
-- A user in Istanbul (UTC+3) reading at 11 PM local time will have it logged
-- as the next day (UTC). Acceptable for MVP.

-- RLS
ALTER TABLE daily_chapter_reads ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own reads" ON daily_chapter_reads
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own reads" ON daily_chapter_reads
    FOR INSERT WITH CHECK (auth.uid() = user_id);
