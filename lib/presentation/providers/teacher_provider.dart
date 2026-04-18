import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../domain/entities/achievement_group.dart';
import '../../domain/entities/badge.dart';
import '../../domain/entities/card.dart';
import '../../domain/entities/class_learning_path_unit.dart';
import '../../domain/entities/student_unit_progress_item.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/teacher_repository.dart';
import 'badge_progress_provider.dart';
import 'badge_provider.dart';
import '../../domain/usecases/assignment/delete_assignment_usecase.dart';
import '../../domain/usecases/assignment/get_assignment_detail_usecase.dart';
import '../../domain/usecases/badge/get_user_badges_usecase.dart';
import '../../domain/usecases/card/get_user_cards_usecase.dart';
import '../../domain/usecases/wordlist/get_words_for_list_usecase.dart';
import '../../domain/usecases/assignment/get_assignment_students_usecase.dart';
import '../../domain/usecases/assignment/get_assignments_usecase.dart';
import '../../domain/usecases/assignment/get_class_learning_path_units_usecase.dart';
import '../../domain/usecases/assignment/get_student_unit_progress_usecase.dart';
import '../../domain/usecases/teacher/get_class_students_usecase.dart';
import '../../domain/usecases/teacher/get_classes_usecase.dart';
import '../../domain/usecases/teacher/get_student_detail_usecase.dart';
import '../../domain/usecases/teacher/get_student_progress_usecase.dart';
import '../../domain/usecases/teacher/get_student_vocab_stats_usecase.dart';
import '../../domain/usecases/teacher/get_student_word_list_progress_usecase.dart';
import '../../domain/usecases/teacher/get_recent_school_activity_usecase.dart';
import '../../domain/usecases/teacher/get_school_book_reading_stats_usecase.dart';
import '../../domain/usecases/teacher/get_school_summary_usecase.dart';
import '../../domain/usecases/teacher/get_teacher_stats_usecase.dart';
import '../../domain/usecases/usecase.dart';
import 'auth_provider.dart';
import 'usecase_providers.dart';

/// Provider for teacher dashboard statistics
final teacherStatsProvider = FutureProvider<TeacherStats>((ref) async {
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) {
    return const TeacherStats(
      totalStudents: 0,
      totalClasses: 0,
      activeAssignments: 0,
      avgProgress: 0,
    );
  }

  final useCase = ref.watch(getTeacherStatsUseCaseProvider);
  final result = await useCase(GetTeacherStatsParams(teacherId: userId));

  return result.fold(
    (failure) => const TeacherStats(
      totalStudents: 0,
      totalClasses: 0,
      activeAssignments: 0,
      avgProgress: 0,
    ),
    (stats) => stats,
  );
});

/// Provider for current teacher's profile
final currentTeacherProfileProvider = FutureProvider<User?>((ref) async {
  final user = await ref.watch(authStateChangesProvider.future);
  return user;
});

/// Provider for current teacher's classes. Talks to the use case directly
/// (no family delegation) so `ref.invalidate(currentTeacherClassesProvider)`
/// actually re-fetches — family delegation used to hide the upstream cache
/// and breaks invalidation after create/delete.
final currentTeacherClassesProvider = FutureProvider<List<TeacherClass>>((ref) async {
  final user = await ref.watch(authStateChangesProvider.future);
  if (user == null || user.schoolId.isEmpty) return [];

  final useCase = ref.watch(getClassesUseCaseProvider);
  final result = await useCase(GetClassesParams(schoolId: user.schoolId));

  return result.fold(
    (failure) => throw Exception(failure.message),
    (classes) => classes,
  );
});

/// Provider for students in a specific class
final classStudentsProvider =
    FutureProvider.family<List<StudentSummary>, String>((ref, classId) async {
  final useCase = ref.watch(getClassStudentsUseCaseProvider);
  final result = await useCase(GetClassStudentsParams(classId: classId));

  return result.fold(
    (failure) => throw Exception(failure.message),
    (students) => students,
  );
});

/// Provider for detailed student info
final studentDetailProvider =
    FutureProvider.family<User?, String>((ref, studentId) async {
  final useCase = ref.watch(getStudentDetailUseCaseProvider);
  final result = await useCase(GetStudentDetailParams(studentId: studentId));

  return result.fold(
    (failure) => null,
    (user) => user,
  );
});

/// Provider for student's book progress
final studentProgressProvider =
    FutureProvider.family<List<StudentBookProgress>, String>((ref, studentId) async {
  final useCase = ref.watch(getStudentProgressUseCaseProvider);
  final result = await useCase(GetStudentProgressParams(studentId: studentId));

  return result.fold(
    (failure) => [],
    (progress) => progress,
  );
});

/// Provider for student's vocabulary stats
final studentVocabStatsProvider =
    FutureProvider.family<StudentVocabStats, String>((ref, studentId) async {
  final useCase = ref.watch(getStudentVocabStatsUseCaseProvider);
  final result = await useCase(GetStudentVocabStatsParams(studentId: studentId));

  return result.fold(
    (failure) => const StudentVocabStats(
      totalWords: 0,
      newCount: 0,
      learningCount: 0,
      reviewingCount: 0,
      masteredCount: 0,
      listsStarted: 0,
      listsCompleted: 0,
      totalSessions: 0,
    ),
    (stats) => stats,
  );
});

