-- =============================================
-- UNIT CURRICULUM ASSIGNMENTS
-- Allows admins to assign vocabulary units to
-- schools, grades, or specific classes.
-- =============================================

CREATE TABLE unit_curriculum_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Unit being assigned
    unit_id UUID NOT NULL REFERENCES vocabulary_units(id) ON DELETE CASCADE,

    -- Scope: school_id is always required
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    grade INTEGER CHECK (grade >= 1 AND grade <= 12),
    class_id UUID REFERENCES classes(id) ON DELETE CASCADE,

    -- Admin who created the assignment
    assigned_by UUID REFERENCES profiles(id) ON DELETE SET NULL,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- grade and class_id cannot both be set
    CHECK (NOT (grade IS NOT NULL AND class_id IS NOT NULL)),

    -- Prevent duplicate assignments
    UNIQUE NULLS NOT DISTINCT (unit_id, school_id, grade, class_id)
);

COMMENT ON TABLE unit_curriculum_assignments IS 'Admin-assigned vocabulary units to schools/grades/classes';

-- =============================================
-- INDEXES
-- =============================================

CREATE INDEX idx_unit_curriculum_school
    ON unit_curriculum_assignments(school_id);

CREATE INDEX idx_unit_curriculum_school_grade
    ON unit_curriculum_assignments(school_id, grade)
    WHERE grade IS NOT NULL;

CREATE INDEX idx_unit_curriculum_class
    ON unit_curriculum_assignments(class_id)
    WHERE class_id IS NOT NULL;

-- =============================================
-- RLS POLICIES
-- =============================================

ALTER TABLE unit_curriculum_assignments ENABLE ROW LEVEL SECURITY;

-- Admin full access (matches existing pattern in 20260131000008)
CREATE POLICY "unit_curriculum_admin_all"
    ON unit_curriculum_assignments FOR ALL
    USING (is_admin());

-- Authenticated users can read (needed for mobile app RPC)
CREATE POLICY "unit_curriculum_select_authenticated"
    ON unit_curriculum_assignments FOR SELECT
    USING (auth.uid() IS NOT NULL);

-- =============================================
-- TRIGGER: Auto-update updated_at
-- =============================================

CREATE TRIGGER unit_curriculum_updated_at
    BEFORE UPDATE ON unit_curriculum_assignments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

-- =============================================
-- RPC: Get assigned unit IDs for a user
-- Returns unit IDs the user has access to.
-- If NO assignments exist for the user's school,
-- returns ALL active units (backward compatible).
-- =============================================

CREATE OR REPLACE FUNCTION get_assigned_vocabulary_units(p_user_id UUID)
RETURNS TABLE(unit_id UUID) AS $$
DECLARE
    v_school_id UUID;
    v_class_id UUID;
    v_grade INTEGER;
    v_has_assignments BOOLEAN;
BEGIN
    -- Get user's school, class, and grade context
    SELECT p.school_id, p.class_id, c.grade
    INTO v_school_id, v_class_id, v_grade
    FROM profiles p
    LEFT JOIN classes c ON p.class_id = c.id
    WHERE p.id = p_user_id;

    -- No school → return all active units (no assignments possible)
    IF v_school_id IS NULL THEN
        RETURN QUERY
        SELECT vu.id FROM vocabulary_units vu
        WHERE vu.is_active = true
        ORDER BY vu.sort_order;
        RETURN;
    END IF;

    -- Check if ANY assignments exist for this school
    SELECT EXISTS(
        SELECT 1 FROM unit_curriculum_assignments
        WHERE school_id = v_school_id
    ) INTO v_has_assignments;

    -- No assignments → ALL active units (backward compatible)
    IF NOT v_has_assignments THEN
        RETURN QUERY
        SELECT vu.id FROM vocabulary_units vu
        WHERE vu.is_active = true
        ORDER BY vu.sort_order;
        RETURN;
    END IF;

    -- Assignments exist → return union of matching scopes
    RETURN QUERY
    SELECT DISTINCT uca.unit_id
    FROM unit_curriculum_assignments uca
    WHERE
        -- School-wide (grade IS NULL AND class_id IS NULL)
        (uca.school_id = v_school_id AND uca.grade IS NULL AND uca.class_id IS NULL)
        OR
        -- Grade-level (user has a class with matching grade)
        (uca.school_id = v_school_id AND uca.grade = v_grade AND v_grade IS NOT NULL)
        OR
        -- Class-specific (user belongs to that class)
        (uca.class_id = v_class_id AND v_class_id IS NOT NULL);

    RETURN;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION get_assigned_vocabulary_units IS
    'Returns vocabulary unit IDs accessible to user based on curriculum assignments. '
    'Returns all active units if no assignments exist for the school.';
