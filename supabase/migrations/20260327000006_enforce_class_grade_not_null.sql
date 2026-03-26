-- Enforce classes.grade as NOT NULL with range check.
-- Auto-fix existing null grades from class name heuristics.

DO $$
DECLARE
  r RECORD;
  v_extracted INT;
BEGIN
  FOR r IN SELECT id, name FROM classes WHERE grade IS NULL LOOP
    v_extracted := (regexp_match(r.name, '^(\d+)'))[1]::INT;
    IF v_extracted IS NOT NULL AND v_extracted BETWEEN 1 AND 12 THEN
      UPDATE classes SET grade = v_extracted WHERE id = r.id;
      RAISE NOTICE 'Auto-fixed class "%" → grade %', r.name, v_extracted;
    ELSE
      UPDATE classes SET grade = 5 WHERE id = r.id;
      RAISE NOTICE 'WARNING: Set class "%" to default grade 5', r.name;
    END IF;
  END LOOP;
END $$;

ALTER TABLE classes ALTER COLUMN grade SET NOT NULL;
ALTER TABLE classes ADD CONSTRAINT classes_grade_range CHECK (grade BETWEEN 1 AND 12);
