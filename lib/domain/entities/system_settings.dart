import 'package:equatable/equatable.dart';

/// System-wide configuration settings entity
/// Only contains settings that are actively used at runtime
class SystemSettings extends Equatable {
  const SystemSettings({
    // XP Rewards
    this.xpChapterComplete = 50,
    this.xpBookComplete = 200,
    this.xpQuizPass = 20,
    // Inline Activity XP (per type)
    this.xpInlineTrueFalse = 25,
    this.xpInlineWordTranslation = 25,
    this.xpInlineFindWords = 25,
    this.xpInlineMatching = 25,
    // Vocab Question Type XP
    this.xpVocabMultipleChoice = 10,
    this.xpVocabMatching = 15,
    this.xpVocabScrambledLetters = 20,
    this.xpVocabSpelling = 25,
    this.xpVocabSentenceGap = 30,
    // Combo & Session Bonuses
    this.comboBonusXp = 5,
    this.xpVocabSessionBonus = 10,
    this.xpVocabPerfectBonus = 20,
    // Notifications
    this.notifStreakExtended = true,
    this.notifStreakBroken = true,
    this.notifStreakBrokenMin = 3,
    this.notifMilestone = true,
    this.notifLevelUp = true,
    this.notifLeagueChange = true,
    this.notifFreezeSaved = true,
    this.notifBadgeEarned = true,
    this.notifAssignment = true,
    // Streak
    this.streakFreezePrice = 50,
    this.streakFreezeMax = 2,
    // Debug
    this.debugDateOffset = 0,
  });

  // XP Rewards
  final int xpChapterComplete;
  final int xpBookComplete;
  final int xpQuizPass;

  // Inline Activity XP (per type)
  final int xpInlineTrueFalse;
  final int xpInlineWordTranslation;
  final int xpInlineFindWords;
  final int xpInlineMatching;

  // Vocab Question Type XP
  final int xpVocabMultipleChoice;
  final int xpVocabMatching;
  final int xpVocabScrambledLetters;
  final int xpVocabSpelling;
  final int xpVocabSentenceGap;

  // Combo & Session Bonuses
  final int comboBonusXp;
  final int xpVocabSessionBonus;
  final int xpVocabPerfectBonus;

  // Notifications
  final bool notifStreakExtended;
  final bool notifStreakBroken;
  final int notifStreakBrokenMin;
  final bool notifMilestone;
  final bool notifLevelUp;
  final bool notifLeagueChange;
  final bool notifFreezeSaved;
  final bool notifBadgeEarned;
  final bool notifAssignment;

  // Streak
  final int streakFreezePrice;
  final int streakFreezeMax;

  // Debug
  final int debugDateOffset;

  /// Default settings (fallback when database is unavailable)
  factory SystemSettings.defaults() => const SystemSettings();

  @override
  List<Object?> get props => [
        xpChapterComplete,
        xpBookComplete,
        xpQuizPass,
        xpInlineTrueFalse,
        xpInlineWordTranslation,
        xpInlineFindWords,
        xpInlineMatching,
        xpVocabMultipleChoice,
        xpVocabMatching,
        xpVocabScrambledLetters,
        xpVocabSpelling,
        xpVocabSentenceGap,
        comboBonusXp,
        xpVocabSessionBonus,
        xpVocabPerfectBonus,
        notifStreakExtended,
        notifStreakBroken,
        notifStreakBrokenMin,
        notifMilestone,
        notifLevelUp,
        notifLeagueChange,
        notifFreezeSaved,
        notifBadgeEarned,
        notifAssignment,
        streakFreezePrice,
        streakFreezeMax,
        debugDateOffset,
      ];
}
