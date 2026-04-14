-- =============================================
-- Hotfix: translate 24 card/league badges from Turkish to English
-- Follows CLAUDE.md rule "UI in English" and existing badge naming convention.
-- =============================================

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
