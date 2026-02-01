import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/badge.dart';
import '../../domain/usecases/badge/award_badge_usecase.dart';
import '../../domain/usecases/badge/check_earnable_badges_usecase.dart';
import '../../domain/usecases/badge/get_recently_earned_usecase.dart';
import '../../domain/usecases/badge/get_user_badges_usecase.dart';
import '../../domain/usecases/usecase.dart';
import 'auth_provider.dart';
import 'usecase_providers.dart';

/// Provides all available badges
final allBadgesProvider = FutureProvider<List<Badge>>((ref) async {
  final useCase = ref.watch(getAllBadgesUseCaseProvider);
  final result = await useCase(const NoParams());
  return result.fold(
    (failure) => [],
    (badges) => badges,
  );
});

/// Provides user's earned badges
final userBadgesProvider = FutureProvider<List<UserBadge>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final useCase = ref.watch(getUserBadgesUseCaseProvider);
  final result = await useCase(GetUserBadgesParams(userId: userId));
  return result.fold(
    (failure) => [],
    (badges) => badges,
  );
});

/// Provides recently earned badges
final recentBadgesProvider = FutureProvider<List<Badge>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final useCase = ref.watch(getRecentlyEarnedUseCaseProvider);
  final result = await useCase(GetRecentlyEarnedParams(userId: userId, limit: 3));
  return result.fold(
    (failure) => [],
    (badges) => badges,
  );
});

/// Provides badges that can be earned
final earnableBadgesProvider = FutureProvider<List<Badge>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final useCase = ref.watch(checkEarnableBadgesUseCaseProvider);
  final result = await useCase(CheckEarnableBadgesParams(userId: userId));
  return result.fold(
    (failure) => [],
    (badges) => badges,
  );
});

/// Badge controller for awarding badges
class BadgeController extends StateNotifier<BadgeState> {

  BadgeController(this._ref) : super(const BadgeState());
  final Ref _ref;

  Future<UserBadge?> awardBadge(String badgeId) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return null;

    state = state.copyWith(isAwarding: true);

    final useCase = _ref.read(awardBadgeUseCaseProvider);
    final result = await useCase(AwardBadgeParams(
      userId: userId,
      badgeId: badgeId,
    ),);

    return result.fold(
      (failure) {
        state = state.copyWith(isAwarding: false, error: failure.message);
        return null;
      },
      (userBadge) {
        state = state.copyWith(
          isAwarding: false,
          recentlyAwarded: userBadge,
        );
        // Invalidate badge providers to refresh
        _ref.invalidate(userBadgesProvider);
        _ref.invalidate(recentBadgesProvider);
        return userBadge;
      },
    );
  }

  void clearRecentlyAwarded() {
    state = state.copyWith(recentlyAwarded: null);
  }
}

class BadgeState {

  const BadgeState({
    this.isAwarding = false,
    this.error,
    this.recentlyAwarded,
  });
  final bool isAwarding;
  final String? error;
  final UserBadge? recentlyAwarded;

  BadgeState copyWith({
    bool? isAwarding,
    String? error,
    UserBadge? recentlyAwarded,
  }) {
    return BadgeState(
      isAwarding: isAwarding ?? this.isAwarding,
      error: error,
      recentlyAwarded: recentlyAwarded,
    );
  }
}

final badgeControllerProvider =
    StateNotifierProvider<BadgeController, BadgeState>((ref) {
  return BadgeController(ref);
});
