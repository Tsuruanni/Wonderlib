-- Remove unused system_settings entries
-- These settings have no runtime consumers in the Flutter app or DB functions
DELETE FROM system_settings WHERE key IN (
  'xp_activity_complete',
  'xp_activity_perfect',
  'xp_word_learned',
  'xp_word_mastered',
  'xp_streak_bonus_day',
  'xp_assignment_complete',
  'max_streak_multiplier',
  'streak_bonus_increment',
  'daily_xp_cap',
  'default_time_limit',
  'hint_penalty_percent',
  'skip_penalty_percent',
  'maintenance_mode',
  'min_app_version',
  'feature_word_lists',
  'feature_achievements'
);
