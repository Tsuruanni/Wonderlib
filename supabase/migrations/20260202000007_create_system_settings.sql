-- Helper function for updated_at trigger (if not exists)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- System settings table for admin-configurable values
CREATE TABLE IF NOT EXISTS system_settings (
  key VARCHAR(100) PRIMARY KEY,
  value JSONB NOT NULL,
  category VARCHAR(50) NOT NULL DEFAULT 'general',
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE system_settings ENABLE ROW LEVEL SECURITY;

-- Policy: Everyone can read settings
CREATE POLICY "Anyone can read settings"
  ON system_settings FOR SELECT
  USING (true);

-- Policy: Only admins can modify settings
CREATE POLICY "Admins can modify settings"
  ON system_settings FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Trigger for updated_at
CREATE TRIGGER update_system_settings_updated_at
  BEFORE UPDATE ON system_settings
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Seed with default values from AppConfig
INSERT INTO system_settings (key, value, category, description) VALUES
  -- XP Rewards
  ('xp_chapter_complete', '"50"', 'xp', 'XP awarded for completing a chapter'),
  ('xp_activity_complete', '"20"', 'xp', 'XP awarded for completing an activity'),
  ('xp_activity_perfect', '"30"', 'xp', 'Bonus XP for perfect activity score'),
  ('xp_word_learned', '"5"', 'xp', 'XP awarded for learning a new word'),
  ('xp_word_mastered', '"15"', 'xp', 'XP awarded for mastering a word'),
  ('xp_book_complete', '"200"', 'xp', 'XP awarded for completing a book'),
  ('xp_streak_bonus_day', '"10"', 'xp', 'Daily streak bonus XP'),
  ('xp_assignment_complete', '"100"', 'xp', 'XP awarded for completing an assignment'),

  -- Level & Progression
  ('xp_per_level', '"100"', 'progression', 'XP required per level'),
  ('max_streak_multiplier', '"2.0"', 'progression', 'Maximum streak multiplier'),
  ('streak_bonus_increment', '"0.1"', 'progression', 'Streak bonus increment per day'),
  ('daily_xp_cap', '"1000"', 'progression', 'Maximum XP earnable per day'),

  -- Game Settings
  ('default_time_limit', '"60"', 'game', 'Default game time limit in seconds'),
  ('hint_penalty_percent', '"10"', 'game', 'XP penalty percentage for using hints'),
  ('skip_penalty_percent', '"50"', 'game', 'XP penalty percentage for skipping'),

  -- App Settings
  ('maintenance_mode', '"false"', 'app', 'Enable maintenance mode'),
  ('min_app_version', '"1.0.0"', 'app', 'Minimum required app version'),
  ('feature_word_lists', '"true"', 'app', 'Enable word lists feature'),
  ('feature_achievements', '"true"', 'app', 'Enable achievements/badges feature')
ON CONFLICT (key) DO NOTHING;
