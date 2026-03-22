-- Grant admin SELECT access to student progress and audit tables
-- Required for: admin panel "Son Etkinlikler" (recent activity) page

CREATE POLICY "Admins can view all inline activity results"
    ON inline_activity_results FOR SELECT
    USING (is_admin());

CREATE POLICY "Admins can view all reading progress"
    ON reading_progress FOR SELECT
    USING (is_admin());

CREATE POLICY "Admins can view all xp logs"
    ON xp_logs FOR SELECT
    USING (is_admin());
