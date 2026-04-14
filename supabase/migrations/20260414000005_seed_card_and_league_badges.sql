-- =============================================
-- Seed: Card Collection + League Tier badges
-- 4 total-card + 16 category (half + full) + 4 tier = 24 badges
-- Slugs are stable so re-runs are idempotent via ON CONFLICT DO NOTHING.
-- =============================================

INSERT INTO badges (name, slug, description, icon, category, condition_type, condition_value, condition_param, xp_reward, is_active) VALUES
-- --------- Total Cards ---------
('Koleksiyoncu Çırağı', 'card-collector-10',
 '10 farklı kart topla.', '🎴', 'achievement',
 'cards_collected', 10, NULL, 50, TRUE),
('Kart Ustası', 'card-collector-20',
 '20 farklı kart topla.', '🃏', 'achievement',
 'cards_collected', 20, NULL, 100, TRUE),
('Kart Koleksiyoncusu', 'card-collector-50',
 '50 farklı kart topla.', '🎭', 'achievement',
 'cards_collected', 50, NULL, 250, TRUE),
('Efsane Koleksiyoncu', 'card-collector-96',
 '96 kartın tamamını topla.', '👑', 'achievement',
 'cards_collected', 96, NULL, 1000, TRUE),

-- --------- Turkish Myths (12 cards) ---------
('Türk Mitleri Yarı Yolda', 'myth-turkish-6',
 'Türk Mitleri kategorisinden 6 kart topla.', '🇹🇷', 'achievement',
 'myth_category_completed', 6, 'turkish_myths', 100, TRUE),
('Türk Mitleri Ustası', 'myth-turkish-12',
 'Türk Mitleri kategorisinin tamamını topla (12 kart).', '🏛️', 'achievement',
 'myth_category_completed', 12, 'turkish_myths', 300, TRUE),

-- --------- Ancient Greece ---------
('Antik Yunan Yarı Yolda', 'myth-greece-6',
 'Antik Yunan kategorisinden 6 kart topla.', '⚡', 'achievement',
 'myth_category_completed', 6, 'ancient_greece', 100, TRUE),
('Antik Yunan Ustası', 'myth-greece-12',
 'Antik Yunan kategorisinin tamamını topla (12 kart).', '🏺', 'achievement',
 'myth_category_completed', 12, 'ancient_greece', 300, TRUE),

-- --------- Viking / Ice Lands ---------
('Viking Yarı Yolda', 'myth-viking-6',
 'Viking & Buz Diyarları kategorisinden 6 kart topla.', '⚔️', 'achievement',
 'myth_category_completed', 6, 'viking_ice_lands', 100, TRUE),
('Viking Ustası', 'myth-viking-12',
 'Viking & Buz Diyarları kategorisinin tamamını topla (12 kart).', '🛡️', 'achievement',
 'myth_category_completed', 12, 'viking_ice_lands', 300, TRUE),

-- --------- Egyptian Deserts ---------
('Mısır Yarı Yolda', 'myth-egypt-6',
 'Mısır Çölleri kategorisinden 6 kart topla.', '🐫', 'achievement',
 'myth_category_completed', 6, 'egyptian_deserts', 100, TRUE),
('Mısır Ustası', 'myth-egypt-12',
 'Mısır Çölleri kategorisinin tamamını topla (12 kart).', '🔺', 'achievement',
 'myth_category_completed', 12, 'egyptian_deserts', 300, TRUE),

-- --------- Far East ---------
('Uzak Doğu Yarı Yolda', 'myth-fareast-6',
 'Uzak Doğu kategorisinden 6 kart topla.', '🐉', 'achievement',
 'myth_category_completed', 6, 'far_east', 100, TRUE),
('Uzak Doğu Ustası', 'myth-fareast-12',
 'Uzak Doğu kategorisinin tamamını topla (12 kart).', '🎋', 'achievement',
 'myth_category_completed', 12, 'far_east', 300, TRUE),

-- --------- Medieval Magic ---------
('Ortaçağ Büyüsü Yarı Yolda', 'myth-medieval-6',
 'Ortaçağ Büyüsü kategorisinden 6 kart topla.', '🔮', 'achievement',
 'myth_category_completed', 6, 'medieval_magic', 100, TRUE),
('Ortaçağ Büyüsü Ustası', 'myth-medieval-12',
 'Ortaçağ Büyüsü kategorisinin tamamını topla (12 kart).', '🧙', 'achievement',
 'myth_category_completed', 12, 'medieval_magic', 300, TRUE),

-- --------- Legendary Weapons ---------
('Silah Yarı Yolda', 'myth-weapons-6',
 'Efsanevi Silahlar kategorisinden 6 kart topla.', '🗡️', 'achievement',
 'myth_category_completed', 6, 'legendary_weapons', 100, TRUE),
('Silah Ustası', 'myth-weapons-12',
 'Efsanevi Silahlar kategorisinin tamamını topla (12 kart).', '⚔️', 'achievement',
 'myth_category_completed', 12, 'legendary_weapons', 300, TRUE),

-- --------- Dark Creatures ---------
('Karanlık Yaratıklar Yarı Yolda', 'myth-dark-6',
 'Karanlık Yaratıklar kategorisinden 6 kart topla.', '👻', 'achievement',
 'myth_category_completed', 6, 'dark_creatures', 100, TRUE),
('Karanlık Yaratıklar Ustası', 'myth-dark-12',
 'Karanlık Yaratıklar kategorisinin tamamını topla (12 kart).', '🦇', 'achievement',
 'myth_category_completed', 12, 'dark_creatures', 300, TRUE),

-- --------- League Tier (condition_value is a placeholder — not used in evaluation) ---------
('Silver Ligci', 'league-tier-silver',
 'Silver lige yüksel.', '🥈', 'achievement',
 'league_tier_reached', 1, 'silver', 150, TRUE),
('Gold Ligci', 'league-tier-gold',
 'Gold lige yüksel.', '🥇', 'achievement',
 'league_tier_reached', 1, 'gold', 300, TRUE),
('Platinum Ligci', 'league-tier-platinum',
 'Platinum lige yüksel.', '💎', 'achievement',
 'league_tier_reached', 1, 'platinum', 600, TRUE),
('Diamond Ligci', 'league-tier-diamond',
 'Diamond lige yüksel.', '🌟', 'achievement',
 'league_tier_reached', 1, 'diamond', 1200, TRUE)

ON CONFLICT (slug) DO NOTHING;
