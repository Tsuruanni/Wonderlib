-- =============================================
-- One-time Backfill: retroactive badge awards for all existing users.
--
-- Why: badge trigger points (addXP, open_card_pack, league reset, vocab session)
-- only fire on new actions. Users who accumulated XP/streak/cards/level/tier
-- before the relevant badge existed (or before triggers were wired) never got
-- those badges. This migration loops every profile and invokes
-- `check_and_award_badges_system` which is idempotent via ON CONFLICT DO NOTHING.
--
-- XP side-effect: badge XP rewards are awarded via award_xp_transaction inside
-- the RPC. Profile XP will jump for users who earn multiple catchup badges.
-- Accepted for pre-production test data.
--
-- Safety: wrapped in BEGIN/EXCEPTION per user so one failure doesn't abort the
-- whole batch. Logs a RAISE NOTICE for each user processed.
-- =============================================

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
            RAISE NOTICE 'Backfill failed for user %: %', u.id, SQLERRM;
        END;
    END LOOP;

    RAISE NOTICE 'Badge backfill complete: % processed, % failed', v_processed, v_failed;
END $$;
