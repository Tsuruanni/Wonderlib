-- Type-based XP settings: inline activities, vocab question types, combo bonus, session bonuses
INSERT INTO system_settings (key, value, category) VALUES
  -- Inline activity XP (per type)
  ('xp_inline_true_false', '"25"', 'xp'),
  ('xp_inline_word_translation', '"25"', 'xp'),
  ('xp_inline_find_words', '"25"', 'xp'),
  ('xp_inline_matching', '"25"', 'xp'),
  -- Vocab question type XP (grouped by difficulty)
  ('xp_vocab_multiple_choice', '"10"', 'xp'),
  ('xp_vocab_matching', '"15"', 'xp'),
  ('xp_vocab_scrambled_letters', '"20"', 'xp'),
  ('xp_vocab_spelling', '"25"', 'xp'),
  ('xp_vocab_sentence_gap', '"30"', 'xp'),
  -- Combo bonus (session-end: maxCombo × this value)
  ('combo_bonus_xp', '"5"', 'xp'),
  -- Vocab session bonuses (read by RPC)
  ('xp_vocab_session_bonus', '"10"', 'xp'),
  ('xp_vocab_perfect_bonus', '"20"', 'xp')
ON CONFLICT (key) DO NOTHING;
