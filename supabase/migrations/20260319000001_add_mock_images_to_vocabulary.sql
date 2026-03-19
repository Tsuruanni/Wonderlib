-- Add mock images to all vocabulary words for UI testing
-- Uses picsum.photos with word as seed for consistent, unique images
UPDATE vocabulary_words
SET image_url = 'https://picsum.photos/seed/' || word || '/200/200'
WHERE image_url IS NULL;
