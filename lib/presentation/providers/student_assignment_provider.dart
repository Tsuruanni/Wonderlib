import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/student_assignment.dart';
import '../../domain/entities/unit_assignment_item.dart';
import '../../domain/usecases/reading/get_reading_progress_usecase.dart';
import '../../domain/usecases/student_assignment/calculate_unit_progress_usecase.dart';
import '../../domain/usecases/student_assignment/complete_assignment_usecase.dart';
import '../../domain/usecases/student_assignment/get_active_assignments_usecase.dart';
import '../../domain/usecases/student_assignment/get_student_assignment_detail_usecase.dart';
import '../../domain/usecases/student_assignment/get_student_assignments_usecase.dart';
import '../../domain/usecases/student_assignment/get_unit_assignment_items_usecase.dart';
import '../../domain/usecases/student_assignment/start_assignment_usecase.dart';
import 'auth_provider.dart';
import 'usecase_providers.dart';

/// Assignment notification event — fired when student has active assignments on app open
class AssignmentNotificationEvent {
  const AssignmentNotificationEvent({required this.count, this.assignmentId});
  final int count;
  /// When count == 1, holds the single assignment's ID for direct navigation
  final String? assignmentId;
}

/// Provider for assignment notification events — UI listens to show dialog
final assignmentNotificationEventProvider =
    StateProvider<AssignmentNotificationEvent?>((ref) => null);

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
  if (userId == null) return [];

  final useCase = ref.watch(getActiveAssignmentsUseCaseProvider);
  final result = await useCase(GetActiveAssignmentsParams(studentId: userId));

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

/// Provider that syncs assignment completion with book/unit completion.
/// Debounced: only runs once per keepAlive cycle (not on every screen open).
final assignmentSyncProvider = FutureProvider<void>((ref) async {
  // Keep alive for 60 seconds — prevents re-running on every screen open
  final link = ref.keepAlive();
  Future.delayed(const Duration(seconds: 60), link.close);

  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return;

  final getActiveAssignmentsUseCase = ref.read(getActiveAssignmentsUseCaseProvider);
  final assignmentsResult = await getActiveAssignmentsUseCase(
    GetActiveAssignmentsParams(studentId: userId),
  );

  final assignments = assignmentsResult.fold(
    (failure) => <StudentAssignment>[],
    (assignments) => assignments,
  );

  final getReadingProgressUseCase = ref.read(getReadingProgressUseCaseProvider);
  final completeAssignmentUseCase = ref.read(completeAssignmentUseCaseProvider);
  var syncedCount = 0;

  for (final assignment in assignments) {
    if (assignment.status == StudentAssignmentStatus.completed) continue;

    // Sync book assignments
    if (assignment.bookId != null) {
      final progressResult = await getReadingProgressUseCase(
        GetReadingProgressParams(userId: userId, bookId: assignment.bookId!),
      );

      final isBookCompleted = progressResult.fold(
        (failure) => false,
        (progress) => progress.isCompleted,
      );

      if (isBookCompleted) {
        await completeAssignmentUseCase(CompleteAssignmentParams(
          studentId: userId,
          assignmentId: assignment.assignmentId,
          score: null,
        ));
        syncedCount++;
      }
    }

    // Sync unit assignments (server-side recalculates from current state)
    if (assignment.scopeLpUnitId != null) {
      final calculateUseCase = ref.read(calculateUnitProgressUseCaseProvider);
      await calculateUseCase(CalculateUnitProgressParams(
        assignmentId: assignment.assignmentId,
        studentId: userId,
      ));
      syncedCount++;
    }
  }

  if (syncedCount > 0) {
    ref.invalidate(studentAssignmentsProvider);
    ref.invalidate(activeAssignmentsProvider);
  }
});

/// Controller for student assignment mutations (start, navigation)
class StudentAssignmentController extends StateNotifier<AsyncValue<void>> {
  StudentAssignmentController(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  bool get isMutating => state is AsyncLoading;

  Future<String?> startAssignment(String assignmentId) async {
    if (isMutating) return null;
    state = const AsyncValue.loading();
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) {
      state = const AsyncValue.data(null);
      return 'Not logged in';
    }
    final useCase = _ref.read(startAssignmentUseCaseProvider);
    final result = await useCase(StartAssignmentParams(
      studentId: userId,
      assignmentId: assignmentId,
    ));
    return result.fold(
      (failure) {
        state = const AsyncValue.data(null);
        return failure.message;
      },
      (_) {
        _ref.invalidate(studentAssignmentDetailProvider(assignmentId));
        _ref.invalidate(studentAssignmentsProvider);
        _ref.invalidate(activeAssignmentsProvider);
        state = const AsyncValue.data(null);
        return null;
      },
    );
  }
}

final studentAssignmentControllerProvider =
    StateNotifierProvider.autoDispose<StudentAssignmentController, AsyncValue<void>>((ref) {
  return StudentAssignmentController(ref);
});

/// Provider for unit assignment items (student detail screen)
final unitAssignmentItemsProvider =
    FutureProvider.family<List<UnitAssignmentItem>, ({String scopeLpUnitId, String studentId})>(
  (ref, params) async {
    final useCase = ref.watch(getUnitAssignmentItemsUseCaseProvider);
    final result = await useCase(GetUnitAssignmentItemsParams(
      scopeLpUnitId: params.scopeLpUnitId,
      studentId: params.studentId,
    ));

    return result.fold(
      (failure) => [],
      (items) => items,
    );
  },
);
