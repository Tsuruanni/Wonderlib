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
    if (statusStr != 'completed' && DateTime.now().isAfter(dueDate)) {
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

  factory StudentAssignmentModel.fromEntity(StudentAssignment entity) {
    return StudentAssignmentModel(
      id: entity.id,
      assignmentId: entity.assignmentId,
      title: entity.title,
      description: entity.description,
      type: _typeToString(entity.type),
      status: _statusToString(entity.status),
      progress: entity.progress,
      score: entity.score,
      teacherName: entity.teacherName,
      className: entity.className,
      startDate: entity.startDate,
      dueDate: entity.dueDate,
      startedAt: entity.startedAt,
      completedAt: entity.completedAt,
      contentConfig: entity.contentConfig,
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assignment_id': assignmentId,
      'title': title,
      'description': description,
      'type': type,
      'status': status,
      'progress': progress,
      'score': score,
      'teacher_name': teacherName,
      'class_name': className,
      'start_date': startDate.toIso8601String(),
      'due_date': dueDate.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'content_config': contentConfig,
    };
  }

  StudentAssignment toEntity() {
    return StudentAssignment(
      id: id,
      assignmentId: assignmentId,
      title: title,
      description: description,
      type: StudentAssignmentType.fromString(type),
      status: StudentAssignmentStatus.fromString(status),
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

  static String _typeToString(StudentAssignmentType type) {
    switch (type) {
      case StudentAssignmentType.book:
        return 'book';
      case StudentAssignmentType.vocabulary:
        return 'vocabulary';
      case StudentAssignmentType.mixed:
        return 'mixed';
    }
  }

  static String _statusToString(StudentAssignmentStatus status) {
    switch (status) {
      case StudentAssignmentStatus.pending:
        return 'pending';
      case StudentAssignmentStatus.inProgress:
        return 'in_progress';
      case StudentAssignmentStatus.completed:
        return 'completed';
      case StudentAssignmentStatus.overdue:
        return 'overdue';
    }
  }
}
