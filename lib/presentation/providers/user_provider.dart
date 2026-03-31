import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../core/utils/app_clock.dart';
import '../../domain/entities/badge_earned.dart';
import '../../domain/entities/streak_result.dart';
import '../../domain/entities/system_settings.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/badge/check_and_award_badges_usecase.dart';
import '../../domain/usecases/user/add_xp_usecase.dart';
import '../../domain/usecases/user/buy_streak_freeze_usecase.dart';
import '../../domain/usecases/user/get_login_dates_usecase.dart';
import '../../domain/usecases/user/get_user_by_id_usecase.dart';
import '../../domain/usecases/user/get_user_stats_usecase.dart';
import '../../domain/usecases/user/get_weekly_activity_usecase.dart';
import '../../domain/usecases/user/update_streak_usecase.dart';
import 'auth_provider.dart';
import 'badge_provider.dart';
import 'system_settings_provider.dart';
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

/// Badge earned event for celebration dialog
class BadgeEarnedEvent {
  const BadgeEarnedEvent({required this.badges});
  final List<BadgeEarned> badges;
}

/// Provider for badge earned events - UI listens to show celebration
final badgeEarnedEventProvider = StateProvider<BadgeEarnedEvent?>((ref) => null);

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

  final today = AppClock.today();
  final monday = today.subtract(Duration(days: today.weekday - 1));

  final useCase = ref.watch(getLoginDatesUseCaseProvider);
  final result = await useCase(GetLoginDatesParams(userId: userId, from: monday));
  return result.fold(
    (failure) => <DateTime, bool>{},
    (dates) => dates,
  );
});

/// Monthly login/freeze dates for streak calendar (from daily_logins table).
/// Keyed by (year, month) so each month is cached independently.
final monthlyLoginDatesProvider = FutureProvider.family<
    Map<DateTime, bool>,
    ({int year, int month})>((ref, params) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return {};

  final from = DateTime(params.year, params.month, 1);
  final nextMonth = DateTime(params.year, params.month + 1, 1);
  final useCase = ref.watch(getLoginDatesUseCaseProvider);
  final result =
      await useCase(GetLoginDatesParams(userId: userId, from: from));
  return result.fold(
    (_) => <DateTime, bool>{},
    (dates) {
      // Filter to only this month (query has no upper bound)
      dates.removeWhere((date, _) => !date.isBefore(nextMonth));
      return dates;
    },
  );
});

