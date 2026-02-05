import '../../../domain/entities/daily_review_session.dart';

/// Model for DailyReviewSession - handles JSON serialization
class DailyReviewSessionModel {
  const DailyReviewSessionModel({
    required this.id,
    required this.userId,
    required this.sessionDate,
    required this.wordsReviewed,
    required this.correctCount,
    required this.incorrectCount,
    required this.xpEarned,
    required this.isPerfect,
    required this.completedAt,
  });

  factory DailyReviewSessionModel.fromJson(Map<String, dynamic> json) {
    return DailyReviewSessionModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      sessionDate: DateTime.parse(json['session_date'] as String),
      wordsReviewed: json['words_reviewed'] as int? ?? 0,
      correctCount: json['correct_count'] as int? ?? 0,
      incorrectCount: json['incorrect_count'] as int? ?? 0,
      xpEarned: json['xp_earned'] as int? ?? 0,
      isPerfect: json['is_perfect'] as bool? ?? false,
      completedAt: DateTime.parse(json['completed_at'] as String),
    );
  }

  factory DailyReviewSessionModel.fromEntity(DailyReviewSession entity) {
    return DailyReviewSessionModel(
      id: entity.id,
      userId: entity.userId,
      sessionDate: entity.sessionDate,
      wordsReviewed: entity.wordsReviewed,
      correctCount: entity.correctCount,
      incorrectCount: entity.incorrectCount,
      xpEarned: entity.xpEarned,
      isPerfect: entity.isPerfect,
      completedAt: entity.completedAt,
    );
  }

  final String id;
  final String userId;
  final DateTime sessionDate;
  final int wordsReviewed;
  final int correctCount;
  final int incorrectCount;
  final int xpEarned;
  final bool isPerfect;
  final DateTime completedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'session_date': sessionDate.toIso8601String().split('T').first,
      'words_reviewed': wordsReviewed,
      'correct_count': correctCount,
      'incorrect_count': incorrectCount,
      'xp_earned': xpEarned,
      'is_perfect': isPerfect,
      'completed_at': completedAt.toIso8601String(),
    };
  }

  DailyReviewSession toEntity() {
    return DailyReviewSession(
      id: id,
      userId: userId,
      sessionDate: sessionDate,
      wordsReviewed: wordsReviewed,
      correctCount: correctCount,
      incorrectCount: incorrectCount,
      xpEarned: xpEarned,
      isPerfect: isPerfect,
      completedAt: completedAt,
    );
  }
}

/// Model for DailyReviewResult - handles RPC response parsing
class DailyReviewResultModel {
  const DailyReviewResultModel({
    required this.sessionId,
    required this.totalXp,
    required this.isNewSession,
    required this.isPerfect,
  });

  factory DailyReviewResultModel.fromJson(Map<String, dynamic> json) {
    return DailyReviewResultModel(
      sessionId: json['session_id'] as String,
      totalXp: json['total_xp'] as int? ?? 0,
      isNewSession: json['is_new_session'] as bool? ?? false,
      isPerfect: json['is_perfect'] as bool? ?? false,
    );
  }

  final String sessionId;
  final int totalXp;
  final bool isNewSession;
  final bool isPerfect;

  DailyReviewResult toEntity() {
    return DailyReviewResult(
      sessionId: sessionId,
      xpEarned: totalXp,
      isNewSession: isNewSession,
      isPerfect: isPerfect,
    );
  }
}
