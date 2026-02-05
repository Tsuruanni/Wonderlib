import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/user/add_xp_usecase.dart';
import '../../domain/usecases/user/get_classmates_usecase.dart';
import '../../domain/usecases/user/get_leaderboard_usecase.dart';
import '../../domain/usecases/user/get_user_by_id_usecase.dart';
import '../../domain/usecases/user/get_user_stats_usecase.dart';
import '../../domain/usecases/user/update_streak_usecase.dart';
import 'auth_provider.dart';
import 'usecase_providers.dart';

/// Level up event for celebration UI
class LevelUpEvent {
  const LevelUpEvent({
    required this.oldLevel,
    required this.newLevel,
    required this.oldTier,
    required this.newTier,
  });

  final int oldLevel;
  final int newLevel;
  final UserLevel oldTier;
  final UserLevel newTier;

  /// True if user advanced to a new tier (every 5 levels)
  bool get isTierUp => oldTier != newTier;

  /// True if this is a milestone level (5, 10, 15, 20, etc.)
  bool get isMilestone => newLevel % 5 == 0;
}

/// Provider for level up events - UI can listen to this to show celebrations
final levelUpEventProvider = StateProvider<LevelUpEvent?>((ref) => null);

/// Provides user stats for current user
final userStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return {};

  final useCase = ref.watch(getUserStatsUseCaseProvider);
  final result = await useCase(GetUserStatsParams(userId: userId));
  return result.fold(
    (failure) => {},
    (stats) => stats,
  );
});

/// Provides leaderboard
final leaderboardProvider = FutureProvider.family<List<User>, LeaderboardParams?>((ref, params) async {
  final useCase = ref.watch(getLeaderboardUseCaseProvider);
  final result = await useCase(GetLeaderboardParams(
    schoolId: params?.schoolId,
    classId: params?.classId,
    limit: params?.limit ?? 10,
  ),);
  return result.fold(
    (failure) => [],
    (users) => users,
  );
});

/// Provides classmates
final classmatesProvider = FutureProvider<List<User>>((ref) async {
  final user = ref.watch(authStateChangesProvider).valueOrNull;
  if (user == null || user.classId == null) return [];

  final useCase = ref.watch(getClassmatesUseCaseProvider);
  final result = await useCase(GetClassmatesParams(classId: user.classId!));
  return result.fold(
    (failure) => [],
    (users) => users,
  );
});

/// Leaderboard params
class LeaderboardParams {

  const LeaderboardParams({
    this.schoolId,
    this.classId,
    this.limit = 10,
  });
  final String? schoolId;
  final String? classId;
  final int limit;
}

/// User controller for XP and streak updates
class UserController extends StateNotifier<AsyncValue<User?>> {

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
    }, fireImmediately: true,);
  }
  final Ref _ref;

  Future<void> _loadUserById(String userId) async {
    state = const AsyncValue.loading();

    final useCase = _ref.read(getUserByIdUseCaseProvider);
    final result = await useCase(GetUserByIdParams(userId: userId));

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

    // Capture old level/tier before XP update
    final oldUser = state.valueOrNull;
    final oldLevel = oldUser?.level ?? 1;
    final oldTier = oldUser?.userLevel ?? UserLevel.bronze;

    final useCase = _ref.read(addXPUseCaseProvider);
    final result = await useCase(AddXPParams(userId: userId, amount: amount));

    result.fold(
      (failure) => null,
      (user) {
        state = AsyncValue.data(user);

        // Check for level up
        if (user.level > oldLevel) {
          _ref.read(levelUpEventProvider.notifier).state = LevelUpEvent(
            oldLevel: oldLevel,
            newLevel: user.level,
            oldTier: oldTier,
            newTier: user.userLevel,
          );
        }
      },
    );

    // Update streak when XP is earned (activity completion)
    // DB function handles "once per day" logic automatically
    await updateStreak();

    // Note: Badge checking is handled by the check_and_award_badges RPC
    // called within SupabaseUserRepository.addXP()
  }

  Future<void> updateStreak() async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;

    final useCase = _ref.read(updateStreakUseCaseProvider);
    final result = await useCase(UpdateStreakParams(userId: userId));

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
