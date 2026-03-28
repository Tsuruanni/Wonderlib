-- Auth Security Hardening
-- Fixes audit findings #10 and #11 from docs/specs/21-auth.md

-- =============================================
-- FIX #10: Force student role in handle_new_user trigger
-- Prevents privilege escalation via self-signup with role metadata
-- =============================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, first_name, last_name, email, role)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'first_name', 'User'),
        COALESCE(NEW.raw_user_meta_data->>'last_name', ''),
        NEW.email,
        'student'  -- Always student; admin/teacher creation goes through bulk-create edge function
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- FIX #11: Restrict profiles school-wide SELECT to teachers+
-- Students must use safe_profiles view for peer data
-- =============================================
DROP POLICY IF EXISTS "Users can view profiles in their school" ON profiles;

CREATE POLICY "Teachers can view profiles in their school"
    ON profiles FOR SELECT
    USING (
        is_teacher_or_higher()
        AND school_id = get_user_school_id()
    );
