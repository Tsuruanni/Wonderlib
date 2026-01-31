import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/user.dart';
import 'auth_provider.dart';
import 'repository_providers.dart';

/// Provides user stats for current user
final userStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return {};

  final userRepo = ref.watch(userRepositoryProvider);
  final result = await userRepo.getUserStats(userId);
  return result.fold(
    (failure) => {},
    (stats) => stats,
  );
});

/// Provides leaderboard
final leaderboardProvider = FutureProvider.family<List<User>, LeaderboardParams?>((ref, params) async {
  final userRepo = ref.watch(userRepositoryProvider);
  final result = await userRepo.getLeaderboard(
    schoolId: params?.schoolId,
    classId: params?.classId,
    limit: params?.limit ?? 10,
  );
  return result.fold(
    (failure) => [],
    (users) => users,
  );
});

/// Provides classmates
final classmatesProvider = FutureProvider<List<User>>((ref) async {
  final user = ref.watch(authStateChangesProvider).valueOrNull;
  if (user == null || user.classId == null) return [];

  final userRepo = ref.watch(userRepositoryProvider);
  final result = await userRepo.getClassmates(user.classId!);
  return result.fold(
    (failure) => [],
    (users) => users,
  );
});

/// Leaderboard params
class LeaderboardParams {
  final String? schoolId;
  final String? classId;
  final int limit;

  const LeaderboardParams({
    this.schoolId,
    this.classId,
    this.limit = 10,
  });
}

/// User controller for XP and streak updates
class UserController extends StateNotifier<AsyncValue<User?>> {
  final Ref _ref;

  UserController(this._ref) : super(const AsyncValue.loading()) {
    // Watch auth state changes and reload user when it changes
    _ref.listen(authStateChangesProvider, (previous, next) {
      final newUserId = next.valueOrNull?.id;
      final oldUserId = previous?.valueOrNull?.id;

      if (newUserId != oldUserId) {
        _loadUser();
      }
    });

    _loadUser();
  }

  Future<void> _loadUser() async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) {
      state = const AsyncValue.data(null);
      return;
    }

    state = const AsyncValue.loading();

    final userRepo = _ref.read(userRepositoryProvider);
    final result = await userRepo.getUserById(userId);

    state = result.fold(
      (failure) => AsyncValue.error(failure.message, StackTrace.current),
      (user) => AsyncValue.data(user),
    );
  }

  Future<void> addXP(int amount) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;

    final userRepo = _ref.read(userRepositoryProvider);
    final result = await userRepo.addXP(userId, amount);

    result.fold(
      (failure) => null,
      (user) {
        state = AsyncValue.data(user);
      },
    );
    // Note: Badge checking is handled by the check_and_award_badges RPC
    // called within SupabaseUserRepository.addXP()
  }

  Future<void> updateStreak() async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;

    final userRepo = _ref.read(userRepositoryProvider);
    final result = await userRepo.updateStreak(userId);

    result.fold(
      (failure) => null,
      (user) {
        state = AsyncValue.data(user);
      },
    );
  }

  void refresh() {
    _loadUser();
  }
}

final userControllerProvider =
    StateNotifierProvider<UserController, AsyncValue<User?>>((ref) {
  return UserController(ref);
});
