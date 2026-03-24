-- Store plaintext passwords for admin visibility
-- Only accessible by admin/head via direct profiles query (not in safe_profiles view)
ALTER TABLE profiles ADD COLUMN password_plain VARCHAR(20);

COMMENT ON COLUMN profiles.password_plain IS 'Plaintext password for admin display. Only set for auto-created users. Not exposed in safe_profiles view.';
