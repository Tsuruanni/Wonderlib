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
    // Streak Milestones
    this.streakMilestones = const {7: 50, 14: 100, 30: 200, 60: 400, 100: 1000},
    this.streakMilestoneRepeatInterval = 100,
    this.streakMilestoneRepeatXp = 1000,
    // Debug
    this.debugDateOffset = 0,
    // Card economy
    this.packCost = 100,
    // Activity result XP tiers
    this.xpActivityResultPerfect = 10,
    this.xpActivityResultGood = 7,
    this.xpActivityResultPass = 5,
    this.xpActivityResultParticipation = 2,
    // Daily review
    this.xpDailyReviewCorrect = 5,
    // Activity thresholds
    this.activityPassThreshold = 60,
    this.activityExcellenceThreshold = 90,
    // Star rating thresholds
    this.starRating3 = 90,
    this.starRating2 = 70,
    this.starRating1 = 50,
    // Mock library
    this.mockLibraryEnabled = false,
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

  // Streak Milestones
  final Map<int, int> streakMilestones;
  final int streakMilestoneRepeatInterval;
  final int streakMilestoneRepeatXp;

  // Debug
  final int debugDateOffset;

  // Card economy
  final int packCost;

  // Activity result XP tiers
  final int xpActivityResultPerfect;
  final int xpActivityResultGood;
  final int xpActivityResultPass;
  final int xpActivityResultParticipation;

  // Daily review
  final int xpDailyReviewCorrect;

  // Activity thresholds
  final int activityPassThreshold;
  final int activityExcellenceThreshold;

  // Star rating thresholds
  final int starRating3;
  final int starRating2;
  final int starRating1;

  // Mock library
  final bool mockLibraryEnabled;

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
        streakMilestones,
        streakMilestoneRepeatInterval,
        streakMilestoneRepeatXp,
        debugDateOffset,
        packCost,
        xpActivityResultPerfect,
        xpActivityResultGood,
        xpActivityResultPass,
        xpActivityResultParticipation,
        xpDailyReviewCorrect,
        activityPassThreshold,
        activityExcellenceThreshold,
        starRating3,
        starRating2,
        starRating1,
        mockLibraryEnabled,
      ];
}
