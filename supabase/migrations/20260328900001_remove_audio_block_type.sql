-- Remove unused 'audio' block type from CHECK constraint.
-- Text blocks with audio_url serve the same purpose; no audio-type rows exist.
ALTER TABLE content_blocks
  DROP CONSTRAINT IF EXISTS content_blocks_type_check;

ALTER TABLE content_blocks
  ADD CONSTRAINT content_blocks_type_check
  CHECK (type IN ('text', 'image', 'activity'));
