import '../../../domain/repositories/teacher_repository.dart';

/// Model for StudentVocabStats - handles JSON serialization
class StudentVocabStatsModel {

  const StudentVocabStatsModel({
    required this.totalWords,
    required this.newCount,
    required this.learningCount,
    required this.reviewingCount,
    required this.masteredCount,
    required this.listsStarted,
    required this.listsCompleted,
    required this.totalSessions,
  });

  factory StudentVocabStatsModel.fromJson(Map<String, dynamic> json) {
    return StudentVocabStatsModel(
      totalWords: (json['total_words'] as num?)?.toInt() ?? 0,
      newCount: (json['new_count'] as num?)?.toInt() ?? 0,
      learningCount: (json['learning_count'] as num?)?.toInt() ?? 0,
      reviewingCount: (json['reviewing_count'] as num?)?.toInt() ?? 0,
      masteredCount: (json['mastered_count'] as num?)?.toInt() ?? 0,
      listsStarted: (json['lists_started'] as num?)?.toInt() ?? 0,
      listsCompleted: (json['lists_completed'] as num?)?.toInt() ?? 0,
      totalSessions: (json['total_sessions'] as num?)?.toInt() ?? 0,
    );
  }

  final int totalWords;
  final int newCount;
  final int learningCount;
  final int reviewingCount;
  final int masteredCount;
  final int listsStarted;
  final int listsCompleted;
  final int totalSessions;

  StudentVocabStats toEntity() {
    return StudentVocabStats(
      totalWords: totalWords,
      newCount: newCount,
      learningCount: learningCount,
      reviewingCount: reviewingCount,
      masteredCount: masteredCount,
      listsStarted: listsStarted,
      listsCompleted: listsCompleted,
      totalSessions: totalSessions,
    );
  }
}
