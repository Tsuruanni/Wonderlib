-- =============================================
-- Fix: add 'badge' to coin_logs.chk_coin_source + re-run badge backfill
--
-- Root cause: award_xp_transaction inserts into coin_logs with source=p_source,
-- and the badge flow passes 'badge' as source. The CHECK constraint didn't
-- include 'badge', causing all RPC-triggered badge awards to fail with a
-- rolled-back transaction.
--
-- This migration:
-- 1. Drops and recreates chk_coin_source with 'badge' added.
-- 2. Re-runs the retroactive backfill loop. Users who already got backfilled
--    successfully in 20260416000001 are idempotent (ON CONFLICT DO NOTHING);
--    the 13 previously-failed users will now succeed.
-- =============================================

-- Part 1: extend CHECK constraint
ALTER TABLE coin_logs DROP CONSTRAINT IF EXISTS chk_coin_source;
ALTER TABLE coin_logs ADD CONSTRAINT chk_coin_source CHECK (
    source IN (
        'pack_purchase', 'daily_quest', 'streak_freeze',
        'vocabulary_session', 'daily_review', 'card_trade',
        'avatar_item', 'avatar_gender_change', 'treasure_wheel',
        'badge'
    )
) NOT VALID;

-- Part 2: re-run the backfill now that the constraint no longer blocks it
DO $$
DECLARE
    u RECORD;
    v_processed INTEGER := 0;
    v_failed INTEGER := 0;
BEGIN
    FOR u IN SELECT id FROM profiles LOOP
        BEGIN
            PERFORM check_and_award_badges_system(u.id);
            v_processed := v_processed + 1;
        EXCEPTION WHEN OTHERS THEN
            v_failed := v_failed + 1;
            RAISE NOTICE 'Re-backfill failed for user %: %', u.id, SQLERRM;
        END;
    END LOOP;

    RAISE NOTICE 'Badge re-backfill complete: % processed, % failed', v_processed, v_failed;
END $$;
