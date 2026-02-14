-- ============================================================
-- Unit Book Assignments
-- Assigns books to vocabulary units, scoped by school/grade/class.
-- Uses cascading fallback: class → grade → school-wide.
-- ============================================================

CREATE TABLE unit_book_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  unit_id UUID NOT NULL REFERENCES vocabulary_units(id) ON DELETE CASCADE,
  book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  grade INTEGER CHECK (grade >= 1 AND grade <= 12),
  class_id UUID REFERENCES classes(id) ON DELETE CASCADE,
  order_in_unit INTEGER NOT NULL DEFAULT 0,
  assigned_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Grade and class are mutually exclusive (same pattern as unit_curriculum_assignments)
  CHECK (NOT (grade IS NOT NULL AND class_id IS NOT NULL)),

  -- Same book can't be assigned twice to the same unit+scope
  UNIQUE NULLS NOT DISTINCT (unit_id, book_id, school_id, grade, class_id)
);

-- Indexes for fast lookups
CREATE INDEX idx_unit_book_assignments_scope
  ON unit_book_assignments(school_id, grade, class_id);
CREATE INDEX idx_unit_book_assignments_unit
  ON unit_book_assignments(unit_id);

-- Enable RLS
ALTER TABLE unit_book_assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read unit book assignments"
  ON unit_book_assignments FOR SELECT
  TO authenticated USING (true);

CREATE POLICY "Admins can manage unit book assignments"
  ON unit_book_assignments FOR ALL
  TO authenticated USING (true) WITH CHECK (true);

-- ============================================================
-- RPC: get_user_unit_books
-- Returns books assigned to the user's vocabulary units,
-- using cascading fallback scope resolution:
--   1. Class-specific assignments (most specific)
--   2. Grade-level assignments
--   3. School-wide assignments (least specific)
-- For each unit, only the MOST SPECIFIC scope is used.
-- ============================================================

CREATE OR REPLACE FUNCTION get_user_unit_books(p_user_id UUID)
RETURNS TABLE(unit_id UUID, book_id UUID, order_in_unit INTEGER) AS $$
DECLARE
  v_school_id UUID;
  v_class_id UUID;
  v_grade INTEGER;
BEGIN
  -- Step 1: Get user's scope context
  SELECT p.school_id, p.class_id, c.grade
  INTO v_school_id, v_class_id, v_grade
  FROM profiles p
  LEFT JOIN classes c ON p.class_id = c.id
  WHERE p.id = p_user_id;

  -- No school → no book assignments
  IF v_school_id IS NULL THEN
    RETURN;
  END IF;

  -- Step 2: For each unit, find most specific scope with assignments
  -- Priority: 1=class, 2=grade, 3=school-wide, 4=no match
  RETURN QUERY
  WITH ranked AS (
    SELECT
      uba.unit_id,
      uba.book_id,
      uba.order_in_unit,
      CASE
        WHEN uba.class_id = v_class_id AND v_class_id IS NOT NULL THEN 1
        WHEN uba.grade = v_grade AND v_grade IS NOT NULL
             AND uba.class_id IS NULL THEN 2
        WHEN uba.grade IS NULL AND uba.class_id IS NULL THEN 3
        ELSE 4
      END AS priority
    FROM unit_book_assignments uba
    WHERE uba.school_id = v_school_id
  ),
  best_scope AS (
    SELECT r.unit_id, MIN(r.priority) AS best_priority
    FROM ranked r
    WHERE r.priority <= 3
    GROUP BY r.unit_id
  )
  SELECT r.unit_id, r.book_id, r.order_in_unit
  FROM ranked r
  JOIN best_scope bs ON r.unit_id = bs.unit_id AND r.priority = bs.best_priority
  ORDER BY r.unit_id, r.order_in_unit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
