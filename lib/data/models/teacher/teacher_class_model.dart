import '../../../domain/repositories/teacher_repository.dart';

/// Model for TeacherClass - handles JSON serialization
class TeacherClassModel {

  const TeacherClassModel({
    required this.id,
    required this.name,
    this.grade,
    this.academicYear,
    required this.studentCount,
    required this.avgProgress,
    this.createdAt,
  });

  factory TeacherClassModel.fromJson(Map<String, dynamic> json) {
    return TeacherClassModel(
      id: json['id'] as String,
      name: json['name'] as String,
      grade: json['grade'] as int?,
      academicYear: json['academic_year'] as String?,
      studentCount: (json['student_count'] as num?)?.toInt() ?? 0,
      avgProgress: (json['avg_progress'] as num?)?.toDouble() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  factory TeacherClassModel.fromEntity(TeacherClass entity) {
    return TeacherClassModel(
      id: entity.id,
      name: entity.name,
      grade: entity.grade,
      academicYear: entity.academicYear,
      studentCount: entity.studentCount,
      avgProgress: entity.avgProgress,
      createdAt: entity.createdAt,
    );
  }
  final String id;
  final String name;
  final int? grade;
  final String? academicYear;
  final int studentCount;
  final double avgProgress;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'grade': grade,
      'academic_year': academicYear,
      'student_count': studentCount,
      'avg_progress': avgProgress,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  TeacherClass toEntity() {
    return TeacherClass(
      id: id,
      name: name,
      grade: grade,
      academicYear: academicYear,
      studentCount: studentCount,
      avgProgress: avgProgress,
      createdAt: createdAt,
    );
  }
}
