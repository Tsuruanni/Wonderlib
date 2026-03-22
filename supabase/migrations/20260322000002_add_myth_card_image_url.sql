-- Add image_url column to myth_cards for Supabase Storage URLs
ALTER TABLE myth_cards
ADD COLUMN image_url VARCHAR(500);

-- Populate image_url from card name → Storage public URL
-- Pattern: https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/card-images/{name}.png
-- Names with special chars (') are stored without them in the file
UPDATE myth_cards
SET image_url = 'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/card-images/'
    || REPLACE(REPLACE(REPLACE(name, '''', ''), '(', ''), ')', '')
    || '.png';

COMMENT ON COLUMN myth_cards.image_url IS 'Public URL to card image in Supabase Storage';
