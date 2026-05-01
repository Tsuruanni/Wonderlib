-- Add admin bypass for classes RLS.
-- Existing "Teachers can manage classes in their school" policy stays
-- intact; Postgres ORs multiple policies, so admin gains global access
-- without disturbing teacher scope. Mirrors the schools table pattern.

CREATE POLICY "Admins can manage all classes"
    ON classes FOR ALL
    USING (is_admin())
    WITH CHECK (is_admin());
