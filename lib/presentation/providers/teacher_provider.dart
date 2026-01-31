import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/user.dart';
import '../../domain/repositories/teacher_repository.dart';
import 'auth_provider.dart';
import 'repository_providers.dart';

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

  final teacherRepo = ref.watch(teacherRepositoryProvider);
  final result = await teacherRepo.getTeacherStats(userId);

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

/// Provider for teacher's classes
final teacherClassesProvider = FutureProvider<List<TeacherClass>>((ref) async {
  final user = ref.watch(authStateChangesProvider).valueOrNull;
  if (user == null || user.schoolId.isEmpty) {
    return [];
  }

  final teacherRepo = ref.watch(teacherRepositoryProvider);
  final result = await teacherRepo.getClasses(user.schoolId);

  return result.fold(
    (failure) => [],
    (classes) => classes,
  );
});

/// Provider for students in a specific class
final classStudentsProvider =
    FutureProvider.family<List<StudentSummary>, String>((ref, classId) async {
  final teacherRepo = ref.watch(teacherRepositoryProvider);
  final result = await teacherRepo.getClassStudents(classId);

  return result.fold(
    (failure) => [],
    (students) => students,
  );
});

/// Provider for detailed student info
final studentDetailProvider =
    FutureProvider.family<User?, String>((ref, studentId) async {
  final teacherRepo = ref.watch(teacherRepositoryProvider);
  final result = await teacherRepo.getStudentDetail(studentId);

  return result.fold(
    (failure) => null,
    (user) => user,
  );
});

/// Provider for student's book progress
final studentProgressProvider =
    FutureProvider.family<List<StudentBookProgress>, String>((ref, studentId) async {
  final teacherRepo = ref.watch(teacherRepositoryProvider);
  final result = await teacherRepo.getStudentProgress(studentId);

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

  final teacherRepo = ref.watch(teacherRepositoryProvider);
  final result = await teacherRepo.getAssignments(userId);

  return result.fold(
    (failure) => [],
    (assignments) => assignments,
  );
});

/// Provider for assignment detail
final assignmentDetailProvider =
    FutureProvider.family<Assignment?, String>((ref, assignmentId) async {
  final teacherRepo = ref.watch(teacherRepositoryProvider);
  final result = await teacherRepo.getAssignmentDetail(assignmentId);

  return result.fold(
    (failure) => null,
    (assignment) => assignment,
  );
});

/// Provider for students in an assignment
final assignmentStudentsProvider =
    FutureProvider.family<List<AssignmentStudent>, String>((ref, assignmentId) async {
  final teacherRepo = ref.watch(teacherRepositoryProvider);
  final result = await teacherRepo.getAssignmentStudents(assignmentId);

  return result.fold(
    (failure) => [],
    (students) => students,
  );
});
