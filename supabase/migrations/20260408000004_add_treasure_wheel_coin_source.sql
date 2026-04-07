-- Add 'treasure_wheel' to allowed coin_logs sources
ALTER TABLE coin_logs DROP CONSTRAINT IF EXISTS chk_coin_source;
ALTER TABLE coin_logs ADD CONSTRAINT chk_coin_source CHECK (
  source IN (
    'pack_purchase', 'daily_quest', 'streak_freeze',
    'vocabulary_session', 'daily_review', 'card_trade',
    'avatar_item', 'avatar_gender_change', 'treasure_wheel'
  )
) NOT VALID;
