import '../../../domain/entities/book_quiz.dart';

/// Model for BookQuizResult entity - handles JSON serialization
class BookQuizResultModel {
  const BookQuizResultModel({
    required this.id,
    required this.userId,
    required this.quizId,
    required this.bookId,
    required this.score,
    required this.maxScore,
    required this.percentage,
    required this.isPassing,
    required this.answers,
    this.timeSpent,
    this.attemptNumber = 1,
    required this.completedAt,
  });

  factory BookQuizResultModel.fromJson(Map<String, dynamic> json) {
    return BookQuizResultModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      quizId: json['quiz_id'] as String,
      bookId: json['book_id'] as String,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      maxScore: (json['max_score'] as num?)?.toDouble() ?? 0.0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      isPassing: json['is_passing'] as bool? ?? false,
      answers: json['answers'] as Map<String, dynamic>? ?? {},
      timeSpent: json['time_spent'] as int?,
      attemptNumber: json['attempt_number'] as int? ?? 1,
      completedAt: DateTime.parse(json['completed_at'] as String),
    );
  }

  factory BookQuizResultModel.fromEntity(BookQuizResult entity) {
    return BookQuizResultModel(
      id: entity.id,
      userId: entity.userId,
      quizId: entity.quizId,
      bookId: entity.bookId,
      score: entity.score,
      maxScore: entity.maxScore,
      percentage: entity.percentage,
      isPassing: entity.isPassing,
      answers: entity.answers,
      timeSpent: entity.timeSpent,
      attemptNumber: entity.attemptNumber,
      completedAt: entity.completedAt,
    );
  }

  final String id;
  final String userId;
  final String quizId;
  final String bookId;
  final double score;
  final double maxScore;
  final double percentage;
  final bool isPassing;
  final Map<String, dynamic> answers;
  final int? timeSpent;
  final int attemptNumber;
  final DateTime completedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'quiz_id': quizId,
      'book_id': bookId,
      'score': score,
      'max_score': maxScore,
      'percentage': percentage,
      'is_passing': isPassing,
      'answers': answers,
      'time_spent': timeSpent,
      'attempt_number': attemptNumber,
      'completed_at': completedAt.toUtc().toIso8601String(),
    };
  }

  /// For inserting (no id, server generates it)
  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'quiz_id': quizId,
      'book_id': bookId,
      'score': score,
      'max_score': maxScore,
      'percentage': percentage,
      'is_passing': isPassing,
      'answers': answers,
      'time_spent': timeSpent,
      'completed_at': completedAt.toUtc().toIso8601String(),
    };
  }

  BookQuizResult toEntity() {
    return BookQuizResult(
      id: id,
      userId: userId,
      quizId: quizId,
      bookId: bookId,
      score: score,
      maxScore: maxScore,
      percentage: percentage,
      isPassing: isPassing,
      answers: answers,
      timeSpent: timeSpent,
      attemptNumber: attemptNumber,
      completedAt: completedAt,
    );
  }
}
