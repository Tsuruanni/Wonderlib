-- Add audio segment columns for chapter-level batch audio generation
-- Each block stores its start/end position within the chapter's combined audio file

ALTER TABLE content_blocks ADD COLUMN IF NOT EXISTS audio_start_ms INTEGER;
ALTER TABLE content_blocks ADD COLUMN IF NOT EXISTS audio_end_ms INTEGER;

COMMENT ON COLUMN content_blocks.audio_start_ms IS 'Start position of this block within the chapter audio file (milliseconds)';
COMMENT ON COLUMN content_blocks.audio_end_ms IS 'End position of this block within the chapter audio file (milliseconds)';
