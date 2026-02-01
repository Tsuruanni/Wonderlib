-- =============================================
-- FIX: Assignment RLS Infinite Recursion
-- =============================================
-- Problem: Policies on assignments and assignment_students reference each other
-- Solution: Use SECURITY DEFINER functions to break the recursion chain

-- Drop problematic policies
DROP POLICY IF EXISTS "Teachers can manage own assignments" ON assignments;
DROP POLICY IF EXISTS "Teachers can view school assignments" ON assignments;
DROP POLICY IF EXISTS "Students can view assigned assignments" ON assignments;
DROP POLICY IF EXISTS "Teachers can manage assignment students" ON assignment_students;

-- Create helper function to check if user is assignment teacher
-- SECURITY DEFINER bypasses RLS for this function's queries
CREATE OR REPLACE FUNCTION is_assignment_teacher(assignment_id UUID)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM assignments a
        WHERE a.id = assignment_id
        AND a.teacher_id = auth.uid()
    );
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- Create helper function to check if user is assigned to assignment
CREATE OR REPLACE FUNCTION is_assigned_student(assignment_id UUID)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM assignment_students ast
        WHERE ast.assignment_id = $1
        AND ast.student_id = auth.uid()
    );
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- Create helper function to get assignment's teacher_id without recursion
CREATE OR REPLACE FUNCTION get_assignment_teacher_id(assignment_id UUID)
RETURNS UUID AS $$
    SELECT teacher_id FROM assignments WHERE id = assignment_id;
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- =============================================
-- ASSIGNMENT POLICIES (simplified)
-- =============================================

-- Teachers can do everything with their own assignments
CREATE POLICY "assignments_teacher_all"
    ON assignments FOR ALL
    USING (teacher_id = auth.uid() OR is_admin());

-- Students can only SELECT assignments they're assigned to
CREATE POLICY "assignments_student_select"
    ON assignments FOR SELECT
    USING (is_assigned_student(id));

-- =============================================
-- ASSIGNMENT_STUDENTS POLICIES (simplified)
-- =============================================

-- Teachers can manage students in their assignments
CREATE POLICY "assignment_students_teacher_all"
    ON assignment_students FOR ALL
    USING (
        get_assignment_teacher_id(assignment_id) = auth.uid()
        OR is_admin()
    );

-- Students can view their own assignment records
CREATE POLICY "assignment_students_student_select"
    ON assignment_students FOR SELECT
    USING (student_id = auth.uid());

-- Students can update their own progress
CREATE POLICY "assignment_students_student_update"
    ON assignment_students FOR UPDATE
    USING (student_id = auth.uid());
