import '../../../domain/repositories/teacher_repository.dart';

/// Model for Assignment - handles JSON serialization
class AssignmentModel {

  const AssignmentModel({
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

  factory AssignmentModel.fromJson(Map<String, dynamic> json, {int? totalStudents, int? completedStudents}) {
    final classData = json['classes'] as Map<String, dynamic>?;

    return AssignmentModel(
      id: json['id'] as String,
      teacherId: json['teacher_id'] as String,
      classId: json['class_id'] as String?,
      className: json['class_name'] as String? ?? classData?['name'] as String?,
      type: json['type'] as String? ?? 'book',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      contentConfig: (json['content_config'] as Map<String, dynamic>?) ?? {},
      startDate: DateTime.parse(json['start_date'] as String),
      dueDate: DateTime.parse(json['due_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      totalStudents: totalStudents ?? (json['total_students'] as num?)?.toInt() ?? 0,
      completedStudents: completedStudents ?? (json['completed_students'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String teacherId;
  final String? classId;
  final String? className;
  final String type;
  final String title;
  final String? description;
  final Map<String, dynamic> contentConfig;
  final DateTime startDate;
  final DateTime dueDate;
  final DateTime createdAt;
  final int totalStudents;
  final int completedStudents;

  Assignment toEntity() {
    return Assignment(
      id: id,
      teacherId: teacherId,
      classId: classId,
      className: className,
      type: AssignmentType.fromDbValue(type),
      title: title,
      description: description,
      contentConfig: contentConfig,
      startDate: startDate,
      dueDate: dueDate,
      createdAt: createdAt,
      totalStudents: totalStudents,
      completedStudents: completedStudents,
    );
  }
}
