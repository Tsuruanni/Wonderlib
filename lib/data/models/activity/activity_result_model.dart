import '../../../domain/entities/activity.dart';

/// Model for ActivityResult entity - handles JSON serialization
class ActivityResultModel {
  final String id;
  final String userId;
  final String activityId;
  final double score;
  final double maxScore;
  final Map<String, dynamic> answers;
  final int? timeSpent;
  final int attemptNumber;
  final DateTime completedAt;

  const ActivityResultModel({
    required this.id,
    required this.userId,
    required this.activityId,
    required this.score,
    required this.maxScore,
    required this.answers,
    this.timeSpent,
    this.attemptNumber = 1,
    required this.completedAt,
  });

  factory ActivityResultModel.fromJson(Map<String, dynamic> json) {
    return ActivityResultModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      activityId: json['activity_id'] as String,
      score: (json['score'] as num).toDouble(),
      maxScore: (json['max_score'] as num).toDouble(),
      answers: (json['answers'] as Map<String, dynamic>?) ?? {},
      timeSpent: json['time_spent'] as int?,
      attemptNumber: json['attempt_number'] as int? ?? 1,
      completedAt: DateTime.parse(json['completed_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'activity_id': activityId,
      'score': score,
      'max_score': maxScore,
      'answers': answers,
      'time_spent': timeSpent,
      'attempt_number': attemptNumber,
      'completed_at': completedAt.toIso8601String(),
    };
  }

  /// Converts to JSON for insert (without ID, as it's auto-generated)
  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'activity_id': activityId,
      'score': score,
      'max_score': maxScore,
      'answers': answers,
      'time_spent': timeSpent,
      'attempt_number': attemptNumber,
      'completed_at': completedAt.toIso8601String(),
    };
  }

  ActivityResult toEntity() {
    return ActivityResult(
      id: id,
      userId: userId,
      activityId: activityId,
      score: score,
      maxScore: maxScore,
      answers: answers,
      timeSpent: timeSpent,
      attemptNumber: attemptNumber,
      completedAt: completedAt,
    );
  }

  factory ActivityResultModel.fromEntity(ActivityResult entity) {
    return ActivityResultModel(
      id: entity.id,
      userId: entity.userId,
      activityId: entity.activityId,
      score: entity.score,
      maxScore: entity.maxScore,
      answers: entity.answers,
      timeSpent: entity.timeSpent,
      attemptNumber: entity.attemptNumber,
      completedAt: entity.completedAt,
    );
  }
}
