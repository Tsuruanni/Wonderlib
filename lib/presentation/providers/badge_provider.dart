import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/badge.dart';
import 'auth_provider.dart';
import 'repository_providers.dart';

/// Provides all available badges
final allBadgesProvider = FutureProvider<List<Badge>>((ref) async {
  final badgeRepo = ref.watch(badgeRepositoryProvider);
  final result = await badgeRepo.getAllBadges();
  return result.fold(
    (failure) => [],
    (badges) => badges,
  );
});

/// Provides user's earned badges
final userBadgesProvider = FutureProvider<List<UserBadge>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final badgeRepo = ref.watch(badgeRepositoryProvider);
  final result = await badgeRepo.getUserBadges(userId);
  return result.fold(
    (failure) => [],
    (badges) => badges,
  );
});

/// Provides recently earned badges
final recentBadgesProvider = FutureProvider<List<Badge>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final badgeRepo = ref.watch(badgeRepositoryProvider);
  final result = await badgeRepo.getRecentlyEarned(userId: userId, limit: 3);
  return result.fold(
    (failure) => [],
    (badges) => badges,
  );
});

/// Provides badges that can be earned
final earnableBadgesProvider = FutureProvider<List<Badge>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final badgeRepo = ref.watch(badgeRepositoryProvider);
  final result = await badgeRepo.checkEarnableBadges(userId);
  return result.fold(
    (failure) => [],
    (badges) => badges,
  );
});

/// Badge controller for awarding badges
class BadgeController extends StateNotifier<BadgeState> {
  final Ref _ref;

  BadgeController(this._ref) : super(const BadgeState());

  Future<UserBadge?> awardBadge(String badgeId) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return null;

    state = state.copyWith(isAwarding: true);

    final badgeRepo = _ref.read(badgeRepositoryProvider);
    final result = await badgeRepo.awardBadge(
      userId: userId,
      badgeId: badgeId,
    );

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
  final bool isAwarding;
  final String? error;
  final UserBadge? recentlyAwarded;

  const BadgeState({
    this.isAwarding = false,
    this.error,
    this.recentlyAwarded,
  });

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
