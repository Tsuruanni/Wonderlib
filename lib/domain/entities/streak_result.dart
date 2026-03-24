import 'package:equatable/equatable.dart';

class StreakResult extends Equatable {
  const StreakResult({
    required this.newStreak,
    required this.longestStreak,
    this.previousStreak = 0,
    this.streakBroken = false,
    this.streakExtended = false,
    this.freezeUsed = false,
    this.freezesConsumed = 0,
    this.freezesRemaining = 0,
    this.milestoneBonusXp = 0,
  });

  final int newStreak;
  final int longestStreak;
  final int previousStreak;
  final bool streakBroken;
  final bool streakExtended;
  final bool freezeUsed;
  final int freezesConsumed;
  final int freezesRemaining;
  final int milestoneBonusXp;

  /// Show event dialog? Streak extended always. Milestone and freeze always.
  /// Streak broken only if >= 3 days (default, overridable via settings).
  bool get hasEvent =>
      streakExtended ||
      milestoneBonusXp > 0 || freezeUsed || (streakBroken && previousStreak >= 3);

  @override
  List<Object?> get props => [
        newStreak, longestStreak, previousStreak, streakBroken, streakExtended,
        freezeUsed, freezesConsumed, freezesRemaining, milestoneBonusXp,
      ];
}

class BuyFreezeResult {
  const BuyFreezeResult({
    required this.freezeCount,
    required this.coinsRemaining,
  });

  final int freezeCount;
  final int coinsRemaining;
}
