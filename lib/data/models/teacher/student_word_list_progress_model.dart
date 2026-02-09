import '../../../domain/repositories/teacher_repository.dart';

/// Model for StudentWordListProgress - handles JSON serialization
class StudentWordListProgressModel {

  const StudentWordListProgressModel({
    required this.wordListId,
    required this.wordListName,
    this.wordListLevel,
    required this.wordListCategory,
    required this.wordCount,
    this.bestScore,
    this.bestAccuracy,
    required this.totalSessions,
    this.lastSessionAt,
    this.startedAt,
    this.completedAt,
  });

  factory StudentWordListProgressModel.fromJson(Map<String, dynamic> json) {
    return StudentWordListProgressModel(
      wordListId: json['word_list_id'] as String,
      wordListName: json['word_list_name'] as String,
      wordListLevel: json['word_list_level'] as String?,
      wordListCategory: json['word_list_category'] as String? ?? 'common_words',
      wordCount: (json['word_count'] as num?)?.toInt() ?? 0,
      bestScore: (json['best_score'] as num?)?.toInt(),
      bestAccuracy: (json['best_accuracy'] as num?)?.toDouble(),
      totalSessions: (json['total_sessions'] as num?)?.toInt() ?? 0,
      lastSessionAt: json['last_session_at'] != null
          ? DateTime.parse(json['last_session_at'] as String)
          : null,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }

  final String wordListId;
  final String wordListName;
  final String? wordListLevel;
  final String wordListCategory;
  final int wordCount;
  final int? bestScore;
  final double? bestAccuracy;
  final int totalSessions;
  final DateTime? lastSessionAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  StudentWordListProgress toEntity() {
    return StudentWordListProgress(
      wordListId: wordListId,
      wordListName: wordListName,
      wordListLevel: wordListLevel,
      wordListCategory: wordListCategory,
      wordCount: wordCount,
      bestScore: bestScore,
      bestAccuracy: bestAccuracy,
      totalSessions: totalSessions,
      lastSessionAt: lastSessionAt,
      startedAt: startedAt,
      completedAt: completedAt,
    );
  }
}
