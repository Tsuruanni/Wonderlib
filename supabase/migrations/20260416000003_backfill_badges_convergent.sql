-- =============================================
-- Convergent Backfill: re-runs badge check per user up to 5 times to catch
-- cascading XP-triggered badges.
--
-- Why: badge XP rewards (via award_xp_transaction inside check_and_award_badges)
-- can push the user's XP past higher XP badge thresholds. Single-pass backfill
-- misses these. We loop until either no new badges are awarded, or the safety
-- cap of 5 iterations is reached.
--
-- Idempotent: ON CONFLICT DO NOTHING in user_badges + the convergence check
-- means already-stable users do nothing on re-runs.
-- =============================================

DO $$
DECLARE
    u RECORD;
    v_total_processed INTEGER := 0;
    v_total_iterations INTEGER := 0;
    v_total_new_badges INTEGER := 0;
    v_pass_count INTEGER;
    v_new_count INTEGER;
    v_max_passes CONSTANT INTEGER := 5;
BEGIN
    FOR u IN SELECT id FROM profiles LOOP
        v_pass_count := 0;
        LOOP
            v_pass_count := v_pass_count + 1;
            IF v_pass_count > v_max_passes THEN
                EXIT;
            END IF;
            BEGIN
                SELECT COUNT(*) INTO v_new_count
                FROM check_and_award_badges_system(u.id);
            EXCEPTION WHEN OTHERS THEN
                v_new_count := 0;
                RAISE NOTICE 'Convergent backfill failed for user %: %', u.id, SQLERRM;
                EXIT;
            END;
            v_total_iterations := v_total_iterations + 1;
            v_total_new_badges := v_total_new_badges + v_new_count;
            -- Convergence: no new badges this pass, stop.
            IF v_new_count = 0 THEN
                EXIT;
            END IF;
        END LOOP;
        v_total_processed := v_total_processed + 1;
    END LOOP;

    RAISE NOTICE 'Convergent backfill complete: % users, % total iterations, % new badges awarded',
        v_total_processed, v_total_iterations, v_total_new_badges;
END $$;
