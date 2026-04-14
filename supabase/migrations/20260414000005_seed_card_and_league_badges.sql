-- =============================================
-- Seed: Card Collection + League Tier badges
-- 4 total-card + 16 category (half + full) + 4 tier = 24 badges
-- Slugs are stable so re-runs are idempotent via ON CONFLICT DO NOTHING.
--
-- NOTE on league_tier_reached rows: condition_value is a required non-NULL
-- integer by schema, but the RPC evaluates these badges exclusively on
-- condition_param (tier name) via array_position. The value `1` is a
-- placeholder only — it is never read for evaluation.
-- =============================================

INSERT INTO badges (name, slug, description, icon, category, condition_type, condition_value, condition_param, xp_reward, is_active) VALUES
-- --------- Total Cards ---------
('Apprentice Collector', 'card-collector-10',
 'Collect 10 different cards.', '🎴', 'achievement',
 'cards_collected', 10, NULL, 50, TRUE),
('Card Master', 'card-collector-20',
 'Collect 20 different cards.', '🃏', 'achievement',
 'cards_collected', 20, NULL, 100, TRUE),
('Card Collector', 'card-collector-50',
 'Collect 50 different cards.', '🎭', 'achievement',
 'cards_collected', 50, NULL, 250, TRUE),
('Legendary Collector', 'card-collector-96',
 'Collect all 96 cards.', '👑', 'achievement',
 'cards_collected', 96, NULL, 1000, TRUE),

-- --------- Turkish Myths (12 cards) ---------
('Turkish Myths Halfway', 'myth-turkish-6',
 'Collect 6 cards from the Turkish Myths category.', '🇹🇷', 'achievement',
 'myth_category_completed', 6, 'turkish_myths', 100, TRUE),
('Turkish Myths Master', 'myth-turkish-12',
 'Collect all 12 cards in the Turkish Myths category.', '🏛️', 'achievement',
 'myth_category_completed', 12, 'turkish_myths', 300, TRUE),

-- --------- Ancient Greece ---------
('Ancient Greece Halfway', 'myth-greece-6',
 'Collect 6 cards from the Ancient Greece category.', '⚡', 'achievement',
 'myth_category_completed', 6, 'ancient_greece', 100, TRUE),
('Ancient Greece Master', 'myth-greece-12',
 'Collect all 12 cards in the Ancient Greece category.', '🏺', 'achievement',
 'myth_category_completed', 12, 'ancient_greece', 300, TRUE),

-- --------- Viking / Ice Lands ---------
('Viking Halfway', 'myth-viking-6',
 'Collect 6 cards from the Viking & Ice Lands category.', '⚔️', 'achievement',
 'myth_category_completed', 6, 'viking_ice_lands', 100, TRUE),
('Viking Master', 'myth-viking-12',
 'Collect all 12 cards in the Viking & Ice Lands category.', '🛡️', 'achievement',
 'myth_category_completed', 12, 'viking_ice_lands', 300, TRUE),

-- --------- Egyptian Deserts ---------
('Egyptian Halfway', 'myth-egypt-6',
 'Collect 6 cards from the Egyptian Deserts category.', '🐫', 'achievement',
 'myth_category_completed', 6, 'egyptian_deserts', 100, TRUE),
('Egyptian Master', 'myth-egypt-12',
 'Collect all 12 cards in the Egyptian Deserts category.', '🔺', 'achievement',
 'myth_category_completed', 12, 'egyptian_deserts', 300, TRUE),

-- --------- Far East ---------
('Far East Halfway', 'myth-fareast-6',
 'Collect 6 cards from the Far East category.', '🐉', 'achievement',
 'myth_category_completed', 6, 'far_east', 100, TRUE),
('Far East Master', 'myth-fareast-12',
 'Collect all 12 cards in the Far East category.', '🎋', 'achievement',
 'myth_category_completed', 12, 'far_east', 300, TRUE),

-- --------- Medieval Magic ---------
('Medieval Magic Halfway', 'myth-medieval-6',
 'Collect 6 cards from the Medieval Magic category.', '🔮', 'achievement',
 'myth_category_completed', 6, 'medieval_magic', 100, TRUE),
('Medieval Magic Master', 'myth-medieval-12',
 'Collect all 12 cards in the Medieval Magic category.', '🧙', 'achievement',
 'myth_category_completed', 12, 'medieval_magic', 300, TRUE),

-- --------- Legendary Weapons ---------
('Legendary Weapons Halfway', 'myth-weapons-6',
 'Collect 6 cards from the Legendary Weapons category.', '🗡️', 'achievement',
 'myth_category_completed', 6, 'legendary_weapons', 100, TRUE),
('Legendary Weapons Master', 'myth-weapons-12',
 'Collect all 12 cards in the Legendary Weapons category.', '⚔️', 'achievement',
 'myth_category_completed', 12, 'legendary_weapons', 300, TRUE),

-- --------- Dark Creatures ---------
('Dark Creatures Halfway', 'myth-dark-6',
 'Collect 6 cards from the Dark Creatures category.', '👻', 'achievement',
 'myth_category_completed', 6, 'dark_creatures', 100, TRUE),
('Dark Creatures Master', 'myth-dark-12',
 'Collect all 12 cards in the Dark Creatures category.', '🦇', 'achievement',
 'myth_category_completed', 12, 'dark_creatures', 300, TRUE),

-- --------- League Tier (condition_value is a placeholder — RPC uses condition_param only) ---------
('Silver League', 'league-tier-silver',
 'Reach the Silver League.', '🥈', 'achievement',
 'league_tier_reached', 1, 'silver', 150, TRUE),
('Gold League', 'league-tier-gold',
 'Reach the Gold League.', '🥇', 'achievement',
 'league_tier_reached', 1, 'gold', 300, TRUE),
