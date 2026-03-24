-- Notification settings: admin-configurable toggles for in-app notifications
INSERT INTO system_settings (key, value, category, description, sort_order) VALUES
  ('notif_streak_extended', '"true"', 'notification', 'Show daily "Day X!" streak dialog', 1),
  ('notif_streak_broken', '"true"', 'notification', 'Show streak broken dialog', 2),
  ('notif_streak_broken_min', '"3"', 'notification', 'Minimum streak days to show broken dialog', 3),
  ('notif_milestone', '"true"', 'notification', 'Show milestone dialog (7, 14, 30...)', 4),
  ('notif_level_up', '"true"', 'notification', 'Show level up dialog', 5),
  ('notif_league_change', '"true"', 'notification', 'Show league promotion/demotion dialog', 6),
  ('notif_freeze_saved', '"true"', 'notification', 'Show streak freeze saved dialog', 7)
ON CONFLICT (key) DO NOTHING;
