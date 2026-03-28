import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/badge.dart';
import '../../domain/entities/card.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/badge/get_user_badges_usecase.dart';
import '../../domain/usecases/card/get_user_card_stats_usecase.dart';
import '../../domain/usecases/user/get_user_by_id_usecase.dart';
import 'usecase_providers.dart';

/// Combined data for the student profile popup.
class StudentProfileExtra {
  const StudentProfileExtra({
    required this.user,
    required this.cardStats,
    required this.badges,
  });

  final User user;
  final UserCardStats cardStats;
  final List<UserBadge> badges;
}

/// Fetches a student's profile + card stats + badges for the popup dialog.
/// Keyed by userId. Card stats and badge failures are graceful (fall back to empty).
final studentProfileExtraProvider =
    FutureProvider.autoDispose.family<StudentProfileExtra, String>(
  (ref, userId) async {
    final userUseCase = ref.watch(getUserByIdUseCaseProvider);
    final cardStatsUseCase = ref.watch(getUserCardStatsUseCaseProvider);
    final badgesUseCase = ref.watch(getUserBadgesUseCaseProvider);

    final (userResult, cardStatsResult, badgesResult) = await (
      userUseCase(GetUserByIdParams(userId: userId)),
      cardStatsUseCase(GetUserCardStatsParams(userId: userId)),
      badgesUseCase(GetUserBadgesParams(userId: userId)),
    ).wait;

    final user = userResult.fold(
      (failure) => throw Exception('Failed to load profile'),
      (u) => u,
    );

    final cardStats = cardStatsResult.fold(
      (_) => UserCardStats(userId: userId),
      (s) => s,
    );

    final badges = badgesResult.fold(
      (_) => <UserBadge>[],
      (b) => b,
    );

    return StudentProfileExtra(
      user: user,
      cardStats: cardStats,
      badges: badges,
    );
  },
);
