import 'package:equatable/equatable.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../core/utils/app_clock.dart';

// Re-export shared enums with student-facing typedefs for backwards compat.
// Both teacher and student sides now use the same underlying enum.
typedef StudentAssignmentStatus = AssignmentStatus;
typedef StudentAssignmentType = AssignmentType;

/// Student-facing display names (slightly different from teacher-side).
extension StudentAssignmentStatusDisplay on AssignmentStatus {
  String get studentDisplayName {
    switch (this) {
      case AssignmentStatus.pending:
        return 'Not Started';
      case AssignmentStatus.inProgress:
        return 'In Progress';
      case AssignmentStatus.completed:
        return 'Completed';
      case AssignmentStatus.overdue:
        return 'Overdue';
    }
  }

  /// Backwards compat: fromString maps to fromDbValue.
  static AssignmentStatus fromString(String value) =>
      AssignmentStatus.fromDbValue(value);
}

extension StudentAssignmentTypeDisplay on AssignmentType {
  String get studentDisplayName {
    switch (this) {
      case AssignmentType.book:
        return 'Reading';
      case AssignmentType.vocabulary:
        return 'Vocabulary';
      case AssignmentType.mixed:
        return 'Mixed';
    }
  }

  /// Backwards compat: fromString maps to fromDbValue.
  static AssignmentType fromString(String value) =>
      AssignmentType.fromDbValue(value);
}

/// Assignment as seen by a student
class StudentAssignment extends Equatable {

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

  @override
  List<Object?> get props => [
        id,
        assignmentId,
        title,
        description,
        type,
        status,
        progress,
        score,
        teacherName,
        className,
        startDate,
        dueDate,
        startedAt,
        completedAt,
        contentConfig,
      ];

  bool get isOverdue =>
      status != StudentAssignmentStatus.completed &&
      AppClock.now().isAfter(dueDate);

  bool get isActive =>
      AppClock.now().isAfter(startDate) && AppClock.now().isBefore(dueDate);

  bool get isUpcoming => AppClock.now().isBefore(startDate);

  int get daysRemaining {
    final now = AppClock.now();
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

  /// Get word list ID if this is a vocabulary assignment
  String? get wordListId {
    if (type == StudentAssignmentType.vocabulary) {
      return contentConfig['wordListId'] as String?;
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
