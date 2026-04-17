-- =============================================
-- Restore EXECUTE grants on RPCs recreated in 20260417 migrations.
-- DROP FUNCTION + CREATE FUNCTION drops GRANTs, so teachers got
-- "permission denied for function" errors on class overview.
-- =============================================

GRANT EXECUTE ON FUNCTION get_classes_with_stats(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_school_students_for_teacher(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_school_summary(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_global_student_averages() TO authenticated;