/// Computed streak from daily_logins — counts consecutive days backward from
/// today. Falls back to profiles.current_streak while data is loading.
/// Use this for display instead of user.currentStreak so the number matches
/// the calendar ticks.
final displayStreakProvider = Provider<int>((ref) {
  final user = ref.watch(userControllerProvider).valueOrNull;
  if (user == null) return 0;

  final today = AppClock.today();
  final curData = ref.watch(monthlyLoginDatesProvider(
    (year: today.year, month: today.month),
  )).valueOrNull;
  final prev = DateTime(today.year, today.month - 1, 1);
  final prevData = ref.watch(monthlyLoginDatesProvider(
    (year: prev.year, month: prev.month),
  )).valueOrNull;

  // Still loading — fall back to profile value
  if (curData == null) return user.currentStreak;

  final allDays = {...?prevData, ...curData};
  var count = 0;
  var date = today;
  while (true) {
    final key = DateTime(date.year, date.month, date.day);
    if (allDays.containsKey(key)) {
      count++;
      date = date.subtract(const Duration(days: 1));
    } else {
      break;
    }
  }
  return count;
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
        _ref.read(badgeEarnedEventProvider.notifier).state = null;
      }
    }, fireImmediately: true,);
  }
  final Ref _ref;

  /// Read notification settings (fallback to defaults if not yet loaded)
  SystemSettings get _notifSettings =>
      _ref.read(systemSettingsProvider).valueOrNull ?? SystemSettings.defaults();

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
    if (oldUser.leagueTier != newUser.leagueTier && _notifSettings.notifLeagueChange) {
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
    // Skip if already updated today (avoids redundant RPC on same-day re-opens)
    final today = AppClock.today();
    final lastActivity = user.lastActivityDate;
    if (lastActivity != null && DateTime(lastActivity.year, lastActivity.month, lastActivity.day) == today) {
      return;
    }
    // First open of the day — check streak (broken/freeze/milestone notifications)
    await updateStreak();
  }

  Future<void> addXP(int amount, {String source = 'manual', String? sourceId}) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;

    final oldLevel = state.valueOrNull?.level ?? 1;

    final useCase = _ref.read(addXPUseCaseProvider);
    debugPrint('🔄 addXP: awarding $amount XP to $userId (source=$source, sourceId=$sourceId)');
    final result = await useCase(AddXPParams(
      userId: userId,
      amount: amount,
      source: source,
      sourceId: sourceId,
    ));

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
    if (user.level > oldLevel && _notifSettings.notifLevelUp) {
      _ref.read(levelUpEventProvider.notifier).state = LevelUpEvent(
        oldLevel: oldLevel,
        newLevel: user.level,
      );
    }

    // Check for new badges
    final badgeUseCase = _ref.read(checkAndAwardBadgesUseCaseProvider);
    final badgeResult = await badgeUseCase(CheckAndAwardBadgesParams(userId: userId));
    badgeResult.fold(
      (_) {}, // Ignore badge check failures
      (badges) {
        if (badges.isNotEmpty) {
          if (_notifSettings.notifBadgeEarned) {
            _ref.read(badgeEarnedEventProvider.notifier).state =
                BadgeEarnedEvent(badges: badges);
          }
          _ref.invalidate(userBadgesProvider);
          // Re-fetch profile so badge XP is reflected in UI
          refreshProfileOnly();
        }
      },
    );

    // Note: NOT calling updateStreak() here.
    // Streak is login-based — updated once per day on app open via _updateStreakIfNeeded.
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

    // Fire streak event if settings allow it
    final s = _notifSettings;
    final shouldShow =
        (streakResult.milestoneBonusXp > 0 && s.notifMilestone) ||
        (streakResult.freezeUsed && !streakResult.streakBroken && s.notifFreezeSaved) ||
        (streakResult.streakBroken && streakResult.previousStreak >= s.notifStreakBrokenMin && s.notifStreakBroken) ||
        (streakResult.streakExtended && s.notifStreakExtended);
    if (shouldShow) {
      _ref.read(streakEventProvider.notifier).state = streakResult;
    }

    // Check for new badges (streak badges)
    final badgeUseCase = _ref.read(checkAndAwardBadgesUseCaseProvider);
    final badgeResult = await badgeUseCase(CheckAndAwardBadgesParams(userId: userId));
    badgeResult.fold(
      (_) {},
      (badges) {
        if (badges.isNotEmpty) {
          if (_notifSettings.notifBadgeEarned) {
            _ref.read(badgeEarnedEventProvider.notifier).state =
                BadgeEarnedEvent(badges: badges);
          }
          _ref.invalidate(userBadgesProvider);
          // Re-fetch profile so badge XP is reflected in UI
          refreshProfileOnly();
        }
      },
    );
  }

  /// Returns null on success, error message on failure.
  Future<String?> buyStreakFreeze() async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return 'Not logged in';

    final useCase = _ref.read(buyStreakFreezeUseCaseProvider);
    final result = await useCase(BuyStreakFreezeParams(userId: userId));

    final buyResult = result.fold<BuyFreezeResult?>((f) => null, (r) => r);
    if (buyResult == null) {
      return result.fold((f) => f.message, (_) => 'Unknown error');
    }

    // Re-fetch profile to update freeze count and coins
    final getUserUseCase = _ref.read(getUserByIdUseCaseProvider);
    final userResult = await getUserUseCase(GetUserByIdParams(userId: userId));
    userResult.fold((_) => null, (user) => state = AsyncValue.data(user));
    return null;
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
        if (user.level > oldLevel && _notifSettings.notifLevelUp) {
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