/// Provider for student's word list progress
final studentWordListProgressProvider =
    FutureProvider.family<List<StudentWordListProgress>, String>((ref, studentId) async {
  final useCase = ref.watch(getStudentWordListProgressUseCaseProvider);
  final result = await useCase(GetStudentWordListProgressParams(studentId: studentId));

  return result.fold(
    (failure) => [],
    (progress) => progress,
  );
});

// =============================================
// READING PROGRESS REPORT PROVIDERS
// =============================================

/// Provider for per-book reading stats scoped to the teacher's school
final schoolBookReadingStatsProvider = FutureProvider<List<BookReadingStats>>((ref) async {
  final user = ref.watch(authStateChangesProvider).valueOrNull;
  if (user == null || user.schoolId.isEmpty) return [];

  final useCase = ref.watch(getSchoolBookReadingStatsUseCaseProvider);
  final result = await useCase(GetSchoolBookReadingStatsParams(schoolId: user.schoolId));

  return result.fold(
    (failure) => <BookReadingStats>[],
    (stats) => stats,
  );
});

// =============================================
// RECENT ACTIVITY PROVIDERS
// =============================================

/// Provider for recent school activity feed (teacher dashboard)
final recentSchoolActivityProvider = FutureProvider<List<RecentActivity>>((ref) async {
  final user = await ref.watch(authStateChangesProvider.future);
  if (user == null || user.schoolId.isEmpty) return [];

  final useCase = ref.watch(getRecentSchoolActivityUseCaseProvider);
  final result = await useCase(GetRecentSchoolActivityParams(schoolId: user.schoolId));

  return result.fold(
    (failure) => [],
    (activities) => activities,
  );
});

// =============================================
// STUDENT PROFILE EXTRAS (badges, cards, word list words)
// =============================================

/// Student badges visible to teacher (same school RLS)
final teacherStudentBadgesProvider =
    FutureProvider.family<List<dynamic>, String>((ref, studentId) async {
  final useCase = ref.watch(getUserBadgesUseCaseProvider);
  final result = await useCase(GetUserBadgesParams(userId: studentId));
  return result.fold((failure) => [], (badges) => badges);
});

/// Student cards visible to teacher (same school RLS)
final teacherStudentCardsProvider =
    FutureProvider.family<List<dynamic>, String>((ref, studentId) async {
  final useCase = ref.watch(getUserCardsUseCaseProvider);
  final result = await useCase(GetUserCardsParams(userId: studentId));
  return result.fold((failure) => [], (cards) => cards);
});

/// Monthly login/freeze dates for a specific student (teacher view).
/// Uses a SECURITY DEFINER RPC (teacher-only, same-school check) because
/// daily_logins RLS blocks direct cross-user reads.
final teacherStudentMonthlyLoginsProvider = FutureProvider.family<
    Map<DateTime, bool>,
    ({String studentId, int year, int month})>((ref, params) async {
  final supabase = Supabase.instance.client;
  try {
    final response = await supabase.rpc(
      'get_student_monthly_logins',
      params: {
        'p_student_id': params.studentId,
        'p_year': params.year,
        'p_month': params.month,
      },
    );
    final map = <DateTime, bool>{};
    for (final row in (response as List)) {
      final date = DateTime.parse(row['login_date'] as String);
      map[DateTime(date.year, date.month, date.day)] =
          row['is_freeze'] as bool? ?? false;
    }
    return map;
  } catch (_) {
    return <DateTime, bool>{};
  }
});

/// Achievement tracks (Duolingo-style) for a specific student — reuses the
/// same compute function the current-user provider uses.
final studentAchievementGroupsProvider =
    FutureProvider.family<List<AchievementGroup>, String>((ref, studentId) async {
  final allBadges = await ref.watch(allBadgesProvider.future);
  final userBadgesDyn = await ref.watch(teacherStudentBadgesProvider(studentId).future);
  final userBadges = userBadgesDyn.cast<UserBadge>();
  final student = await ref.watch(studentDetailProvider(studentId).future);
  final progressList = await ref.watch(studentProgressProvider(studentId).future);
  final vocabStats = await ref.watch(studentVocabStatsProvider(studentId).future);
  final cardsDyn = await ref.watch(teacherStudentCardsProvider(studentId).future);
  final cards = cardsDyn.cast<UserCard>();

  final booksCompleted =
      progressList.where((p) => p.isCompleted).length;
  final mythSlugProgress = <String, int>{};
  for (final c in cards) {
    final slug = c.card.category.dbValue;
    mythSlugProgress[slug] = (mythSlugProgress[slug] ?? 0) + 1;
  }

  return buildAchievementGroups(AchievementGroupInput(
    allBadges: allBadges,
    earnedIds: userBadges.map((ub) => ub.badgeId).toSet(),
    xp: student?.xp ?? 0,
    streak: student?.currentStreak ?? 0,
    level: student?.level ?? 0,
    tierOrdinal: buildLeagueTierOrdinal(student?.leagueTier.dbValue),
    totalCards: cards.length,
    booksCompleted: booksCompleted,
    vocabCollected: vocabStats.totalWords,
    mythCategoryProgressBySlug: mythSlugProgress,
    monthlyCountByQuest: const {},
    monthlyMetaByQuest: const {},
  ));
});

