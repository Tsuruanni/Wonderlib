import 'package:equatable/equatable.dart';
import 'package:owlio_shared/owlio_shared.dart';

export 'package:owlio_shared/src/enums/assignment_type.dart';
export 'package:owlio_shared/src/enums/assignment_status.dart';

/// Assignment entity for teacher view
class Assignment extends Equatable {

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

  @override
  List<Object?> get props => [id, teacherId, classId, className, type, title, description, contentConfig, startDate, dueDate, createdAt, totalStudents, completedStudents];
}

/// Student's progress on a specific assignment
class AssignmentStudent extends Equatable {

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

  @override
  List<Object?> get props => [id, studentId, studentName, avatarUrl, status, progress, score, startedAt, completedAt];
}

/// Data for creating a new assignment
class CreateAssignmentData extends Equatable {

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

  @override
  List<Object?> get props => [classId, studentIds, type, title, description, contentConfig, startDate, dueDate];
}
