import '../../../domain/entities/book_quiz.dart';

/// Model for StudentQuizProgress - teacher reporting RPC results
class StudentQuizProgressModel {
  const StudentQuizProgressModel({
    required this.bookId,
    required this.bookTitle,
    required this.quizTitle,
    required this.bestScore,
    required this.maxScore,
    required this.bestPercentage,
    required this.isPassing,
    required this.totalAttempts,
    this.firstAttemptAt,
    this.bestAttemptAt,
  });

  factory StudentQuizProgressModel.fromJson(Map<String, dynamic> json) {
    return StudentQuizProgressModel(
      bookId: json['book_id'] as String,
      bookTitle: json['book_title'] as String? ?? '',
      quizTitle: json['quiz_title'] as String? ?? '',
      bestScore: (json['best_score'] as num?)?.toDouble() ?? 0.0,
      maxScore: (json['max_score'] as num?)?.toDouble() ?? 0.0,
      bestPercentage: (json['best_percentage'] as num?)?.toDouble() ?? 0.0,
      isPassing: json['is_passing'] as bool? ?? false,
      totalAttempts: (json['total_attempts'] as num?)?.toInt() ?? 0,
      firstAttemptAt: json['first_attempt_at'] != null
          ? DateTime.parse(json['first_attempt_at'] as String)
          : null,
      bestAttemptAt: json['best_attempt_at'] != null
          ? DateTime.parse(json['best_attempt_at'] as String)
          : null,
    );
  }

  final String bookId;
  final String bookTitle;
  final String quizTitle;
  final double bestScore;
  final double maxScore;
  final double bestPercentage;
  final bool isPassing;
  final int totalAttempts;
  final DateTime? firstAttemptAt;
  final DateTime? bestAttemptAt;

  StudentQuizProgress toEntity() {
    return StudentQuizProgress(
      bookId: bookId,
      bookTitle: bookTitle,
      quizTitle: quizTitle,
      bestScore: bestScore,
      maxScore: maxScore,
      bestPercentage: bestPercentage,
      isPassing: isPassing,
      totalAttempts: totalAttempts,
      firstAttemptAt: firstAttemptAt,
      bestAttemptAt: bestAttemptAt,
    );
  }
}
