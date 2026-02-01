import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/user.dart';
import '../../domain/repositories/teacher_repository.dart';
import '../../domain/usecases/assignment/delete_assignment_usecase.dart';
import '../../domain/usecases/assignment/get_assignment_detail_usecase.dart';
import '../../domain/usecases/assignment/get_assignment_students_usecase.dart';
import '../../domain/usecases/assignment/get_assignments_usecase.dart';
import '../../domain/usecases/teacher/get_class_students_usecase.dart';
import '../../domain/usecases/teacher/get_classes_usecase.dart';
import '../../domain/usecases/teacher/get_student_detail_usecase.dart';
import '../../domain/usecases/teacher/get_student_progress_usecase.dart';
import '../../domain/usecases/teacher/get_teacher_stats_usecase.dart';
import 'auth_provider.dart';
import 'usecase_providers.dart';

/// Provider for teacher dashboard statistics
final teacherStatsProvider = FutureProvider<TeacherStats>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  debugPrint('teacherStatsProvider: userId = $userId');

  if (userId == null) {
    debugPrint('teacherStatsProvider: userId is null, returning zeros');
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
    (failure) {
      debugPrint('teacherStatsProvider: error = ${failure.message}');
      return const TeacherStats(
        totalStudents: 0,
        totalClasses: 0,
        activeAssignments: 0,
        avgProgress: 0,
      );
    },
    (stats) {
      debugPrint('teacherStatsProvider: success = students:${stats.totalStudents}, classes:${stats.totalClasses}');
      return stats;
    },
  );
});

/// Provider for current teacher's profile
final currentTeacherProfileProvider = FutureProvider<User?>((ref) async {
  final user = ref.watch(authStateChangesProvider).valueOrNull;
  return user;
});

/// Provider for teacher's classes (by school ID)
final teacherClassesProvider = FutureProvider.family<List<TeacherClass>, String>((ref, schoolId) async {
  if (schoolId.isEmpty) {
    return [];
  }

  final useCase = ref.watch(getClassesUseCaseProvider);
  final result = await useCase(GetClassesParams(schoolId: schoolId));

  return result.fold(
    (failure) => [],
    (classes) => classes,
  );
});

/// Provider for current teacher's classes (convenience wrapper)
final currentTeacherClassesProvider = FutureProvider<List<TeacherClass>>((ref) async {
  final user = ref.watch(authStateChangesProvider).valueOrNull;
  if (user == null || user.schoolId.isEmpty) {
    return [];
  }

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
