import '../../domain/entities/vocabulary.dart';

/// SM-2 Spaced Repetition Algorithm
///
/// Simplified to 3 responses for better UX:
/// - "I don't know!" → Reset, review soon
/// - "Got it!" → Normal progression
/// - "Very EASY!" → Accelerated progression
class SM2Algorithm {
  /// Minimum ease factor (prevents intervals from getting too short)
  static const double minEaseFactor = 1.3;

  /// Maximum ease factor
  static const double maxEaseFactor = 3.0;

  /// Maximum interval in days
  static const int maxInterval = 365;

  /// Calculate the next review parameters based on response
  static SM2Result calculate({
    required double currentEaseFactor,
    required int currentInterval,
    required int currentRepetitions,
    required VocabularyStatus currentStatus,
    required SM2Response response,
  }) {
    double newEaseFactor = currentEaseFactor;
    int newInterval;
    int newRepetitions;
    VocabularyStatus newStatus;

    switch (response) {
      case SM2Response.dontKnow:
        // Reset - user didn't know the word
        newEaseFactor = (currentEaseFactor - 0.2).clamp(minEaseFactor, maxEaseFactor);
        newInterval = 1; // Review tomorrow
        newRepetitions = 0;
        newStatus = VocabularyStatus.learning;

      case SM2Response.gotIt:
        // Normal progression
        newRepetitions = currentRepetitions + 1;

        if (newRepetitions == 1) {
          newInterval = 1;
          newStatus = VocabularyStatus.learning;
        } else if (newRepetitions == 2) {
          newInterval = 3;
          newStatus = VocabularyStatus.reviewing;
        } else {
          newInterval = (currentInterval * currentEaseFactor).round();
          newStatus = newInterval > 21
              ? VocabularyStatus.mastered
              : VocabularyStatus.reviewing;
        }

      case SM2Response.veryEasy:
        // Accelerated progression
        newEaseFactor = (currentEaseFactor + 0.15).clamp(minEaseFactor, maxEaseFactor);
        newRepetitions = currentRepetitions + 1;

        if (newRepetitions == 1) {
          newInterval = 2;
          newStatus = VocabularyStatus.learning;
        } else if (newRepetitions == 2) {
          newInterval = 6;
          newStatus = VocabularyStatus.reviewing;
        } else {
          newInterval = (currentInterval * currentEaseFactor * 1.5).round();
          newStatus = newInterval > 21
              ? VocabularyStatus.mastered
              : VocabularyStatus.reviewing;
        }
    }

    // Cap interval at max
    if (newInterval > maxInterval) {
      newInterval = maxInterval;
    }

    return SM2Result(
      newEaseFactor: newEaseFactor,
      newInterval: newInterval,
      newRepetitions: newRepetitions,
      newStatus: newStatus,
      nextReviewAt: DateTime.now().add(Duration(days: newInterval)),
    );
  }

  /// Calculate XP reward based on response
  static int calculateXP(SM2Response response, VocabularyStatus resultStatus) {
    int baseXP = switch (response) {
      SM2Response.dontKnow => 1,  // Small consolation XP
      SM2Response.gotIt => 2,
      SM2Response.veryEasy => 3,
    };

    // Bonus for reaching mastered status
    if (resultStatus == VocabularyStatus.mastered) {
      baseXP += 4; // Word mastered bonus
    }

    return baseXP;
  }
}

/// User's response to a flashcard
enum SM2Response {
  dontKnow,  // "I don't know!" - failed, reset
  gotIt,     // "Got it!" - correct, normal progression
  veryEasy,  // "Very EASY!" - correct, accelerated progression
}

extension SM2ResponseExtension on SM2Response {
  String get displayText {
    switch (this) {
      case SM2Response.dontKnow:
        return "I don't know!";
      case SM2Response.gotIt:
        return 'Got it!';
      case SM2Response.veryEasy:
        return 'Very EASY!';
    }
  }

  String get emoji {
    switch (this) {
      case SM2Response.dontKnow:
        return '😕';
      case SM2Response.gotIt:
        return '😊';
      case SM2Response.veryEasy:
        return '🚀';
    }
  }
}

/// Result of SM-2 calculation
class SM2Result {

  const SM2Result({
    required this.newEaseFactor,
    required this.newInterval,
    required this.newRepetitions,
    required this.newStatus,
    required this.nextReviewAt,
  });
  final double newEaseFactor;
  final int newInterval;
  final int newRepetitions;
  final VocabularyStatus newStatus;
  final DateTime nextReviewAt;

  @override
  String toString() {
    return 'SM2Result(EF: $newEaseFactor, interval: $newInterval days, '
        'reps: $newRepetitions, status: $newStatus, next: $nextReviewAt)';
  }
}
