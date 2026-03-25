import 'package:equatable/equatable.dart';
import 'package:owlio_shared/owlio_shared.dart';

class LeaderboardEntry extends Equatable {
  const LeaderboardEntry({
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    this.avatarEquippedCache,
    required this.totalXp,
    required this.weeklyXp,
    required this.level,
    required this.rank,
    this.previousRank,
    this.className,
    required this.leagueTier,
  });

  final String userId;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final Map<String, dynamic>? avatarEquippedCache;
  final int totalXp;
  final int weeklyXp;
  final int level;
  final int rank;
  final int? previousRank;
  final String? className;
  final LeagueTier leagueTier;

  String get fullName => '$firstName $lastName';

  String get initials {
    final first = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final last = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$first$last';
  }

  /// Rank change from last week. Positive = improved, negative = dropped.
  /// Returns null if no previous rank data.
  int? get rankChange {
    if (previousRank == null) return null;
    return previousRank! - rank; // e.g., was 5, now 2 → +3 (improved)
  }

  @override
  List<Object?> get props => [
        userId,
        firstName,
        lastName,
        avatarUrl,
        avatarEquippedCache,
        totalXp,
        weeklyXp,
        level,
        rank,
        previousRank,
        className,
        leagueTier,
      ];
}
