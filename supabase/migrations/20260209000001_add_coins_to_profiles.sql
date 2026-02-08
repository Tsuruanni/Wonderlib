-- Migration: Add Coins to Profiles
-- Mythic Scholars Arena - Dual Currency System
-- Coins are earned alongside XP but can be spent on card packs

-- =============================================
-- ADD COINS COLUMN TO PROFILES
-- =============================================
ALTER TABLE profiles ADD COLUMN coins INTEGER DEFAULT 0;
COMMENT ON COLUMN profiles.coins IS 'Spendable currency earned alongside XP, used to buy card packs';

-- =============================================
-- COIN TRANSACTION LOG (mirrors xp_logs)
-- =============================================
CREATE TABLE coin_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    amount INTEGER NOT NULL,          -- positive = earn, negative = spend
    balance_after INTEGER NOT NULL,   -- balance after this transaction
    source VARCHAR(50) NOT NULL,      -- 'activity', 'reading', 'vocabulary', 'pack_purchase', etc.
    source_id UUID,                   -- optional link to source entity
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE coin_logs IS 'Audit log of all coin transactions (earn and spend)';
COMMENT ON COLUMN coin_logs.amount IS 'Positive for earning, negative for spending';
COMMENT ON COLUMN coin_logs.balance_after IS 'Coin balance after this transaction';

-- =============================================
-- ROW LEVEL SECURITY
-- =============================================
ALTER TABLE coin_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own coin logs"
    ON coin_logs FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "System can insert coin logs"
    ON coin_logs FOR INSERT
    WITH CHECK (true);

-- =============================================
-- INDEXES
-- =============================================
CREATE INDEX idx_coin_logs_user_id ON coin_logs(user_id);
CREATE INDEX idx_coin_logs_created_at ON coin_logs(created_at DESC);
