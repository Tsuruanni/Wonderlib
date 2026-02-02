import 'package:equatable/equatable.dart';

/// System-wide configuration settings entity
/// Used for XP rewards, progression, game settings, and app configuration
class SystemSettings extends Equatable {
  const SystemSettings({
    // XP Rewards
    this.xpChapterComplete = 50,
    this.xpActivityComplete = 20,
    this.xpActivityPerfect = 30,
    this.xpWordLearned = 5,
    this.xpWordMastered = 15,
    this.xpBookComplete = 200,
    this.xpStreakBonusDay = 10,
    this.xpAssignmentComplete = 100,
    // Progression
    this.maxStreakMultiplier = 2.0,
    this.streakBonusIncrement = 0.1,
    this.dailyXpCap = 1000,
    // Game
    this.defaultTimeLimit = 60,
    this.hintPenaltyPercent = 10,
    this.skipPenaltyPercent = 50,
    // App
    this.maintenanceMode = false,
    this.minAppVersion = '1.0.0',
    this.featureWordLists = true,
    this.featureAchievements = true,
  });

  // XP Rewards
  final int xpChapterComplete;
  final int xpActivityComplete;
  final int xpActivityPerfect;
  final int xpWordLearned;
  final int xpWordMastered;
  final int xpBookComplete;
  final int xpStreakBonusDay;
  final int xpAssignmentComplete;

  // Progression
  final double maxStreakMultiplier;
  final double streakBonusIncrement;
  final int dailyXpCap;

  // Game
  final int defaultTimeLimit;
  final int hintPenaltyPercent;
  final int skipPenaltyPercent;

  // App
  final bool maintenanceMode;
  final String minAppVersion;
  final bool featureWordLists;
  final bool featureAchievements;

  /// Default settings (fallback when database is unavailable)
  factory SystemSettings.defaults() => const SystemSettings();

  @override
  List<Object?> get props => [
        xpChapterComplete,
        xpActivityComplete,
        xpActivityPerfect,
        xpWordLearned,
        xpWordMastered,
        xpBookComplete,
        xpStreakBonusDay,
        xpAssignmentComplete,
        maxStreakMultiplier,
        streakBonusIncrement,
        dailyXpCap,
        defaultTimeLimit,
        hintPenaltyPercent,
        skipPenaltyPercent,
        maintenanceMode,
        minAppVersion,
        featureWordLists,
        featureAchievements,
      ];
}
