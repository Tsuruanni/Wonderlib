-- =============================================
-- Cross-reference comments on the two badge-check RPCs.
-- These functions share ~90 lines of identical evaluation logic.
-- A future change to ONE must be mirrored on the OTHER, or league-reset
-- (system variant) and client-trigger (auth variant) will silently diverge.
-- =============================================

COMMENT ON FUNCTION check_and_award_badges(UUID) IS
    'Client-callable badge evaluator with auth.uid() check. IMPORTANT: keep evaluation logic in sync with check_and_award_badges_system. When adding a new condition_type branch, edit BOTH functions.';

COMMENT ON FUNCTION check_and_award_badges_system(UUID) IS
    'Server-only badge evaluator (no auth check) for scheduled jobs and SECURITY DEFINER chains. Never expose via PostgREST or grant to anon/authenticated. IMPORTANT: keep evaluation logic in sync with check_and_award_badges. When adding a new condition_type branch, edit BOTH functions.';
