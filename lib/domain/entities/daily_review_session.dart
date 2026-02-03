import 'package:equatable/equatable.dart';

/// Represents a completed daily vocabulary review session
class DailyReviewSession extends Equatable {
  const DailyReviewSession({
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

  final String id;
  final String userId;
  final DateTime sessionDate;
  final int wordsReviewed;
  final int correctCount;
  final int incorrectCount;
  final int xpEarned;
  final bool isPerfect;
  final DateTime completedAt;

  /// Calculate accuracy as a percentage (0.0 - 1.0)
  double get accuracy =>
      wordsReviewed > 0 ? correctCount / wordsReviewed : 0.0;

  /// Accuracy as a whole number percentage
  int get accuracyPercent => (accuracy * 100).round();

  @override
  List<Object?> get props => [
        id,
        userId,
        sessionDate,
        wordsReviewed,
        correctCount,
        incorrectCount,
        xpEarned,
        isPerfect,
        completedAt,
      ];
}

/// Result returned when completing a daily review session
class DailyReviewResult extends Equatable {
  const DailyReviewResult({
    required this.sessionId,
    required this.xpEarned,
    required this.isNewSession,
    required this.isPerfect,
  });

  final String sessionId;
  final int xpEarned;
  final bool isNewSession;
  final bool isPerfect;

  @override
  List<Object?> get props => [sessionId, xpEarned, isNewSession, isPerfect];
}
