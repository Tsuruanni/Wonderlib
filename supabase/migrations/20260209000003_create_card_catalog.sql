-- Migration: Card Catalog Table
-- Mythic Scholars Arena - Static catalog of 96 mythology cards

-- =============================================
-- MYTH CARDS TABLE
-- =============================================
CREATE TABLE myth_cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    card_no VARCHAR(10) UNIQUE NOT NULL,    -- 'M-001' through 'M-096'
    name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL
        CHECK (category IN (
            'turkish_myths', 'ancient_greece', 'viking_ice_lands',
            'egyptian_deserts', 'far_east', 'medieval_magic',
            'legendary_weapons', 'dark_creatures'
        )),
    rarity VARCHAR(20) NOT NULL
        CHECK (rarity IN ('common', 'rare', 'epic', 'legendary')),
    power INTEGER NOT NULL,
    special_skill VARCHAR(200),
    description TEXT,
    category_icon VARCHAR(10),              -- Emoji icon for category display
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE myth_cards IS 'Static catalog of 96 mythology creature cards';
COMMENT ON COLUMN myth_cards.card_no IS 'Unique card number M-001 through M-096';
COMMENT ON COLUMN myth_cards.rarity IS 'Card rarity: common, rare, epic, legendary';
COMMENT ON COLUMN myth_cards.power IS 'Card power rating (higher = stronger)';

-- =============================================
-- ROW LEVEL SECURITY
-- =============================================
ALTER TABLE myth_cards ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read active cards"
    ON myth_cards FOR SELECT
    USING (is_active = true);

CREATE POLICY "Admins can manage cards"
    ON myth_cards FOR ALL
    USING (is_admin());

-- =============================================
-- INDEXES
-- =============================================
CREATE INDEX idx_myth_cards_category ON myth_cards(category);
CREATE INDEX idx_myth_cards_rarity ON myth_cards(rarity);
CREATE INDEX idx_myth_cards_card_no ON myth_cards(card_no);
