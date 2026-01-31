-- Migration: Make student_number globally unique
-- This allows login with just student_number (no school code needed)

-- Remove existing school-scoped unique constraint if it exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'profiles_school_student_unique'
  ) THEN
    ALTER TABLE profiles DROP CONSTRAINT profiles_school_student_unique;
  END IF;
END $$;

-- Add global unique constraint on student_number
-- Note: student_number can be NULL for teachers/admins, so we use a partial index
CREATE UNIQUE INDEX IF NOT EXISTS profiles_student_number_unique
  ON profiles (student_number)
  WHERE student_number IS NOT NULL;

COMMENT ON INDEX profiles_student_number_unique IS 'Student numbers are globally unique for direct login without school code';
