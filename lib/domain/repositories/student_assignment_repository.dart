import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/student_assignment.dart';

/// Repository for student assignment operations
abstract class StudentAssignmentRepository {
  /// Get all assignments for a student
  Future<Either<Failure, List<StudentAssignment>>> getStudentAssignments(
    String studentId,
  );

  /// Get active (current) assignments
  Future<Either<Failure, List<StudentAssignment>>> getActiveAssignments(
    String studentId,
  );

  /// Get assignment detail
  Future<Either<Failure, StudentAssignment>> getAssignmentDetail(
    String studentId,
    String assignmentId,
  );

  /// Start an assignment (update status to in_progress)
  Future<Either<Failure, void>> startAssignment(
    String studentId,
    String assignmentId,
  );

  /// Update assignment progress
  Future<Either<Failure, void>> updateAssignmentProgress(
    String studentId,
    String assignmentId,
    double progress,
  );

  /// Mark assignment as completed
  Future<Either<Failure, void>> completeAssignment(
    String studentId,
    String assignmentId,
    double? score,
  );
}
