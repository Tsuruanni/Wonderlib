import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/usecases/user/get_total_leaderboard_usecase.dart';
import '../../domain/usecases/user/get_user_total_position_usecase.dart';
import '../../domain/usecases/user/get_weekly_leaderboard_usecase.dart'
    as weekly;
import '../../domain/usecases/user/get_user_weekly_position_usecase.dart';
import 'auth_provider.dart';
import 'usecase_providers.dart';

/// Leaderboard scope: class or school.
enum LeaderboardScope { classScope, schoolScope, leagueScope }

/// Current leaderboard scope toggle.
final leaderboardScopeProvider = StateProvider<LeaderboardScope>(
  (ref) => LeaderboardScope.leagueScope,
);

/// Total XP leaderboard entries (all students).
final leaderboardEntriesProvider =
    FutureProvider.autoDispose<List<LeaderboardEntry>>((ref) async {
  final currentUser = await ref.watch(currentUserProvider.future);
  if (currentUser == null) return [];

  final scope = ref.watch(leaderboardScopeProvider);

  if (scope == LeaderboardScope.classScope) {
    if (currentUser.classId == null) return [];
    final useCase = ref.watch(getTotalLeaderboardUseCaseProvider);
    final result = await useCase(GetTotalLeaderboardParams(
      scope: TotalLeaderboardScope.classScope,
      classId: currentUser.classId,
      limit: 50,
    ));
    return result.fold((_) => [], (entries) => entries);
  } else if (scope == LeaderboardScope.schoolScope) {
    final useCase = ref.watch(getTotalLeaderboardUseCaseProvider);
    final result = await useCase(GetTotalLeaderboardParams(
      scope: TotalLeaderboardScope.schoolScope,
      schoolId: currentUser.schoolId,
      limit: 50,
    ));
    return result.fold((_) => [], (entries) => entries);
  } else {
    // leagueScope — weekly school leaderboard (within user's tier)
    final useCase = ref.watch(getWeeklyLeaderboardUseCaseProvider);
    final result = await useCase(weekly.GetWeeklyLeaderboardParams(
      scope: weekly.LeaderboardScope.schoolScope,
      schoolId: currentUser.schoolId,
      leagueTier: currentUser.leagueTier.dbValue,
      limit: 50,
    ));
    return result.fold((_) => [], (entries) => entries);
  }
});

/// Current user's position (for when they're outside the top N fetched).
final currentUserPositionProvider =
    FutureProvider.autoDispose<LeaderboardEntry?>((ref) async {
  final currentUser = await ref.watch(currentUserProvider.future);
  if (currentUser == null) return null;

  final scope = ref.watch(leaderboardScopeProvider);

  if (scope == LeaderboardScope.classScope) {
    if (currentUser.classId == null) return null;
    final useCase = ref.watch(getUserTotalPositionUseCaseProvider);
    final result = await useCase(GetUserTotalPositionParams(
      userId: currentUser.id,
      scope: TotalLeaderboardScope.classScope,
      classId: currentUser.classId,
    ));
    return result.fold((_) => null, (entry) => entry);
  } else if (scope == LeaderboardScope.schoolScope) {
    final useCase = ref.watch(getUserTotalPositionUseCaseProvider);
    final result = await useCase(GetUserTotalPositionParams(
      userId: currentUser.id,
      scope: TotalLeaderboardScope.schoolScope,
      schoolId: currentUser.schoolId,
    ));
    return result.fold((_) => null, (entry) => entry);
  } else {
    // leagueScope — user's weekly position in school (within user's tier)
    final useCase = ref.watch(getUserWeeklyPositionUseCaseProvider);
    final result = await useCase(GetUserWeeklyPositionParams(
      userId: currentUser.id,
      scope: weekly.LeaderboardScope.schoolScope,
      schoolId: currentUser.schoolId,
      leagueTier: currentUser.leagueTier.dbValue,
    ));
    return result.fold((_) => null, (entry) => entry);
  }
});

/// Combined leaderboard state for display.
final leaderboardDisplayProvider =
    FutureProvider.autoDispose<LeaderboardDisplayState>((ref) async {
  final entries = await ref.watch(leaderboardEntriesProvider.future);
  final userPosition = await ref.watch(currentUserPositionProvider.future);
  final currentUser = await ref.watch(currentUserProvider.future);

  final scope = ref.watch(leaderboardScopeProvider);

  if (currentUser == null) {
    return const LeaderboardDisplayState(
      entries: [],
      currentUserEntry: null,
      currentUserId: '',
    );
  }

  final isInList = entries.any((e) => e.userId == currentUser.id);

  return LeaderboardDisplayState(
    entries: entries,
    currentUserEntry: isInList ? null : userPosition,
    currentUserId: currentUser.id,
    scope: scope,
  );
});

/// State class for leaderboard display.
class LeaderboardDisplayState {
  const LeaderboardDisplayState({
    required this.entries,
    required this.currentUserEntry,
    required this.currentUserId,
    this.scope = LeaderboardScope.classScope,
  });

  final List<LeaderboardEntry> entries;
  final LeaderboardEntry? currentUserEntry;
  final String currentUserId;
  final LeaderboardScope scope;

  bool get isLeagueMode => scope == LeaderboardScope.leagueScope;

  bool get isEmpty => entries.isEmpty;

  bool isCurrentUser(String userId) => userId == currentUserId;

  /// Total number of students (entries + possibly current user if not in list).
  int get totalCount => entries.length + (currentUserEntry != null ? 1 : 0);
}
