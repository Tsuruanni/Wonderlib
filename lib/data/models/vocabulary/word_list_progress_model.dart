import '../../../domain/entities/word_list.dart';

/// Model for UserWordListProgress entity - handles JSON serialization
class WordListProgressModel {

  const WordListProgressModel({
    required this.id,
    required this.userId,
    required this.wordListId,
    this.bestScore,
    this.bestAccuracy,
    this.totalSessions = 0,
    this.lastSessionAt,
    this.startedAt,
    this.completedAt,
    required this.updatedAt,
  });

  factory WordListProgressModel.fromJson(Map<String, dynamic> json) {
    return WordListProgressModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      wordListId: json['word_list_id'] as String,
      bestScore: json['best_score'] as int?,
      bestAccuracy: json['best_accuracy'] != null
          ? (json['best_accuracy'] as num).toDouble()
          : null,
      totalSessions: json['total_sessions'] as int? ?? 0,
      lastSessionAt: json['last_session_at'] != null
          ? DateTime.parse(json['last_session_at'] as String)
          : null,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  factory WordListProgressModel.fromEntity(UserWordListProgress entity) {
    return WordListProgressModel(
      id: entity.id,
      userId: entity.userId,
      wordListId: entity.wordListId,
      bestScore: entity.bestScore,
      bestAccuracy: entity.bestAccuracy,
      totalSessions: entity.totalSessions,
      lastSessionAt: entity.lastSessionAt,
      startedAt: entity.startedAt,
      completedAt: entity.completedAt,
      updatedAt: entity.updatedAt,
    );
  }

  final String id;
  final String userId;
  final String wordListId;
  final int? bestScore;
  final double? bestAccuracy;
  final int totalSessions;
  final DateTime? lastSessionAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'word_list_id': wordListId,
      'best_score': bestScore,
      'best_accuracy': bestAccuracy,
      'total_sessions': totalSessions,
      'last_session_at': lastSessionAt?.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserWordListProgress toEntity() {
    return UserWordListProgress(
      id: id,
      userId: userId,
      wordListId: wordListId,
      bestScore: bestScore,
      bestAccuracy: bestAccuracy,
      totalSessions: totalSessions,
      lastSessionAt: lastSessionAt,
      startedAt: startedAt,
      completedAt: completedAt,
      updatedAt: updatedAt,
    );
  }
}