('Platinum League', 'league-tier-platinum',
 'Reach the Platinum League.', '💎', 'achievement',
 'league_tier_reached', 1, 'platinum', 600, TRUE),
('Diamond League', 'league-tier-diamond',
 'Reach the Diamond League.', '🌟', 'achievement',
 'league_tier_reached', 1, 'diamond', 1200, TRUE)

ON CONFLICT (slug) DO NOTHING;

-- NOTE: The UPDATE below is a recovery mechanism. On a fresh DB the INSERT above
-- already provides English values, making this UPDATE a harmless no-op.
-- The UPDATE handles the case where this migration was first applied with
-- Turkish names (pre-hotfix) and the remote rows need translation.

-- Update existing rows that might have been inserted with Turkish names (in case
-- the original migration landed on remote first). Safe no-op if slugs don't exist.
UPDATE badges SET
    name = CASE slug
        WHEN 'card-collector-10' THEN 'Apprentice Collector'
        WHEN 'card-collector-20' THEN 'Card Master'
        WHEN 'card-collector-50' THEN 'Card Collector'
        WHEN 'card-collector-96' THEN 'Legendary Collector'
        WHEN 'myth-turkish-6' THEN 'Turkish Myths Halfway'
        WHEN 'myth-turkish-12' THEN 'Turkish Myths Master'
        WHEN 'myth-greece-6' THEN 'Ancient Greece Halfway'
        WHEN 'myth-greece-12' THEN 'Ancient Greece Master'
        WHEN 'myth-viking-6' THEN 'Viking Halfway'
        WHEN 'myth-viking-12' THEN 'Viking Master'
        WHEN 'myth-egypt-6' THEN 'Egyptian Halfway'
        WHEN 'myth-egypt-12' THEN 'Egyptian Master'
        WHEN 'myth-fareast-6' THEN 'Far East Halfway'
        WHEN 'myth-fareast-12' THEN 'Far East Master'
        WHEN 'myth-medieval-6' THEN 'Medieval Magic Halfway'
        WHEN 'myth-medieval-12' THEN 'Medieval Magic Master'
        WHEN 'myth-weapons-6' THEN 'Legendary Weapons Halfway'
        WHEN 'myth-weapons-12' THEN 'Legendary Weapons Master'
        WHEN 'myth-dark-6' THEN 'Dark Creatures Halfway'
        WHEN 'myth-dark-12' THEN 'Dark Creatures Master'
        WHEN 'league-tier-silver' THEN 'Silver League'
        WHEN 'league-tier-gold' THEN 'Gold League'
        WHEN 'league-tier-platinum' THEN 'Platinum League'
        WHEN 'league-tier-diamond' THEN 'Diamond League'
        ELSE name
    END,
    description = CASE slug
        WHEN 'card-collector-10' THEN 'Collect 10 different cards.'
        WHEN 'card-collector-20' THEN 'Collect 20 different cards.'
        WHEN 'card-collector-50' THEN 'Collect 50 different cards.'
        WHEN 'card-collector-96' THEN 'Collect all 96 cards.'
        WHEN 'myth-turkish-6' THEN 'Collect 6 cards from the Turkish Myths category.'
        WHEN 'myth-turkish-12' THEN 'Collect all 12 cards in the Turkish Myths category.'
        WHEN 'myth-greece-6' THEN 'Collect 6 cards from the Ancient Greece category.'
        WHEN 'myth-greece-12' THEN 'Collect all 12 cards in the Ancient Greece category.'
        WHEN 'myth-viking-6' THEN 'Collect 6 cards from the Viking & Ice Lands category.'
        WHEN 'myth-viking-12' THEN 'Collect all 12 cards in the Viking & Ice Lands category.'
        WHEN 'myth-egypt-6' THEN 'Collect 6 cards from the Egyptian Deserts category.'
        WHEN 'myth-egypt-12' THEN 'Collect all 12 cards in the Egyptian Deserts category.'
        WHEN 'myth-fareast-6' THEN 'Collect 6 cards from the Far East category.'
        WHEN 'myth-fareast-12' THEN 'Collect all 12 cards in the Far East category.'
        WHEN 'myth-medieval-6' THEN 'Collect 6 cards from the Medieval Magic category.'
        WHEN 'myth-medieval-12' THEN 'Collect all 12 cards in the Medieval Magic category.'
        WHEN 'myth-weapons-6' THEN 'Collect 6 cards from the Legendary Weapons category.'
        WHEN 'myth-weapons-12' THEN 'Collect all 12 cards in the Legendary Weapons category.'
        WHEN 'myth-dark-6' THEN 'Collect 6 cards from the Dark Creatures category.'
        WHEN 'myth-dark-12' THEN 'Collect all 12 cards in the Dark Creatures category.'
        WHEN 'league-tier-silver' THEN 'Reach the Silver League.'
        WHEN 'league-tier-gold' THEN 'Reach the Gold League.'
        WHEN 'league-tier-platinum' THEN 'Reach the Platinum League.'
        WHEN 'league-tier-diamond' THEN 'Reach the Diamond League.'
        ELSE description
    END
WHERE slug IN (
    'card-collector-10','card-collector-20','card-collector-50','card-collector-96',
    'myth-turkish-6','myth-turkish-12','myth-greece-6','myth-greece-12',
    'myth-viking-6','myth-viking-12','myth-egypt-6','myth-egypt-12',
    'myth-fareast-6','myth-fareast-12','myth-medieval-6','myth-medieval-12',
    'myth-weapons-6','myth-weapons-12','myth-dark-6','myth-dark-12',
    'league-tier-silver','league-tier-gold','league-tier-platinum','league-tier-diamond'
);
