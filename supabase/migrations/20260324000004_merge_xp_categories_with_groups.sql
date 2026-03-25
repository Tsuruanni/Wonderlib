-- Add group_label and sort_order for sub-grouping within categories
ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS group_label TEXT;
ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS sort_order INTEGER DEFAULT 0;

-- ============================
-- Reading XP (merge xp + xp_inline → xp_reading)
-- ============================

-- Sub-group: Book & Chapter
UPDATE system_settings SET category = 'xp_reading', group_label = 'Book & Chapter', sort_order = 1 WHERE key = 'xp_chapter_complete';
UPDATE system_settings SET category = 'xp_reading', group_label = 'Book & Chapter', sort_order = 2 WHERE key = 'xp_book_complete';
UPDATE system_settings SET category = 'xp_reading', group_label = 'Book & Chapter', sort_order = 3 WHERE key = 'xp_quiz_pass';

-- Sub-group: Inline Activities
UPDATE system_settings SET category = 'xp_reading', group_label = 'Inline Activities', sort_order = 4 WHERE key = 'xp_inline_true_false';
UPDATE system_settings SET category = 'xp_reading', group_label = 'Inline Activities', sort_order = 5 WHERE key = 'xp_inline_word_translation';
UPDATE system_settings SET category = 'xp_reading', group_label = 'Inline Activities', sort_order = 6 WHERE key = 'xp_inline_find_words';
UPDATE system_settings SET category = 'xp_reading', group_label = 'Inline Activities', sort_order = 7 WHERE key = 'xp_inline_matching';

-- ============================
-- Vocab Session XP (merge xp_vocab + xp_bonus → xp_vocab)
-- ============================

-- Sub-group: Question Types
UPDATE system_settings SET group_label = 'Question Types', sort_order = 1 WHERE key = 'xp_vocab_multiple_choice';
UPDATE system_settings SET group_label = 'Question Types', sort_order = 2 WHERE key = 'xp_vocab_matching';
UPDATE system_settings SET group_label = 'Question Types', sort_order = 3 WHERE key = 'xp_vocab_scrambled_letters';
UPDATE system_settings SET group_label = 'Question Types', sort_order = 4 WHERE key = 'xp_vocab_spelling';
UPDATE system_settings SET group_label = 'Question Types', sort_order = 5 WHERE key = 'xp_vocab_sentence_gap';

-- Sub-group: Session Bonuses
UPDATE system_settings SET category = 'xp_vocab', group_label = 'Session Bonuses', sort_order = 6 WHERE key = 'combo_bonus_xp';
UPDATE system_settings SET category = 'xp_vocab', group_label = 'Session Bonuses', sort_order = 7 WHERE key = 'xp_vocab_session_bonus';
UPDATE system_settings SET category = 'xp_vocab', group_label = 'Session Bonuses', sort_order = 8 WHERE key = 'xp_vocab_perfect_bonus';

-- ============================
-- Other categories — set sort_order for consistent ordering
-- ============================
UPDATE system_settings SET sort_order = 1 WHERE key = 'streak_freeze_price';
UPDATE system_settings SET sort_order = 2 WHERE key = 'streak_freeze_max';
UPDATE system_settings SET sort_order = 1 WHERE key = 'debug_date_offset';
