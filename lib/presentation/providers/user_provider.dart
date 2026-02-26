import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../domain/entities/user.dart';
import '../../domain/usecases/user/add_xp_usecase.dart';
import '../../domain/usecases/user/get_user_by_id_usecase.dart';
import '../../domain/usecases/user/get_user_stats_usecase.dart';
import '../../domain/usecases/user/get_weekly_activity_usecase.dart';
import '../../domain/usecases/user/update_streak_usecase.dart';
import 'auth_provider.dart';
import 'usecase_providers.dart';

/// Level up event for celebration UI
class LevelUpEvent {
  const LevelUpEvent({
    required this.oldLevel,
    required this.newLevel,
  });

  final int oldLevel;
  final int newLevel;
}

/// Provider for level up events - UI can listen to this to show celebrations
final levelUpEventProvider = StateProvider<LevelUpEvent?>((ref) => null);

/// League tier change event (weekly league promotion/demotion)
class LeagueTierChangeEvent {
  const LeagueTierChangeEvent({
    required this.oldTier,
    required this.newTier,
  });

  final LeagueTier oldTier;
  final LeagueTier newTier;

  bool get isPromotion => newTier.index > oldTier.index;
  bool get isDemotion => newTier.index < oldTier.index;
}

/// Provider for league tier change events
final leagueTierChangeEventProvider = StateProvider<LeagueTierChangeEvent?>((ref) => null);

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

/// Provides activity history for last 7 days
final activityHistoryProvider = FutureProvider<List<DateTime>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final useCase = ref.watch(getWeeklyActivityUseCaseProvider);
  final result = await useCase(GetWeeklyActivityParams(userId: userId));

  return result.fold(
    (failure) => [],
    (dates) => dates,
  );
});

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
        // User logged out — clear stale state
        state = const AsyncValue.data(null);
        _ref.read(levelUpEventProvider.notifier).state = null;
        _ref.read(leagueTierChangeEventProvider.notifier).state = null;
      }
    }, fireImmediately: true,);
  }
  final Ref _ref;

  Future<void> _loadUserById(String userId) async {
    final oldUser = state.valueOrNull;
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
        _checkLeagueTierChange(oldUser, user);
      },
    );
  }

  void _checkLeagueTierChange(User? oldUser, User newUser) {
    if (oldUser == null) return;
    if (oldUser.leagueTier != newUser.leagueTier) {
      _ref.read(leagueTierChangeEventProvider.notifier).state =
          LeagueTierChangeEvent(
        oldTier: oldUser.leagueTier,
        newTier: newUser.leagueTier,
      );
    }
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

    final oldLevel = state.valueOrNull?.level ?? 1;

    final useCase = _ref.read(addXPUseCaseProvider);
    debugPrint('🔄 addXP: awarding $amount XP to $userId');
    final result = await useCase(AddXPParams(userId: userId, amount: amount));

    final succeeded = result.fold(
      (failure) {
        debugPrint('❌ addXP FAILED: ${failure.message}');
        return false;
      },
      (user) {
        debugPrint('✅ addXP SUCCESS: new XP=${user.xp}, level=${user.level}');
        state = AsyncValue.data(user);
        _ref.invalidate(activityHistoryProvider);

        // Check for level up
        if (user.level > oldLevel) {
          _ref.read(levelUpEventProvider.notifier).state = LevelUpEvent(
            oldLevel: oldLevel,
            newLevel: user.level,
          );
        }
        return true;
      },
    );

    // Update streak only when XP was successfully awarded
    // DB function handles "once per day" logic automatically
    if (succeeded) {
      await updateStreak();
    }
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
        _ref.invalidate(activityHistoryProvider);
      },
    );
  }

  Future<void> refresh() async {
    final oldLevel = state.valueOrNull?.level ?? 1;

    await _loadUser();

    final newUser = state.valueOrNull;
    if (newUser != null && newUser.level > oldLevel) {
      _ref.read(levelUpEventProvider.notifier).state = LevelUpEvent(
        oldLevel: oldLevel,
        newLevel: newUser.level,
      );
    }
  }
}

final userControllerProvider =
    StateNotifierProvider<UserController, AsyncValue<User?>>((ref) {
  return UserController(ref);
});
