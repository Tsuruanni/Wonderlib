-- Migration 6: Gamification Tables
-- ReadEng (Wonderlib) Database Schema

-- =============================================
-- BADGES
-- =============================================
CREATE TABLE badges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    icon VARCHAR(50),
    category VARCHAR(50),
    condition_type VARCHAR(50) NOT NULL
        CHECK (condition_type IN (
            'xp_total', 'streak_days', 'books_completed',
            'vocabulary_learned', 'perfect_scores',
            'level_completed', 'daily_login'
        )),
    condition_value INTEGER NOT NULL,
    xp_reward INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE badges IS 'Achievement badges users can earn';
COMMENT ON COLUMN badges.condition_type IS 'Type of condition to earn badge';
COMMENT ON COLUMN badges.condition_value IS 'Numeric threshold for condition';

-- =============================================
-- USER BADGES
-- =============================================
CREATE TABLE user_badges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    badge_id UUID NOT NULL REFERENCES badges(id) ON DELETE CASCADE,
    earned_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(user_id, badge_id)
);

COMMENT ON TABLE user_badges IS 'Badges earned by users';

-- =============================================
-- XP LOGS
-- =============================================
CREATE TABLE xp_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    amount INTEGER NOT NULL,
    source VARCHAR(50) NOT NULL,
    source_id UUID,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE xp_logs IS 'Audit log of all XP earned';
COMMENT ON COLUMN xp_logs.source IS 'Source of XP: reading, activity, vocabulary, streak, badge, etc.';
