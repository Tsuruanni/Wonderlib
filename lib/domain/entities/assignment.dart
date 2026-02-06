/// Assignment type enum
enum AssignmentType {
  book,
  vocabulary,
  mixed;

  String get displayName {
    switch (this) {
      case AssignmentType.book:
        return 'Book Reading';
      case AssignmentType.vocabulary:
        return 'Vocabulary';
      case AssignmentType.mixed:
        return 'Mixed';
    }
  }

  static AssignmentType fromString(String value) {
    switch (value) {
      case 'book':
        return AssignmentType.book;
      case 'vocabulary':
        return AssignmentType.vocabulary;
      case 'mixed':
        return AssignmentType.mixed;
      default:
        return AssignmentType.book;
    }
  }
}

/// Assignment status for students
enum AssignmentStatus {
  pending,
  inProgress,
  completed,
  overdue;

  String get displayName {
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

  static AssignmentStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return AssignmentStatus.pending;
      case 'in_progress':
        return AssignmentStatus.inProgress;
      case 'completed':
        return AssignmentStatus.completed;
      case 'overdue':
        return AssignmentStatus.overdue;
      default:
        return AssignmentStatus.pending;
    }
  }
}

/// Assignment entity for teacher view
class Assignment {

  const Assignment({
    required this.id,
    required this.teacherId,
    this.classId,
    this.className,
    required this.type,
    required this.title,
    this.description,
    required this.contentConfig,
    required this.startDate,
    required this.dueDate,
    required this.createdAt,
    required this.totalStudents,
    required this.completedStudents,
  });
  final String id;
  final String teacherId;
  final String? classId;
  final String? className;
  final AssignmentType type;
  final String title;
  final String? description;
  final Map<String, dynamic> contentConfig;
  final DateTime startDate;
  final DateTime dueDate;
  final DateTime createdAt;
  final int totalStudents;
  final int completedStudents;

  double get completionRate =>
      totalStudents > 0 ? (completedStudents / totalStudents) * 100 : 0;

  bool get isOverdue => DateTime.now().isAfter(dueDate);
  bool get isActive =>
      DateTime.now().isAfter(startDate) && DateTime.now().isBefore(dueDate);
  bool get isUpcoming => DateTime.now().isBefore(startDate);
}

/// Student's progress on a specific assignment
class AssignmentStudent {

  const AssignmentStudent({
    required this.id,
    required this.studentId,
    required this.studentName,
    this.avatarUrl,
    required this.status,
    required this.progress,
    this.score,
    this.startedAt,
    this.completedAt,
  });
  final String id;
  final String studentId;
  final String studentName;
  final String? avatarUrl;
  final AssignmentStatus status;
  final double progress;
  final double? score;
  final DateTime? startedAt;
  final DateTime? completedAt;
}

/// Data for creating a new assignment
class CreateAssignmentData {

  const CreateAssignmentData({
    this.classId,
    this.studentIds,
    required this.type,
    required this.title,
    this.description,
    required this.contentConfig,
    required this.startDate,
    required this.dueDate,
  });
  final String? classId;
  final List<String>? studentIds;
  final AssignmentType type;
  final String title;
  final String? description;
  final Map<String, dynamic> contentConfig;
  final DateTime startDate;
  final DateTime dueDate;
}
