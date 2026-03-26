-- Add assignment notification setting
INSERT INTO system_settings (key, value, category, description, sort_order) VALUES
  ('notif_assignment', '"true"', 'notification', 'Show dialog when student has active assignments on app open', 8)
ON CONFLICT (key) DO NOTHING;
