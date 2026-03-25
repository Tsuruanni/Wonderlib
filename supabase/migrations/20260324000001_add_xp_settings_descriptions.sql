-- Add descriptions to type-based XP settings for admin panel clarity
UPDATE system_settings SET description = 'XP for completing a chapter' WHERE key = 'xp_chapter_complete';
UPDATE system_settings SET description = 'XP for completing an entire book' WHERE key = 'xp_book_complete';
UPDATE system_settings SET description = 'XP for passing a book quiz' WHERE key = 'xp_quiz_pass';

-- Inline activity XP (per type)
UPDATE system_settings SET description = 'XP for True/False inline activities' WHERE key = 'xp_inline_true_false';
UPDATE system_settings SET description = 'XP for Word Translation inline activities' WHERE key = 'xp_inline_word_translation';
UPDATE system_settings SET description = 'XP for Find Words inline activities' WHERE key = 'xp_inline_find_words';
UPDATE system_settings SET description = 'XP for Matching inline activities' WHERE key = 'xp_inline_matching';

-- Vocab question type XP
UPDATE system_settings SET description = 'XP for multiple choice / listening select / image match questions' WHERE key = 'xp_vocab_multiple_choice';
UPDATE system_settings SET description = 'XP for matching questions' WHERE key = 'xp_vocab_matching';
UPDATE system_settings SET description = 'XP for scrambled letters / word wheel questions' WHERE key = 'xp_vocab_scrambled_letters';
UPDATE system_settings SET description = 'XP for spelling / listening write questions' WHERE key = 'xp_vocab_spelling';
UPDATE system_settings SET description = 'XP for sentence gap / pronunciation questions' WHERE key = 'xp_vocab_sentence_gap';

-- Combo & session bonuses
UPDATE system_settings SET description = 'XP per combo count at session end (maxCombo × this value)' WHERE key = 'combo_bonus_xp';
UPDATE system_settings SET description = 'Bonus XP for completing any vocab session' WHERE key = 'xp_vocab_session_bonus';
UPDATE system_settings SET description = 'Extra bonus XP for 100% accuracy session' WHERE key = 'xp_vocab_perfect_bonus';

-- Existing settings
UPDATE system_settings SET description = 'Coin cost to buy one streak freeze' WHERE key = 'streak_freeze_price';
UPDATE system_settings SET description = 'Maximum streak freezes a user can hold' WHERE key = 'streak_freeze_max';
UPDATE system_settings SET description = 'Shift app date by N days (testing only)' WHERE key = 'debug_date_offset';
