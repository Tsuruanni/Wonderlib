-- Group XP settings into sub-categories for admin panel clarity
UPDATE system_settings SET category = 'xp_inline' WHERE key IN (
  'xp_inline_true_false',
  'xp_inline_word_translation',
  'xp_inline_find_words',
  'xp_inline_matching'
);

UPDATE system_settings SET category = 'xp_vocab' WHERE key IN (
  'xp_vocab_multiple_choice',
  'xp_vocab_matching',
  'xp_vocab_scrambled_letters',
  'xp_vocab_spelling',
  'xp_vocab_sentence_gap'
);

UPDATE system_settings SET category = 'xp_bonus' WHERE key IN (
  'combo_bonus_xp',
  'xp_vocab_session_bonus',
  'xp_vocab_perfect_bonus'
);
-- Remaining xp keys (xp_chapter_complete, xp_book_complete, xp_quiz_pass) stay as 'xp'
