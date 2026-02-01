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
    // fireImmediately ensures we load user right away if auth state is ready
    _ref.listen(authStateChangesProvider, (previous, next) {
      final newUser = next.valueOrNull;
      final oldUserId = previous?.valueOrNull?.id;

      if (newUser != null && newUser.id != oldUserId) {
        _loadUserById(newUser.id);
      } else if (newUser == null && oldUserId != null) {
        // User logged out
        state = const AsyncValue.data(null);
      }
    }, fireImmediately: true);
  }

  Future<void> _loadUserById(String userId) async {
    state = const AsyncValue.loading();

    final userRepo = _ref.read(userRepositoryProvider);
    final result = await userRepo.getUserById(userId);

    result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
      },
      (user) {
        state = AsyncValue.data(user);
        _updateStreakIfNeeded(user);
      },
    );
  }

  Future<void> _loadUser() async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) {
      state = const AsyncValue.data(null);
      return;
    }
    await _loadUserById(userId);
  }

  Future<void> _updateStreakIfNeeded(User user) async {
    // Only update if user has never had activity (streak = 0, no last activity date)
    // This avoids unnecessary DB calls on every app open
    if (user.currentStreak == 0 && user.lastActivityDate == null) {
      await updateStreak();
    }
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
