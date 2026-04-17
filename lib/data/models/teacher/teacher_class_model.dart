import '../../../domain/repositories/teacher_repository.dart';

/// Model for TeacherClass - handles JSON serialization
class TeacherClassModel {

  const TeacherClassModel({
    required this.id,
    required this.name,
    required this.grade,
    this.academicYear,
    this.description,
    required this.studentCount,
    required this.avgProgress,
    this.avgXp = 0,
    this.avgStreak = 0,
    this.totalReadingTime = 0,
    this.completedBooks = 0,
    this.activeLast30d = 0,
    this.totalVocabWords = 0,
    this.maxLevel = 0,
    this.createdAt,
  });

  factory TeacherClassModel.fromJson(Map<String, dynamic> json) {
    return TeacherClassModel(
      id: json['id'] as String,
      name: json['name'] as String,
      grade: (json['grade'] as num?)?.toInt() ?? 0,
      academicYear: json['academic_year'] as String?,
      description: json['description'] as String?,
      studentCount: (json['student_count'] as num?)?.toInt() ?? 0,
      avgProgress: (json['avg_progress'] as num?)?.toDouble() ?? 0,
      avgXp: (json['avg_xp'] as num?)?.toDouble() ?? 0,
      avgStreak: (json['avg_streak'] as num?)?.toDouble() ?? 0,
      totalReadingTime: (json['total_reading_time'] as num?)?.toInt() ?? 0,
      completedBooks: (json['completed_books'] as num?)?.toInt() ?? 0,
      activeLast30d: (json['active_last_30d'] as num?)?.toInt() ?? 0,
      totalVocabWords: (json['total_vocab_words'] as num?)?.toInt() ?? 0,
      maxLevel: (json['max_level'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  final String id;
  final String name;
  final int grade;
  final String? academicYear;
  final String? description;
  final int studentCount;
  final double avgProgress;
  final double avgXp;
  final double avgStreak;
  final int totalReadingTime;
  final int completedBooks;
  final int activeLast30d;
  final int totalVocabWords;
  final int maxLevel;
  final DateTime? createdAt;

  TeacherClass toEntity() {
    return TeacherClass(
      id: id,
      name: name,
      grade: grade,
      academicYear: academicYear,
      description: description,
      studentCount: studentCount,
      avgProgress: avgProgress,
      avgXp: avgXp,
      avgStreak: avgStreak,
      totalReadingTime: totalReadingTime,
      completedBooks: completedBooks,
      activeLast30d: activeLast30d,
      totalVocabWords: totalVocabWords,
      maxLevel: maxLevel,
      createdAt: createdAt,
    );
  }
}
