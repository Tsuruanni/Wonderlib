import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';

/// Assignment status for students
enum StudentAssignmentStatus {
  pending,
  inProgress,
  completed,
  overdue;

  String get displayName {
    switch (this) {
      case StudentAssignmentStatus.pending:
        return 'Not Started';
      case StudentAssignmentStatus.inProgress:
        return 'In Progress';
      case StudentAssignmentStatus.completed:
        return 'Completed';
      case StudentAssignmentStatus.overdue:
        return 'Overdue';
    }
  }

  static StudentAssignmentStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return StudentAssignmentStatus.pending;
      case 'in_progress':
        return StudentAssignmentStatus.inProgress;
      case 'completed':
        return StudentAssignmentStatus.completed;
      case 'overdue':
        return StudentAssignmentStatus.overdue;
      default:
        return StudentAssignmentStatus.pending;
    }
  }
}

/// Assignment type
enum StudentAssignmentType {
  book,
  vocabulary,
  mixed;

  String get displayName {
    switch (this) {
      case StudentAssignmentType.book:
        return 'Reading';
      case StudentAssignmentType.vocabulary:
        return 'Vocabulary';
      case StudentAssignmentType.mixed:
        return 'Mixed';
    }
  }

  static StudentAssignmentType fromString(String value) {
    switch (value) {
      case 'book':
        return StudentAssignmentType.book;
      case 'vocabulary':
        return StudentAssignmentType.vocabulary;
      case 'mixed':
        return StudentAssignmentType.mixed;
      default:
        return StudentAssignmentType.book;
    }
  }
}

/// Assignment as seen by a student
class StudentAssignment {
  final String id;
  final String assignmentId;
  final String title;
  final String? description;
  final StudentAssignmentType type;
  final StudentAssignmentStatus status;
  final double progress;
  final double? score;
  final String? teacherName;
  final String? className;
  final DateTime startDate;
  final DateTime dueDate;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final Map<String, dynamic> contentConfig;

  const StudentAssignment({
    required this.id,
    required this.assignmentId,
    required this.title,
    this.description,
    required this.type,
    required this.status,
    required this.progress,
    this.score,
    this.teacherName,
    this.className,
    required this.startDate,
    required this.dueDate,
    this.startedAt,
    this.completedAt,
    required this.contentConfig,
  });

  bool get isOverdue =>
      status != StudentAssignmentStatus.completed &&
      DateTime.now().isAfter(dueDate);

  bool get isActive =>
      DateTime.now().isAfter(startDate) && DateTime.now().isBefore(dueDate);

  bool get isUpcoming => DateTime.now().isBefore(startDate);

  int get daysRemaining {
    final now = DateTime.now();
    if (now.isAfter(dueDate)) return 0;
    return dueDate.difference(now).inDays;
  }

  /// Get book ID if this is a book assignment
  String? get bookId {
    if (type == StudentAssignmentType.book || type == StudentAssignmentType.mixed) {
      return contentConfig['bookId'] as String?;
    }
    return null;
  }

  /// Get chapter IDs if this is a book assignment
  List<String> get chapterIds {
    if (type == StudentAssignmentType.book || type == StudentAssignmentType.mixed) {
      final ids = contentConfig['chapterIds'] as List?;
      return ids?.map((e) => e.toString()).toList() ?? [];
    }
    return [];
  }
}

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
