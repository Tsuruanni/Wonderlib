import '../../../core/utils/app_clock.dart';
import '../../../domain/entities/student_assignment.dart';

/// Model for StudentAssignment - handles JSON serialization
class StudentAssignmentModel {

  const StudentAssignmentModel({
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

  factory StudentAssignmentModel.fromJson(Map<String, dynamic> json) {
    final assignmentData = json['assignments'] as Map<String, dynamic>?;

    if (assignmentData == null) {
      throw const FormatException('Missing assignments data in JSON');
    }

    final teacherData = assignmentData['profiles'] as Map<String, dynamic>?;
    final classData = assignmentData['classes'] as Map<String, dynamic>?;

    String? teacherName;
    if (teacherData != null) {
      final firstName = teacherData['first_name'] as String? ?? '';
      final lastName = teacherData['last_name'] as String? ?? '';
      teacherName = '$firstName $lastName'.trim();
      if (teacherName.isEmpty) teacherName = null;
    }

    final dueDate = DateTime.parse(assignmentData['due_date'] as String);
    final statusStr = json['status'] as String? ?? 'pending';

    // Check if overdue
    String finalStatus = statusStr;
    if (statusStr != 'completed' && AppClock.now().isAfter(dueDate)) {
      finalStatus = 'overdue';
    }

    return StudentAssignmentModel(
      id: json['id'] as String,
      assignmentId: assignmentData['id'] as String,
      title: assignmentData['title'] as String,
      description: assignmentData['description'] as String?,
      type: assignmentData['type'] as String,
      status: finalStatus,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      score: (json['score'] as num?)?.toDouble(),
      teacherName: teacherName,
      className: classData?['name'] as String?,
      startDate: DateTime.parse(assignmentData['start_date'] as String),
      dueDate: dueDate,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      contentConfig: (assignmentData['content_config'] as Map<String, dynamic>?) ?? {},
    );
  }

  final String id;
  final String assignmentId;
  final String title;
  final String? description;
  final String type;
  final String status;
  final double progress;
  final double? score;
  final String? teacherName;
  final String? className;
  final DateTime startDate;
  final DateTime dueDate;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final Map<String, dynamic> contentConfig;

  StudentAssignment toEntity() {
    return StudentAssignment(
      id: id,
      assignmentId: assignmentId,
      title: title,
      description: description,
      type: StudentAssignmentType.fromDbValue(type),
      status: StudentAssignmentStatus.fromDbValue(status),
      progress: progress,
      score: score,
      teacherName: teacherName,
      className: className,
      startDate: startDate,
      dueDate: dueDate,
      startedAt: startedAt,
      completedAt: completedAt,
      contentConfig: contentConfig,
    );
  }

}
