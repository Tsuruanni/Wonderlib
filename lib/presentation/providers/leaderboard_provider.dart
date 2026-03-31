import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/entities/league_status.dart';
import '../../domain/usecases/user/get_league_group_leaderboard_usecase.dart';
import '../../domain/usecases/user/get_total_leaderboard_usecase.dart';
import '../../domain/usecases/user/get_user_league_status_usecase.dart';
import '../../domain/usecases/user/get_user_total_position_usecase.dart';
import 'auth_provider.dart';
import 'usecase_providers.dart';

enum LeaderboardScope { classScope, schoolScope, leagueScope }

final leaderboardScopeProvider = StateProvider<LeaderboardScope>(
  (ref) => LeaderboardScope.leagueScope,
);

/// League status for the current user (joined?, group_id, progress).
final leagueStatusProvider =
    FutureProvider.autoDispose<LeagueStatus?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  final useCase = ref.watch(getUserLeagueStatusUseCaseProvider);
  final result = await useCase(
    GetUserLeagueStatusParams(userId: userId),
  );
  return result.fold((_) => null, (status) => status);
});

/// League group leaderboard entries (30 entries = real + bots).
final leagueGroupEntriesProvider =
    FutureProvider.autoDispose<List<LeaderboardEntry>>((ref) async {
  final status = await ref.watch(leagueStatusProvider.future);
  if (status == null || !status.joined || status.groupId == null) return [];

  final useCase = ref.watch(getLeagueGroupLeaderboardUseCaseProvider);
  final result = await useCase(
    GetLeagueGroupLeaderboardParams(groupId: status.groupId!),
  );
  return result.fold((_) => [], (entries) => entries);
});

/// Total XP leaderboard entries (class/school scope only).
final totalLeaderboardEntriesProvider =
    FutureProvider.autoDispose<List<LeaderboardEntry>>((ref) async {
  final currentUser = ref.watch(authStateChangesProvider).valueOrNull;
  if (currentUser == null) return [];

  final scope = ref.watch(leaderboardScopeProvider);
  // League scope uses leagueGroupEntriesProvider, not this provider
  if (scope == LeaderboardScope.leagueScope) return [];

  final useCase = ref.watch(getTotalLeaderboardUseCaseProvider);

  if (scope == LeaderboardScope.classScope) {
    if (currentUser.classId == null) return [];
    final result = await useCase(GetTotalLeaderboardParams(
      scope: TotalLeaderboardScope.classScope,
      classId: currentUser.classId,
      limit: 50,
    ));
    return result.fold((_) => [], (entries) => entries);
  } else {
    final result = await useCase(GetTotalLeaderboardParams(
      scope: TotalLeaderboardScope.schoolScope,
      schoolId: currentUser.schoolId,
      limit: 50,
    ));
    return result.fold((_) => [], (entries) => entries);
  }
});

/// Current user's total position (for class/school when outside top N).
final currentUserTotalPositionProvider =
    FutureProvider.autoDispose<LeaderboardEntry?>((ref) async {
  final currentUser = ref.watch(authStateChangesProvider).valueOrNull;
  if (currentUser == null) return null;

  final scope = ref.watch(leaderboardScopeProvider);
  if (scope == LeaderboardScope.leagueScope) return null;

  final useCase = ref.watch(getUserTotalPositionUseCaseProvider);

  if (scope == LeaderboardScope.classScope) {
    if (currentUser.classId == null) return null;
    final result = await useCase(GetUserTotalPositionParams(
      userId: currentUser.id,
      scope: TotalLeaderboardScope.classScope,
      classId: currentUser.classId,
    ));
    return result.fold((_) => null, (entry) => entry);
  } else {
    final result = await useCase(GetUserTotalPositionParams(
      userId: currentUser.id,
      scope: TotalLeaderboardScope.schoolScope,
      schoolId: currentUser.schoolId,
    ));
    return result.fold((_) => null, (entry) => entry);
  }
});

/// Combined leaderboard display state.
final leaderboardDisplayProvider =
    FutureProvider.autoDispose<LeaderboardDisplayState>((ref) async {
  final scope = ref.watch(leaderboardScopeProvider);
  final currentUser = ref.watch(authStateChangesProvider).valueOrNull;

  if (currentUser == null) {
    return const LeaderboardDisplayState(
      entries: [],
      currentUserEntry: null,
      currentUserId: '',
    );
  }

  if (scope == LeaderboardScope.leagueScope) {
    final status = await ref.watch(leagueStatusProvider.future);
    final entries = await ref.watch(leagueGroupEntriesProvider.future);

    return LeaderboardDisplayState(
      entries: entries,
      currentUserEntry: null,
      currentUserId: currentUser.id,
      scope: scope,
      leagueStatus: status,
    );
  }

  // Class/School scope
  final entries = await ref.watch(totalLeaderboardEntriesProvider.future);
  final userPosition = await ref.watch(currentUserTotalPositionProvider.future);
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
    this.leagueStatus,
  });

  final List<LeaderboardEntry> entries;
  final LeaderboardEntry? currentUserEntry;
  final String currentUserId;
  final LeaderboardScope scope;
  final LeagueStatus? leagueStatus;

  bool get isLeagueMode => scope == LeaderboardScope.leagueScope;
  bool get isEmpty => entries.isEmpty;
  bool isCurrentUser(String userId) => userId == currentUserId;

  /// Whether user has joined a league group this week.
  bool get isLeagueJoined => leagueStatus?.joined ?? false;

  /// Total display count (always 30 for league, entries.length + user for others).
  int get totalCount => isLeagueMode ? 30 : entries.length + (currentUserEntry != null ? 1 : 0);
}
