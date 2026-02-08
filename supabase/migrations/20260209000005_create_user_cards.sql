-- Migration: User Card Collection Tables
-- Mythic Scholars Arena - User card ownership, pack purchases, stats

-- =============================================
-- USER CARDS (owned cards with quantity)
-- =============================================
CREATE TABLE user_cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    card_id UUID NOT NULL REFERENCES myth_cards(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL DEFAULT 1,
    first_obtained_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(user_id, card_id)
);

COMMENT ON TABLE user_cards IS 'Cards owned by users with quantity tracking for duplicates';

-- =============================================
-- PACK PURCHASES (purchase history)
-- =============================================
CREATE TABLE pack_purchases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    cost INTEGER NOT NULL,
    card_ids UUID[] NOT NULL,                  -- Array of 3 card_ids from this pack
    pity_counter_at_purchase INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE pack_purchases IS 'History of card pack purchases';
COMMENT ON COLUMN pack_purchases.card_ids IS 'Array of 3 myth_card IDs obtained in this pack';
COMMENT ON COLUMN pack_purchases.pity_counter_at_purchase IS 'Pity counter value at time of purchase';

-- =============================================
-- USER CARD STATS (aggregate stats + pity counter)
-- =============================================
CREATE TABLE user_card_stats (
    user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
    packs_since_legendary INTEGER DEFAULT 0,   -- Hidden pity counter
    total_packs_opened INTEGER DEFAULT 0,
    total_unique_cards INTEGER DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE user_card_stats IS 'Aggregate card collection statistics per user';
COMMENT ON COLUMN user_card_stats.packs_since_legendary IS 'Hidden pity counter - packs since last legendary card';

-- =============================================
-- ROW LEVEL SECURITY
-- =============================================
ALTER TABLE user_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE pack_purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_card_stats ENABLE ROW LEVEL SECURITY;

-- Users can view own cards
CREATE POLICY "Users can view own cards"
    ON user_cards FOR SELECT
    USING (user_id = auth.uid());

-- Users can view classmate cards (for future social features)
CREATE POLICY "Users can view classmate cards"
    ON user_cards FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM profiles p
        WHERE p.id = user_cards.user_id
        AND p.school_id = get_user_school_id()
    ));

-- System can manage user cards (via RPC functions)
CREATE POLICY "System can manage user cards"
    ON user_cards FOR ALL
    USING (true);

-- Pack purchases: own only
CREATE POLICY "Users can view own pack purchases"
    ON pack_purchases FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "System can insert pack purchases"
    ON pack_purchases FOR INSERT
    WITH CHECK (true);

-- Card stats: own + classmates
CREATE POLICY "Users can view own card stats"
    ON user_card_stats FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Users can view classmate card stats"
    ON user_card_stats FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM profiles p
        WHERE p.id = user_card_stats.user_id
        AND p.school_id = get_user_school_id()
    ));

CREATE POLICY "System can manage card stats"
    ON user_card_stats FOR ALL
    USING (true);

-- =============================================
-- INDEXES
-- =============================================
CREATE INDEX idx_user_cards_user_id ON user_cards(user_id);
CREATE INDEX idx_user_cards_card_id ON user_cards(card_id);
CREATE INDEX idx_pack_purchases_user_id ON pack_purchases(user_id);
CREATE INDEX idx_pack_purchases_created_at ON pack_purchases(created_at DESC);
