import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/student_assignment_repository.dart';
import '../../domain/usecases/reading/get_reading_progress_usecase.dart';
import '../../domain/usecases/student_assignment/complete_assignment_usecase.dart';
import '../../domain/entities/student_assignment.dart';
import '../../domain/usecases/student_assignment/get_active_assignments_usecase.dart';
import '../../domain/usecases/student_assignment/get_student_assignment_detail_usecase.dart';
import '../../domain/usecases/student_assignment/get_student_assignments_usecase.dart';
import 'auth_provider.dart';
import 'usecase_providers.dart';

/// Provider for all student assignments
final studentAssignmentsProvider = FutureProvider<List<StudentAssignment>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final useCase = ref.watch(getStudentAssignmentsUseCaseProvider);
  final result = await useCase(GetStudentAssignmentsParams(studentId: userId));

  return result.fold(
    (failure) => [],
    (assignments) => assignments,
  );
});

/// Provider for active assignments only
final activeAssignmentsProvider = FutureProvider<List<StudentAssignment>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  debugPrint('📋 activeAssignmentsProvider: userId=$userId');
  if (userId == null) return [];

  final useCase = ref.watch(getActiveAssignmentsUseCaseProvider);
  final result = await useCase(GetActiveAssignmentsParams(studentId: userId));

  return result.fold(
    (failure) {
      debugPrint('📋 activeAssignmentsProvider: FAILURE=${failure.message}');
      return [];
    },
    (assignments) {
      debugPrint('📋 activeAssignmentsProvider: got ${assignments.length} assignments');
      return assignments;
    },
  );
});

/// Provider for assignment detail
final studentAssignmentDetailProvider = FutureProvider.family<StudentAssignment?, String>(
  (ref, assignmentId) async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return null;

    final useCase = ref.watch(getStudentAssignmentDetailUseCaseProvider);
    final result = await useCase(GetStudentAssignmentDetailParams(
      studentId: userId,
      assignmentId: assignmentId,
    ),);

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
    a.status == StudentAssignmentStatus.overdue,
  ).length;
});

/// Provider that syncs assignment completion with book completion
/// This fixes cases where book was completed but assignment wasn't updated
final assignmentSyncProvider = FutureProvider<void>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return;

  debugPrint('🔄 assignmentSyncProvider: Starting sync...');

  // Get active assignments
  final getActiveAssignmentsUseCase = ref.read(getActiveAssignmentsUseCaseProvider);
  final assignmentsResult = await getActiveAssignmentsUseCase(
    GetActiveAssignmentsParams(studentId: userId),
  );

  final assignments = assignmentsResult.fold(
    (failure) => <StudentAssignment>[],
    (assignments) => assignments,
  );

  debugPrint('🔄 assignmentSyncProvider: Found ${assignments.length} active assignments');

  // Check each book assignment
  final getReadingProgressUseCase = ref.read(getReadingProgressUseCaseProvider);
  final completeAssignmentUseCase = ref.read(completeAssignmentUseCaseProvider);
  var syncedCount = 0;

  for (final assignment in assignments) {
    // Only check book assignments that aren't already completed
    if (assignment.bookId != null &&
        assignment.status != StudentAssignmentStatus.completed) {
      // Check if the book is completed
      final progressResult = await getReadingProgressUseCase(
        GetReadingProgressParams(userId: userId, bookId: assignment.bookId!),
      );

      final isBookCompleted = progressResult.fold(
        (failure) => false,
        (progress) => progress.isCompleted,
      );

      if (isBookCompleted) {
        debugPrint('🔄 Syncing: Assignment "${assignment.title}" - book is completed but assignment not');
        // Auto-complete the assignment
        await completeAssignmentUseCase(CompleteAssignmentParams(
          studentId: userId,
          assignmentId: assignment.assignmentId,
          score: null,
        ));
        syncedCount++;
      }
    }
  }

  if (syncedCount > 0) {
    debugPrint('🔄 assignmentSyncProvider: Synced $syncedCount assignments');
    // Invalidate assignment providers to reflect changes
    ref.invalidate(studentAssignmentsProvider);
    ref.invalidate(activeAssignmentsProvider);
  } else {
    debugPrint('🔄 assignmentSyncProvider: No sync needed');
  }
});
