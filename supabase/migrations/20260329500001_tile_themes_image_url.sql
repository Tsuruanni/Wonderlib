-- Add image_url column to tile_themes for background images
ALTER TABLE tile_themes
  ADD COLUMN image_url TEXT;