/// Words for a specific word list (public RLS)
final wordListWordsProvider =
    FutureProvider.family<List<dynamic>, String>((ref, listId) async {
  final useCase = ref.watch(getWordsForListUseCaseProvider);
  final result = await useCase(GetWordsForListParams(listId: listId));
  return result.fold((failure) => [], (words) => words);
});

// =============================================
// ASSIGNMENT PROVIDERS
// =============================================

/// Provider for teacher's assignments
final teacherAssignmentsProvider = FutureProvider<List<Assignment>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return [];
  }

  final useCase = ref.watch(getAssignmentsUseCaseProvider);
  final result = await useCase(GetAssignmentsParams(teacherId: userId));

  return result.fold(
    (failure) => throw Exception(failure.message),
    (assignments) => assignments,
  );
});

/// Provider for assignment detail
final assignmentDetailProvider =
    FutureProvider.family<Assignment?, String>((ref, assignmentId) async {
  final useCase = ref.watch(getAssignmentDetailUseCaseProvider);
  final result = await useCase(GetAssignmentDetailParams(assignmentId: assignmentId));

  return result.fold(
    (failure) => null,
    (assignment) => assignment,
  );
});

/// Provider for students in an assignment
final assignmentStudentsProvider =
    FutureProvider.family<List<AssignmentStudent>, String>((ref, assignmentId) async {
  final useCase = ref.watch(getAssignmentStudentsUseCaseProvider);
  final result = await useCase(GetAssignmentStudentsParams(assignmentId: assignmentId));

  return result.fold(
    (failure) => [],
    (students) => students,
  );
});

/// Provider for learning path units of a class (for unit assignment creation)
final classLearningPathUnitsProvider =
    FutureProvider.family<List<ClassLearningPathUnit>, String>((ref, classId) async {
  final useCase = ref.watch(getClassLearningPathUnitsUseCaseProvider);
  final result = await useCase(GetClassLearningPathUnitsParams(classId: classId));

  return result.fold(
    (failure) => [],
    (units) => units,
  );
});

/// Provider for a student's per-item unit progress (teacher view)
final studentUnitProgressProvider =
    FutureProvider.family<List<StudentUnitProgressItem>, ({String assignmentId, String studentId})>(
  (ref, params) async {
    final useCase = ref.watch(getStudentUnitProgressUseCaseProvider);
    final result = await useCase(GetStudentUnitProgressParams(
      assignmentId: params.assignmentId,
      studentId: params.studentId,
    ),);

    return result.fold(
      (failure) => [],
      (items) => items,
    );
  },
);

/// Controller for teacher assignment mutations (delete)
class AssignmentDeleteController extends StateNotifier<AsyncValue<void>> {
  AssignmentDeleteController(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  bool get isMutating => state is AsyncLoading;

  Future<String?> deleteAssignment(String assignmentId) async {
    if (isMutating) return null;
    state = const AsyncValue.loading();
    final useCase = _ref.read(deleteAssignmentUseCaseProvider);
    final result = await useCase(DeleteAssignmentParams(assignmentId: assignmentId));
    return result.fold(
      (failure) {
        state = const AsyncValue.data(null);
        return failure.message;
      },
      (_) {
        _ref.invalidate(teacherAssignmentsProvider);
        _ref.invalidate(teacherStatsProvider);
        state = const AsyncValue.data(null);
        return null;
      },
    );
  }
}

final assignmentDeleteControllerProvider =
    StateNotifierProvider.autoDispose<AssignmentDeleteController, AsyncValue<void>>((ref) {
  return AssignmentDeleteController(ref);
});

/// Aggregates for the teacher's own school (watches authed user for schoolId).
final schoolSummaryProvider =
    FutureProvider.autoDispose<SchoolSummary?>((ref) async {
  final user = await ref.watch(authStateChangesProvider.future);
  if (user == null || user.schoolId.isEmpty) return null;

  final useCase = ref.watch(getSchoolSummaryUseCaseProvider);
  final result = await useCase(
    GetSchoolSummaryParams(schoolId: user.schoolId),
  );
  return result.fold(
    (failure) => throw Exception(failure.message),
    (summary) => summary,
  );
});

/// Platform-wide student averages (same for every teacher).
final globalAveragesProvider =
    FutureProvider.autoDispose<GlobalAverages>((ref) async {
  final useCase = ref.watch(getGlobalAveragesUseCaseProvider);
  final result = await useCase(const NoParams());
  return result.fold(
    (failure) => throw Exception(failure.message),
    (averages) => averages,
  );
});
