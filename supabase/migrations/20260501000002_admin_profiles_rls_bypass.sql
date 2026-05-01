-- Admin must see profiles across all schools to manage users
-- (single user create, list view, user detail). Existing
-- "Teachers can view profiles in their school" policy stays;
-- Postgres ORs them. Mirrors the classes admin bypass added in
-- 20260501000001.

CREATE POLICY "Admins can view all profiles"
    ON profiles FOR SELECT
    USING (is_admin());
