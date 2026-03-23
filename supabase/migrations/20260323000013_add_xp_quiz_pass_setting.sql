-- Add quiz pass XP reward to system_settings
INSERT INTO system_settings (key, value, category, description)
VALUES ('xp_quiz_pass', '"20"', 'xp', 'XP awarded for passing a book quiz')
ON CONFLICT (key) DO NOTHING;
