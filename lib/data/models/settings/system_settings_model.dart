import '../../../domain/entities/system_settings.dart';

/// Model for system settings with JSON serialization
class SystemSettingsModel {
  const SystemSettingsModel({
    required this.xpChapterComplete,
    required this.xpBookComplete,
    required this.xpQuizPass,
    required this.xpInlineTrueFalse,
    required this.xpInlineWordTranslation,
    required this.xpInlineFindWords,
    required this.xpInlineMatching,
    required this.xpVocabMultipleChoice,
    required this.xpVocabMatching,
    required this.xpVocabScrambledLetters,
    required this.xpVocabSpelling,
    required this.xpVocabSentenceGap,
    required this.comboBonusXp,
    required this.xpVocabSessionBonus,
    required this.xpVocabPerfectBonus,
    required this.streakFreezePrice,
    required this.streakFreezeMax,
    required this.debugDateOffset,
  });

  final int xpChapterComplete;
  final int xpBookComplete;
  final int xpQuizPass;
  final int xpInlineTrueFalse;
  final int xpInlineWordTranslation;
  final int xpInlineFindWords;
  final int xpInlineMatching;
  final int xpVocabMultipleChoice;
  final int xpVocabMatching;
  final int xpVocabScrambledLetters;
  final int xpVocabSpelling;
  final int xpVocabSentenceGap;
  final int comboBonusXp;
  final int xpVocabSessionBonus;
  final int xpVocabPerfectBonus;
  final int streakFreezePrice;
  final int streakFreezeMax;
  final int debugDateOffset;

  /// Parse from database rows (key-value pairs)
  factory SystemSettingsModel.fromRows(List<Map<String, dynamic>> rows) {
    final map = <String, dynamic>{};
    for (final row in rows) {
      final key = row['key'] as String;
      map[key] = _parseJsonbValue(row['value']);
    }
    return SystemSettingsModel.fromMap(map);
  }

  /// Parse from key-value map
  factory SystemSettingsModel.fromMap(Map<String, dynamic> m) {
    return SystemSettingsModel(
      xpChapterComplete: _toInt(m['xp_chapter_complete'], 50),
      xpBookComplete: _toInt(m['xp_book_complete'], 200),
      xpQuizPass: _toInt(m['xp_quiz_pass'], 20),
      xpInlineTrueFalse: _toInt(m['xp_inline_true_false'], 25),
      xpInlineWordTranslation: _toInt(m['xp_inline_word_translation'], 25),
      xpInlineFindWords: _toInt(m['xp_inline_find_words'], 25),
      xpInlineMatching: _toInt(m['xp_inline_matching'], 25),
      xpVocabMultipleChoice: _toInt(m['xp_vocab_multiple_choice'], 10),
      xpVocabMatching: _toInt(m['xp_vocab_matching'], 15),
      xpVocabScrambledLetters: _toInt(m['xp_vocab_scrambled_letters'], 20),
      xpVocabSpelling: _toInt(m['xp_vocab_spelling'], 25),
      xpVocabSentenceGap: _toInt(m['xp_vocab_sentence_gap'], 30),
      comboBonusXp: _toInt(m['combo_bonus_xp'], 5),
      xpVocabSessionBonus: _toInt(m['xp_vocab_session_bonus'], 10),
      xpVocabPerfectBonus: _toInt(m['xp_vocab_perfect_bonus'], 20),
      streakFreezePrice: _toInt(m['streak_freeze_price'], 50),
      streakFreezeMax: _toInt(m['streak_freeze_max'], 2),
      debugDateOffset: _toInt(m['debug_date_offset'], 0),
    );
  }

  /// Default model (fallback)
  factory SystemSettingsModel.defaults() => const SystemSettingsModel(
        xpChapterComplete: 50,
        xpBookComplete: 200,
        xpQuizPass: 20,
        xpInlineTrueFalse: 25,
        xpInlineWordTranslation: 25,
        xpInlineFindWords: 25,
        xpInlineMatching: 25,
        xpVocabMultipleChoice: 10,
        xpVocabMatching: 15,
        xpVocabScrambledLetters: 20,
        xpVocabSpelling: 25,
        xpVocabSentenceGap: 30,
        comboBonusXp: 5,
        xpVocabSessionBonus: 10,
        xpVocabPerfectBonus: 20,
        streakFreezePrice: 50,
        streakFreezeMax: 2,
        debugDateOffset: 0,
      );

  /// Convert to entity
  SystemSettings toEntity() => SystemSettings(
        xpChapterComplete: xpChapterComplete,
        xpBookComplete: xpBookComplete,
        xpQuizPass: xpQuizPass,
        xpInlineTrueFalse: xpInlineTrueFalse,
        xpInlineWordTranslation: xpInlineWordTranslation,
        xpInlineFindWords: xpInlineFindWords,
        xpInlineMatching: xpInlineMatching,
        xpVocabMultipleChoice: xpVocabMultipleChoice,
        xpVocabMatching: xpVocabMatching,
        xpVocabScrambledLetters: xpVocabScrambledLetters,
        xpVocabSpelling: xpVocabSpelling,
        xpVocabSentenceGap: xpVocabSentenceGap,
        comboBonusXp: comboBonusXp,
        xpVocabSessionBonus: xpVocabSessionBonus,
        xpVocabPerfectBonus: xpVocabPerfectBonus,
        streakFreezePrice: streakFreezePrice,
        streakFreezeMax: streakFreezeMax,
        debugDateOffset: debugDateOffset,
      );

  /// Create model from entity
  factory SystemSettingsModel.fromEntity(SystemSettings e) =>
      SystemSettingsModel(
        xpChapterComplete: e.xpChapterComplete,
        xpBookComplete: e.xpBookComplete,
        xpQuizPass: e.xpQuizPass,
        xpInlineTrueFalse: e.xpInlineTrueFalse,
        xpInlineWordTranslation: e.xpInlineWordTranslation,
        xpInlineFindWords: e.xpInlineFindWords,
        xpInlineMatching: e.xpInlineMatching,
        xpVocabMultipleChoice: e.xpVocabMultipleChoice,
        xpVocabMatching: e.xpVocabMatching,
        xpVocabScrambledLetters: e.xpVocabScrambledLetters,
        xpVocabSpelling: e.xpVocabSpelling,
        xpVocabSentenceGap: e.xpVocabSentenceGap,
        comboBonusXp: e.comboBonusXp,
        xpVocabSessionBonus: e.xpVocabSessionBonus,
        xpVocabPerfectBonus: e.xpVocabPerfectBonus,
        streakFreezePrice: e.streakFreezePrice,
        streakFreezeMax: e.streakFreezeMax,
        debugDateOffset: e.debugDateOffset,
      );

  // Helper: Parse JSONB value (removes quotes, converts types)
  static dynamic _parseJsonbValue(dynamic v) {
    if (v is! String) return v;
    final s = v.replaceAll('"', '');
    if (s == 'true') return true;
    if (s == 'false') return false;
    return int.tryParse(s) ?? double.tryParse(s) ?? s;
  }

  static int _toInt(dynamic v, int defaultValue) {
    if (v == null) return defaultValue;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? defaultValue;
    return defaultValue;
  }
}
