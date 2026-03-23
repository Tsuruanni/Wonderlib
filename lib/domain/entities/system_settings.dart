import 'package:equatable/equatable.dart';

/// System-wide configuration settings entity
/// Only contains settings that are actively used at runtime
class SystemSettings extends Equatable {
  const SystemSettings({
    // XP Rewards
    this.xpChapterComplete = 50,
    this.xpBookComplete = 200,
    this.xpQuizPass = 20,
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
        streakFreezePrice,
        streakFreezeMax,
        debugDateOffset,
      ];
}
