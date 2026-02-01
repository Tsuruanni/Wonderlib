-- Migration: Create content_blocks table for structured chapter content
-- ReadEng (Wonderlib) Database Schema
-- Purpose: Replace plain text chapter.content with structured blocks (text, image, audio, activity)

-- =============================================
-- CONTENT BLOCKS
-- =============================================
CREATE TABLE content_blocks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chapter_id UUID NOT NULL REFERENCES chapters(id) ON DELETE CASCADE,
    order_index INTEGER NOT NULL,
    type VARCHAR(20) NOT NULL
        CHECK (type IN ('text', 'image', 'audio', 'activity')),

    -- Text block fields
    text TEXT,
    audio_url VARCHAR(500),
    word_timings JSONB,
    -- Format: [{"word": "Hello", "startIndex": 0, "endIndex": 5, "startMs": 0, "endMs": 350}]

    -- Image block fields
    image_url VARCHAR(500),
    caption TEXT,

    -- Activity block fields (reference to inline_activities)
    activity_id UUID REFERENCES inline_activities(id) ON DELETE SET NULL,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Each block has unique position within chapter
    UNIQUE(chapter_id, order_index)
);

-- Index for efficient chapter content loading
CREATE INDEX idx_content_blocks_chapter ON content_blocks(chapter_id);
CREATE INDEX idx_content_blocks_chapter_order ON content_blocks(chapter_id, order_index);

COMMENT ON TABLE content_blocks IS 'Structured content blocks for chapters (replaces plain text content)';
COMMENT ON COLUMN content_blocks.type IS 'Block type: text (paragraph), image, audio (standalone), activity';
COMMENT ON COLUMN content_blocks.word_timings IS 'Word-level audio timestamps for synchronized highlighting';
COMMENT ON COLUMN content_blocks.activity_id IS 'Reference to inline_activity for activity blocks';

-- =============================================
-- UPDATE CHAPTERS TABLE
-- =============================================
-- Make content nullable for gradual migration
-- Keep for backward compatibility during transition
ALTER TABLE chapters
    ALTER COLUMN content DROP NOT NULL;

-- Add flag to indicate if chapter uses content_blocks
ALTER TABLE chapters
    ADD COLUMN use_content_blocks BOOLEAN DEFAULT FALSE;

COMMENT ON COLUMN chapters.use_content_blocks IS 'If true, render from content_blocks instead of content field';

-- =============================================
-- TRIGGER: Auto-update updated_at
-- =============================================
CREATE OR REPLACE FUNCTION update_content_blocks_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER content_blocks_updated_at
    BEFORE UPDATE ON content_blocks
    FOR EACH ROW
    EXECUTE FUNCTION update_content_blocks_updated_at();

-- =============================================
-- RLS POLICIES
-- =============================================
ALTER TABLE content_blocks ENABLE ROW LEVEL SECURITY;

-- Public read access for published books (same as chapters)
CREATE POLICY "content_blocks_select_published"
    ON content_blocks FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM chapters c
            JOIN books b ON b.id = c.book_id
            WHERE c.id = content_blocks.chapter_id
            AND b.status = 'published'
        )
    );

-- Admin/teacher can manage content_blocks
CREATE POLICY "content_blocks_all_for_teachers"
    ON content_blocks FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM auth.users u
            WHERE u.id = auth.uid()
            AND u.raw_user_meta_data->>'role' IN ('teacher', 'admin')
        )
    );
