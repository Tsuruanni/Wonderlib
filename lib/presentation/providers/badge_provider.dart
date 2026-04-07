import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/badge.dart';
import '../../domain/usecases/badge/get_recently_earned_usecase.dart';
import '../../domain/usecases/badge/get_user_badges_usecase.dart';
import '../../domain/usecases/usecase.dart';
import 'auth_provider.dart';
import 'usecase_providers.dart';

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

/// Provides all active badges (for showing earned vs unearned)
final allBadgesProvider = FutureProvider<List<Badge>>((ref) async {
  final useCase = ref.watch(getAllBadgesUseCaseProvider);
  final result = await useCase(const NoParams());
  return result.fold(
    (failure) => [],
    (badges) => badges,
  );
});

