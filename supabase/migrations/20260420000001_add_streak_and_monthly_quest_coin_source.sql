-- =============================================
-- Fix: add 'streak_milestone' and 'monthly_quest' to coin_logs.chk_coin_source
--
-- Root cause: award_xp_transaction inserts into coin_logs with source=p_source.
-- update_user_streak passes 'streak_milestone' (in 20260405000001) and
-- monthly-quest awards pass 'monthly_quest', but neither was in the CHECK
-- constraint. Every streak-milestone and monthly-quest award therefore
-- rolled back the transaction, including the streak update itself.
--
-- Observed error:
--   new row for relation "coin_logs" violates check constraint "chk_coin_source"
-- =============================================

ALTER TABLE coin_logs DROP CONSTRAINT IF EXISTS chk_coin_source;
ALTER TABLE coin_logs ADD CONSTRAINT chk_coin_source CHECK (
    source IN (
        'pack_purchase', 'daily_quest', 'streak_freeze',
        'vocabulary_session', 'daily_review', 'card_trade',
        'avatar_item', 'avatar_gender_change', 'treasure_wheel',
        'badge', 'streak_milestone', 'monthly_quest'
    )
) NOT VALID;
