import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/supabase/supabase_student_assignment_repository.dart';
import '../../domain/repositories/student_assignment_repository.dart';
import 'auth_provider.dart';

/// Provider for student assignment repository
final studentAssignmentRepositoryProvider = Provider<StudentAssignmentRepository>((ref) {
  return SupabaseStudentAssignmentRepository();
});

/// Provider for all student assignments
final studentAssignmentsProvider = FutureProvider<List<StudentAssignment>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final repo = ref.watch(studentAssignmentRepositoryProvider);
  final result = await repo.getStudentAssignments(userId);

  return result.fold(
    (failure) => [],
    (assignments) => assignments,
  );
});

/// Provider for active assignments only
final activeAssignmentsProvider = FutureProvider<List<StudentAssignment>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final repo = ref.watch(studentAssignmentRepositoryProvider);
  final result = await repo.getActiveAssignments(userId);

  return result.fold(
    (failure) => [],
    (assignments) => assignments,
  );
});

/// Provider for assignment detail
final studentAssignmentDetailProvider = FutureProvider.family<StudentAssignment?, String>(
  (ref, assignmentId) async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return null;

    final repo = ref.watch(studentAssignmentRepositoryProvider);
    final result = await repo.getAssignmentDetail(userId, assignmentId);

    return result.fold(
      (failure) => null,
      (assignment) => assignment,
    );
  },
);

/// Provider for pending assignment count (for badge on home)
final pendingAssignmentCountProvider = FutureProvider<int>((ref) async {
  final assignments = await ref.watch(activeAssignmentsProvider.future);
  return assignments.where((a) =>
    a.status == StudentAssignmentStatus.pending ||
    a.status == StudentAssignmentStatus.inProgress ||
    a.status == StudentAssignmentStatus.overdue
  ).length;
});
