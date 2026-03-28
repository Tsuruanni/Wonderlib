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
    required this.notifStreakExtended,
    required this.notifStreakBroken,
    required this.notifStreakBrokenMin,
    required this.notifMilestone,
    required this.notifLevelUp,
    required this.notifLeagueChange,
    required this.notifFreezeSaved,
    required this.notifBadgeEarned,
    required this.notifAssignment,
    required this.streakFreezePrice,
    required this.streakFreezeMax,
    required this.streakMilestones,
    required this.streakMilestoneRepeatInterval,
    required this.streakMilestoneRepeatXp,
    required this.debugDateOffset,
    required this.packCost,
    required this.xpActivityResultPerfect,
    required this.xpActivityResultGood,
    required this.xpActivityResultPass,
    required this.xpActivityResultParticipation,
    required this.xpDailyReviewCorrect,
    required this.activityPassThreshold,
    required this.activityExcellenceThreshold,
    required this.starRating3,
    required this.starRating2,
    required this.starRating1,
    required this.mockLibraryEnabled,
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
  final bool notifStreakExtended;
  final bool notifStreakBroken;
  final int notifStreakBrokenMin;
  final bool notifMilestone;
  final bool notifLevelUp;
  final bool notifLeagueChange;
  final bool notifFreezeSaved;
  final bool notifBadgeEarned;
  final bool notifAssignment;
  final int streakFreezePrice;
  final int streakFreezeMax;
  final Map<int, int> streakMilestones;
  final int streakMilestoneRepeatInterval;
  final int streakMilestoneRepeatXp;
  final int debugDateOffset;
  final int packCost;
  final int xpActivityResultPerfect;
  final int xpActivityResultGood;
  final int xpActivityResultPass;
  final int xpActivityResultParticipation;
  final int xpDailyReviewCorrect;
  final int activityPassThreshold;
  final int activityExcellenceThreshold;
  final int starRating3;
  final int starRating2;
  final int starRating1;
  final bool mockLibraryEnabled;

  /// Parse from database rows (key-value pairs)
  factory SystemSettingsModel.fromRows(List<Map<String, dynamic>> rows) {
    final map = <String, dynamic>{};
    for (final row in rows) {
      final key = row['key'] as String;
      map[key] = _parseJsonbValue(row['value']);
    }
    return SystemSettingsModel.fromMap(map);
  }

  /// Single source of truth for defaults — derived from entity
  static const _d = SystemSettings();

  /// Parse from key-value map
  factory SystemSettingsModel.fromMap(Map<String, dynamic> m) {
    return SystemSettingsModel(
      xpChapterComplete: _toInt(m['xp_chapter_complete'], _d.xpChapterComplete),
      xpBookComplete: _toInt(m['xp_book_complete'], _d.xpBookComplete),
      xpQuizPass: _toInt(m['xp_quiz_pass'], _d.xpQuizPass),
      xpInlineTrueFalse: _toInt(m['xp_inline_true_false'], _d.xpInlineTrueFalse),
      xpInlineWordTranslation: _toInt(m['xp_inline_word_translation'], _d.xpInlineWordTranslation),
      xpInlineFindWords: _toInt(m['xp_inline_find_words'], _d.xpInlineFindWords),
      xpInlineMatching: _toInt(m['xp_inline_matching'], _d.xpInlineMatching),
      xpVocabMultipleChoice: _toInt(m['xp_vocab_multiple_choice'], _d.xpVocabMultipleChoice),
      xpVocabMatching: _toInt(m['xp_vocab_matching'], _d.xpVocabMatching),
      xpVocabScrambledLetters: _toInt(m['xp_vocab_scrambled_letters'], _d.xpVocabScrambledLetters),
      xpVocabSpelling: _toInt(m['xp_vocab_spelling'], _d.xpVocabSpelling),
      xpVocabSentenceGap: _toInt(m['xp_vocab_sentence_gap'], _d.xpVocabSentenceGap),
      comboBonusXp: _toInt(m['combo_bonus_xp'], _d.comboBonusXp),
      xpVocabSessionBonus: _toInt(m['xp_vocab_session_bonus'], _d.xpVocabSessionBonus),
      xpVocabPerfectBonus: _toInt(m['xp_vocab_perfect_bonus'], _d.xpVocabPerfectBonus),
      notifStreakExtended: _toBool(m['notif_streak_extended'], _d.notifStreakExtended),
      notifStreakBroken: _toBool(m['notif_streak_broken'], _d.notifStreakBroken),
      notifStreakBrokenMin: _toInt(m['notif_streak_broken_min'], _d.notifStreakBrokenMin),
      notifMilestone: _toBool(m['notif_milestone'], _d.notifMilestone),
      notifLevelUp: _toBool(m['notif_level_up'], _d.notifLevelUp),
      notifLeagueChange: _toBool(m['notif_league_change'], _d.notifLeagueChange),
      notifFreezeSaved: _toBool(m['notif_freeze_saved'], _d.notifFreezeSaved),
      notifBadgeEarned: _toBool(m['notif_badge_earned'], _d.notifBadgeEarned),
      notifAssignment: _toBool(m['notif_assignment'], _d.notifAssignment),
      streakFreezePrice: _toInt(m['streak_freeze_price'], _d.streakFreezePrice),
      streakFreezeMax: _toInt(m['streak_freeze_max'], _d.streakFreezeMax),
      streakMilestones: _toIntMap(m['streak_milestones'], _d.streakMilestones),
      streakMilestoneRepeatInterval: _toInt(m['streak_milestone_repeat_interval'], _d.streakMilestoneRepeatInterval),
      streakMilestoneRepeatXp: _toInt(m['streak_milestone_repeat_xp'], _d.streakMilestoneRepeatXp),
      debugDateOffset: _toInt(m['debug_date_offset'], _d.debugDateOffset),
      packCost: _toInt(m['pack_cost'], _d.packCost),
      xpActivityResultPerfect: _toInt(m['xp_activity_result_perfect'], _d.xpActivityResultPerfect),
      xpActivityResultGood: _toInt(m['xp_activity_result_good'], _d.xpActivityResultGood),
      xpActivityResultPass: _toInt(m['xp_activity_result_pass'], _d.xpActivityResultPass),
      xpActivityResultParticipation: _toInt(m['xp_activity_result_participation'], _d.xpActivityResultParticipation),
      xpDailyReviewCorrect: _toInt(m['xp_daily_review_correct'], _d.xpDailyReviewCorrect),
      activityPassThreshold: _toInt(m['activity_pass_threshold'], _d.activityPassThreshold),
      activityExcellenceThreshold: _toInt(m['activity_excellence_threshold'], _d.activityExcellenceThreshold),
      starRating3: _toInt(m['star_rating_3'], _d.starRating3),
      starRating2: _toInt(m['star_rating_2'], _d.starRating2),
      starRating1: _toInt(m['star_rating_1'], _d.starRating1),
      mockLibraryEnabled: _toBool(m['mock_library_enabled'], _d.mockLibraryEnabled),
    );
  }

  /// Default model (fallback) — derives all values from entity defaults
  factory SystemSettingsModel.defaults() => SystemSettingsModel.fromMap({});

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
        notifStreakExtended: notifStreakExtended,
        notifStreakBroken: notifStreakBroken,
        notifStreakBrokenMin: notifStreakBrokenMin,
        notifMilestone: notifMilestone,
        notifLevelUp: notifLevelUp,
        notifLeagueChange: notifLeagueChange,
        notifFreezeSaved: notifFreezeSaved,
        notifBadgeEarned: notifBadgeEarned,
        notifAssignment: notifAssignment,
        streakFreezePrice: streakFreezePrice,
        streakFreezeMax: streakFreezeMax,
        streakMilestones: streakMilestones,
        streakMilestoneRepeatInterval: streakMilestoneRepeatInterval,
        streakMilestoneRepeatXp: streakMilestoneRepeatXp,
        debugDateOffset: debugDateOffset,
        packCost: packCost,
        xpActivityResultPerfect: xpActivityResultPerfect,
        xpActivityResultGood: xpActivityResultGood,
        xpActivityResultPass: xpActivityResultPass,
        xpActivityResultParticipation: xpActivityResultParticipation,
        xpDailyReviewCorrect: xpDailyReviewCorrect,
        activityPassThreshold: activityPassThreshold,
        activityExcellenceThreshold: activityExcellenceThreshold,
        starRating3: starRating3,
        starRating2: starRating2,
        starRating1: starRating1,
        mockLibraryEnabled: mockLibraryEnabled,
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

  static bool _toBool(dynamic v, bool defaultValue) {
    if (v == null) return defaultValue;
    if (v is bool) return v;
    if (v is String) return v == 'true';
    return defaultValue;
  }

  static Map<int, int> _toIntMap(dynamic v, Map<int, int> defaultValue) {
    if (v == null) return defaultValue;
    if (v is Map) {
      return v.map((k, v) => MapEntry(
        int.tryParse(k.toString()) ?? 0,
        _toInt(v, 0),
      ));
    }
    return defaultValue;
  }
}
