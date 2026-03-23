import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../core/utils/app_clock.dart';
import '../../domain/entities/streak_result.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/user/add_xp_usecase.dart';
import '../../domain/usecases/user/buy_streak_freeze_usecase.dart';
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

/// Provider for streak events (milestone, freeze-saved, streak-broken)
final streakEventProvider = StateProvider<StreakResult?>((ref) => null);


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

/// Login/freeze dates for streak calendar (from daily_logins table)
/// Returns map: date → is_freeze (true = freeze day, false = login day)
final loginDatesProvider = FutureProvider<Map<DateTime, bool>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return {};

  try {
    final today = AppClock.today();
    final monday = today.subtract(Duration(days: today.weekday - 1));

    final response = await Supabase.instance.client
        .from(DbTables.dailyLogins)
        .select('login_date, is_freeze')
        .eq('user_id', userId)
        .gte('login_date', monday.toIso8601String().split('T').first);

    final map = <DateTime, bool>{};
    for (final row in response as List) {
      final date = DateTime.parse(row['login_date'] as String);
      map[DateTime(date.year, date.month, date.day)] = row['is_freeze'] as bool? ?? false;
    }
    return map;
  } catch (_) {
    return {};
  }
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
        _ref.read(streakEventProvider.notifier).state = null;
      }
    }, fireImmediately: true,);
  }
  final Ref _ref;

  Future<void> _loadUserById(String userId) async {
    final oldUser = state.valueOrNull;
    state = const AsyncValue.loading();

    final useCase = _ref.read(getUserByIdUseCaseProvider);
    final result = await useCase(GetUserByIdParams(userId: userId));

    final user = result.fold((failure) {
      state = AsyncValue.error(failure.message, StackTrace.current);
      return null;
    }, (user) => user);

    if (user == null) return;

    // Run streak check BEFORE setting state — this updates DB + re-fetches profile
    await _updateStreakIfNeeded(user);

    // Now read the fully updated profile (streak check already set state via updateStreak)
    // If updateStreak didn't run or failed, set state with the initial profile
    if (!state.hasValue || state.valueOrNull == null) {
      state = AsyncValue.data(user);
    }

    _checkLeagueTierChange(oldUser, state.valueOrNull ?? user);
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
    // Check streak on every app open (like Duolingo).
    // RPC is idempotent — same-day calls return no-op.
    // This ensures streak broken/freeze notifications show immediately on launch.
    await updateStreak();
  }

  Future<void> addXP(int amount) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;

    final oldLevel = state.valueOrNull?.level ?? 1;

    final useCase = _ref.read(addXPUseCaseProvider);
    debugPrint('🔄 addXP: awarding $amount XP to $userId');
    final result = await useCase(AddXPParams(userId: userId, amount: amount));

    final user = result.fold(
      (failure) {
        debugPrint('❌ addXP FAILED: ${failure.message}');
        return null;
      },
      (user) => user,
    );

    if (user == null) return;

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

    // Note: NOT calling updateStreak() here.
    // Server-side RPCs (complete_daily_review, complete_vocabulary_session)
    // already call PERFORM update_user_streak() internally.
    // The streak was already updated on app open via _updateStreakIfNeeded.
    // Calling it again would be idempotent but would suppress event dialogs
    // (second same-day call returns no events).
  }

  Future<void> updateStreak() async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;

    final useCase = _ref.read(updateStreakUseCaseProvider);
    final result = await useCase(UpdateStreakParams(userId: userId));

    // FIX: Extract from fold to properly await — Either.fold is not async-aware
    final streakResult = result.fold<StreakResult?>((f) => null, (r) => r);
    if (streakResult == null) return;

    // Re-fetch profile with updated streak data
    final getUserUseCase = _ref.read(getUserByIdUseCaseProvider);
    final userResult = await getUserUseCase(GetUserByIdParams(userId: userId));
    userResult.fold((_) => null, (user) => state = AsyncValue.data(user));
    _ref.invalidate(loginDatesProvider);

    // Fire streak event if anything notable happened
    if (streakResult.hasEvent) {
      _ref.read(streakEventProvider.notifier).state = streakResult;
    }
  }

  Future<bool> buyStreakFreeze() async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return false;

    final useCase = _ref.read(buyStreakFreezeUseCaseProvider);
    final result = await useCase(BuyStreakFreezeParams(userId: userId));

    // FIX: Extract from fold to properly await
    final buyResult = result.fold<BuyFreezeResult?>((f) => null, (r) => r);
    if (buyResult == null) return false;

    // Re-fetch profile to update freeze count and coins
    final getUserUseCase = _ref.read(getUserByIdUseCaseProvider);
    final userResult = await getUserUseCase(GetUserByIdParams(userId: userId));
    userResult.fold((_) => null, (user) => state = AsyncValue.data(user));
    return true;
  }

  /// Refresh profile without triggering streak check.
  /// Use after vocab sessions, daily reviews, etc. where the server-side RPC
  /// already called update_user_streak internally.
  Future<void> refreshProfileOnly() async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;

    final oldLevel = state.valueOrNull?.level ?? 1;

    final useCase = _ref.read(getUserByIdUseCaseProvider);
    final result = await useCase(GetUserByIdParams(userId: userId));
    result.fold(
      (_) => null,
      (user) {
        state = AsyncValue.data(user);
        if (user.level > oldLevel) {
          _ref.read(levelUpEventProvider.notifier).state = LevelUpEvent(
            oldLevel: oldLevel,
            newLevel: user.level,
          );
        }
      },
    );
  }

  /// Full refresh with streak check. Only use for app-level refresh (pull-to-refresh etc.)
  Future<void> refresh() async {
    await _loadUser();
  }
}

final userControllerProvider =
    StateNotifierProvider<UserController, AsyncValue<User?>>((ref) {
  return UserController(ref);
});
