import 'package:equatable/equatable.dart';

class StreakResult extends Equatable {
  const StreakResult({
    required this.newStreak,
    required this.longestStreak,
    this.streakBroken = false,
    this.streakExtended = false,
    this.freezeUsed = false,
    this.freezesConsumed = 0,
    this.freezesRemaining = 0,
    this.milestoneBonusXp = 0,
  });

  final int newStreak;
  final int longestStreak;
  final bool streakBroken;
  final bool streakExtended;
  final bool freezeUsed;
  final int freezesConsumed;
  final int freezesRemaining;
  final int milestoneBonusXp;

  bool get hasEvent => milestoneBonusXp > 0 || freezeUsed || streakBroken;

  @override
  List<Object?> get props => [
        newStreak, longestStreak, streakBroken, streakExtended,
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
