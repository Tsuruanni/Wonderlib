-- =============================================================
-- Migration: Username Auth Support
-- Adds username-based authentication for students using
-- synthetic email pattern (username@owlio.local)
-- =============================================================

-- 1. Add username column to profiles
ALTER TABLE profiles ADD COLUMN username VARCHAR(20);

-- Unique partial index (only students have usernames, NULL for teachers/admins)
CREATE UNIQUE INDEX idx_profiles_username ON profiles(username) WHERE username IS NOT NULL;

-- Prevent duplicate classes with NULL academic_year (for class auto-creation)
CREATE UNIQUE INDEX idx_classes_unique_null_year ON classes(school_id, name) WHERE academic_year IS NULL;

-- 2. Username generation function
CREATE OR REPLACE FUNCTION generate_username(p_first_name TEXT, p_last_name TEXT)
RETURNS TEXT AS $$
DECLARE
  v_base TEXT;
  v_max_num INT;
BEGIN
  -- Turkish → ASCII, lowercase, take first 3 chars each
  v_base := lower(
    translate(
      left(p_first_name, 3) || left(p_last_name, 3),
      'şçğöüıİŞÇĞÖÜ',
      'scgouiiSCGOU'
    )
  );

  -- Strip non-alphanumeric chars (handles periods, hyphens, etc.)
  v_base := regexp_replace(v_base, '[^a-z0-9]', '', 'g');

  -- Fallback if base is empty after sanitization
  IF v_base = '' THEN
    v_base := 'user';
  END IF;

  -- Advisory lock to prevent race conditions on same base
  PERFORM pg_advisory_xact_lock(hashtext(v_base));

  -- Find highest existing number for this base
  SELECT MAX(
    CAST(substring(username FROM length(v_base) + 1) AS INT)
  ) INTO v_max_num
  FROM profiles
  WHERE username LIKE v_base || '%'
    AND substring(username FROM length(v_base) + 1) ~ '^\d+$';

  RETURN v_base || COALESCE(v_max_num + 1, 1);
END;
$$ LANGUAGE plpgsql;

-- 3. Generate usernames for all existing students
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT id, first_name, last_name
    FROM profiles
    WHERE role = 'student' AND username IS NULL
    AND first_name IS NOT NULL AND last_name IS NOT NULL
  LOOP
    UPDATE profiles
    SET username = generate_username(r.first_name, r.last_name)
    WHERE id = r.id;
  END LOOP;
END $$;

-- 4. Update safe_profiles view to include username
-- Must DROP+CREATE because adding a column in the middle changes column order
DROP VIEW IF EXISTS safe_profiles;
CREATE VIEW safe_profiles AS
SELECT
    id,
    school_id,
    class_id,
    role,
    first_name,
    last_name,
    avatar_url,
    username,
    xp,
    level,
    current_streak,
    longest_streak,
    league_tier,
    last_activity_date,
    created_at
    -- Deliberately omits: email, student_number, coins, settings
FROM profiles;

GRANT SELECT ON safe_profiles TO authenticated;

COMMENT ON VIEW safe_profiles IS 'Student-safe profile view. Omits email, student_number, coins, settings. Includes username for public display.';
