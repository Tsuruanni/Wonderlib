-- =============================================
-- SEED: Avatar accessories (images to be uploaded via admin panel)
-- Placeholder image_url will be updated when admin uploads PNGs
-- =============================================

-- Helper: get category ID by name
-- Using CTEs for readability

WITH cats AS (
    SELECT id, name FROM avatar_item_categories
)
INSERT INTO avatar_items (category_id, name, display_name, rarity, coin_price, image_url, is_active) VALUES
    -- ══════════════════════════════════════════
    -- HEAD (hat, crown, helmet)
    -- ══════════════════════════════════════════
    ((SELECT id FROM cats WHERE name = 'head'), 'red_beret',          'Red Beret',           'common',    50,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/red_beret.png', false),
    ((SELECT id FROM cats WHERE name = 'head'), 'bandana',            'Bandana',             'common',    50,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/bandana.png', false),
    ((SELECT id FROM cats WHERE name = 'head'), 'flower_crown',       'Flower Crown',        'common',    50,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/flower_crown.png', false),
    ((SELECT id FROM cats WHERE name = 'head'), 'cowboy_hat',         'Cowboy Hat',          'rare',     150,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/cowboy_hat.png', false),
    ((SELECT id FROM cats WHERE name = 'head'), 'sailor_hat',         'Sailor Hat',          'rare',     150,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/sailor_hat.png', false),
    ((SELECT id FROM cats WHERE name = 'head'), 'chef_hat',           'Chef Hat',            'rare',     150,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/chef_hat.png', false),
    ((SELECT id FROM cats WHERE name = 'head'), 'party_hat',          'Party Hat',           'rare',     150,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/party_hat.png', false),
    ((SELECT id FROM cats WHERE name = 'head'), 'wizard_hat',         'Wizard Hat',          'epic',     400,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/wizard_hat.png', false),
    ((SELECT id FROM cats WHERE name = 'head'), 'viking_helmet',      'Viking Helmet',       'epic',     400,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/viking_helmet.png', false),
    ((SELECT id FROM cats WHERE name = 'head'), 'pirate_hat',         'Pirate Hat',          'epic',     400,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/pirate_hat.png', false),
    ((SELECT id FROM cats WHERE name = 'head'), 'golden_crown',       'Golden Crown',        'legendary', 1000, 'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/golden_crown.png', false),
    ((SELECT id FROM cats WHERE name = 'head'), 'astronaut_helmet',   'Astronaut Helmet',    'legendary', 1000, 'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/astronaut_helmet.png', false),

    -- ══════════════════════════════════════════
    -- FACE (glasses, mask, eye patch)
    -- ══════════════════════════════════════════
    ((SELECT id FROM cats WHERE name = 'face'), 'round_glasses',      'Round Glasses',       'common',    50,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/round_glasses.png', false),
    ((SELECT id FROM cats WHERE name = 'face'), 'eye_patch',          'Eye Patch',           'common',    50,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/eye_patch.png', false),
    ((SELECT id FROM cats WHERE name = 'face'), 'freckle_sticker',    'Freckle Sticker',     'common',    50,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/freckle_sticker.png', false),
    ((SELECT id FROM cats WHERE name = 'face'), 'sunglasses',         'Sunglasses',          'rare',     150,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/sunglasses.png', false),
    ((SELECT id FROM cats WHERE name = 'face'), 'aviator_glasses',    'Aviator Glasses',     'rare',     150,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/aviator_glasses.png', false),
    ((SELECT id FROM cats WHERE name = 'face'), 'fake_mustache',      'Fake Mustache',       'rare',     150,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/fake_mustache.png', false),
    ((SELECT id FROM cats WHERE name = 'face'), 'neon_glasses',       'Neon Glasses',        'epic',     400,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/neon_glasses.png', false),
    ((SELECT id FROM cats WHERE name = 'face'), 'monocle',            'Monocle',             'epic',     400,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/monocle.png', false),
    ((SELECT id FROM cats WHERE name = 'face'), 'superhero_mask',     'Superhero Mask',      'epic',     400,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/superhero_mask.png', false),
    ((SELECT id FROM cats WHERE name = 'face'), 'robot_visor',        'Robot Visor',         'legendary', 1000, 'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/robot_visor.png', false),
    ((SELECT id FROM cats WHERE name = 'face'), 'dragon_mask',        'Dragon Mask',         'legendary', 1000, 'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/dragon_mask.png', false),

    -- ══════════════════════════════════════════
    -- BODY (upper clothing)
    -- ══════════════════════════════════════════
    ((SELECT id FROM cats WHERE name = 'body'), 'white_tshirt',       'White T-Shirt',       'common',    50,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/white_tshirt.png', false),
    ((SELECT id FROM cats WHERE name = 'body'), 'school_apron',       'School Apron',        'common',    50,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/school_apron.png', false),
    ((SELECT id FROM cats WHERE name = 'body'), 'striped_sweater',    'Striped Sweater',     'common',    50,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/striped_sweater.png', false),
    ((SELECT id FROM cats WHERE name = 'body'), 'red_cape',           'Red Cape',            'rare',     150,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/red_cape.png', false),
    ((SELECT id FROM cats WHERE name = 'body'), 'denim_jacket',       'Denim Jacket',        'rare',     150,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/denim_jacket.png', false),
    ((SELECT id FROM cats WHERE name = 'body'), 'football_jersey',    'Football Jersey',     'rare',     150,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/football_jersey.png', false),
    ((SELECT id FROM cats WHERE name = 'body'), 'armor',              'Armor',               'epic',     400,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/armor.png', false),
    ((SELECT id FROM cats WHERE name = 'body'), 'tuxedo',             'Tuxedo',              'epic',     400,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/tuxedo.png', false),
    ((SELECT id FROM cats WHERE name = 'body'), 'lab_coat',           'Lab Coat',            'epic',     400,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/lab_coat.png', false),
    ((SELECT id FROM cats WHERE name = 'body'), 'golden_armor',       'Golden Armor',        'legendary', 1000, 'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/golden_armor.png', false),
    ((SELECT id FROM cats WHERE name = 'body'), 'wizard_robe',        'Wizard Robe',         'legendary', 1000, 'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/wizard_robe.png', false),

    -- ══════════════════════════════════════════
    -- NECK (bowtie, necklace, scarf)
    -- ══════════════════════════════════════════
    ((SELECT id FROM cats WHERE name = 'neck'), 'red_bowtie',         'Red Bowtie',          'common',    50,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/red_bowtie.png', false),
    ((SELECT id FROM cats WHERE name = 'neck'), 'bead_necklace',      'Bead Necklace',       'common',    50,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/bead_necklace.png', false),
    ((SELECT id FROM cats WHERE name = 'neck'), 'scarf',              'Scarf',               'rare',     150,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/scarf.png', false),
    ((SELECT id FROM cats WHERE name = 'neck'), 'necktie',            'Necktie',             'rare',     150,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/necktie.png', false),
    ((SELECT id FROM cats WHERE name = 'neck'), 'headphones',         'Headphones',          'rare',     150,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/headphones.png', false),
    ((SELECT id FROM cats WHERE name = 'neck'), 'gold_necklace',      'Gold Necklace',       'epic',     400,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/gold_necklace.png', false),
    ((SELECT id FROM cats WHERE name = 'neck'), 'superhero_cape_clip','Superhero Cape Clip', 'epic',     400,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/superhero_cape_clip.png', false),
    ((SELECT id FROM cats WHERE name = 'neck'), 'medallion',          'Medallion',           'legendary', 1000, 'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/medallion.png', false),

    -- ══════════════════════════════════════════
    -- BACKGROUND
    -- ══════════════════════════════════════════
    ((SELECT id FROM cats WHERE name = 'background'), 'blue_circle',     'Blue Circle',        'common',    50,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/blue_circle.png', false),
    ((SELECT id FROM cats WHERE name = 'background'), 'green_leaves',    'Green Leaves',       'common',    50,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/green_leaves.png', false),
    ((SELECT id FROM cats WHERE name = 'background'), 'pink_hearts',     'Pink Hearts',        'common',    50,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/pink_hearts.png', false),
    ((SELECT id FROM cats WHERE name = 'background'), 'rainbow',         'Rainbow',            'rare',     150,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/rainbow.png', false),
    ((SELECT id FROM cats WHERE name = 'background'), 'stars',           'Stars',              'rare',     150,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/stars.png', false),
    ((SELECT id FROM cats WHERE name = 'background'), 'snowflakes',      'Snowflakes',         'rare',     150,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/snowflakes.png', false),
    ((SELECT id FROM cats WHERE name = 'background'), 'galaxy',          'Galaxy',             'epic',     400,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/galaxy.png', false),
    ((SELECT id FROM cats WHERE name = 'background'), 'fire_ring',       'Fire Ring',          'epic',     400,  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/fire_ring.png', false),
    ((SELECT id FROM cats WHERE name = 'background'), 'enchanted_forest','Enchanted Forest',   'legendary', 1000, 'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/enchanted_forest.png', false),
    ((SELECT id FROM cats WHERE name = 'background'), 'aurora_borealis', 'Aurora Borealis',    'legendary', 1000, 'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/items/aurora_borealis.png', false);
