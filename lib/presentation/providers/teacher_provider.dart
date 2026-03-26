import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/class_learning_path_unit.dart';
import '../../domain/entities/student_unit_progress_item.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/teacher_repository.dart';
import '../../domain/usecases/assignment/get_assignment_detail_usecase.dart';
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
import '../../domain/usecases/teacher/get_teacher_stats_usecase.dart';
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

/// Provider for teacher's classes (by school ID)
final teacherClassesProvider = FutureProvider.family<List<TeacherClass>, String>((ref, schoolId) async {
  if (schoolId.isEmpty) return [];

  final useCase = ref.watch(getClassesUseCaseProvider);
  final result = await useCase(GetClassesParams(schoolId: schoolId));

  return result.fold(
    (failure) => <TeacherClass>[],
    (classes) => classes,
  );
});

/// Provider for current teacher's classes (convenience wrapper)
final currentTeacherClassesProvider = FutureProvider<List<TeacherClass>>((ref) async {
  final user = await ref.watch(authStateChangesProvider.future);
  if (user == null || user.schoolId.isEmpty) return [];

  return ref.watch(teacherClassesProvider(user.schoolId).future);
});

/// Provider for students in a specific class
final classStudentsProvider =
    FutureProvider.family<List<StudentSummary>, String>((ref, classId) async {
  final useCase = ref.watch(getClassStudentsUseCaseProvider);
  final result = await useCase(GetClassStudentsParams(classId: classId));

  return result.fold(
    (failure) => [],
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
    (failure) => [],
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
    (failure) {
      debugPrint('📋 classLearningPathUnitsProvider FAILURE: ${failure.message}');
      return [];
    },
    (units) {
      debugPrint('📋 classLearningPathUnitsProvider: got ${units.length} units for classId=$classId');
      return units;
    },
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
      (failure) {
        debugPrint('📋 studentUnitProgressProvider FAILURE: ${failure.message}');
        return [];
      },
      (items) => items,
    );
  },
);

// =============================================
// LEADERBOARD PROVIDERS
// =============================================

/// Provider that aggregates all students from all classes for leaderboard
final allStudentsLeaderboardProvider = FutureProvider<List<StudentSummary>>((ref) async {
  final classesResult = await ref.watch(currentTeacherClassesProvider.future);

  final allStudents = <StudentSummary>[];

  for (final classItem in classesResult) {
    final students = await ref.watch(classStudentsProvider(classItem.id).future);
    allStudents.addAll(students);
  }

  // Sort by XP descending
  allStudents.sort((a, b) => b.xp.compareTo(a.xp));

  return allStudents;
});
