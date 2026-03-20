import '../../domain/entities/vocabulary.dart';

/// User's response to a flashcard
enum SM2Response {
  dontKnow, // "I don't know!" - failed, reset
  gotIt, // "Got it!" - correct, normal progression
  veryEasy, // "Very EASY!" - correct, accelerated progression
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

  /// Convert SM2Response to quality score (0-5) for [SM2.calculateNextReview].
  int toQuality() {
    switch (this) {
      case SM2Response.dontKnow:
        return 1; // Failed
      case SM2Response.gotIt:
        return 4; // Correct with some difficulty
      case SM2Response.veryEasy:
        return 5; // Perfect recall
    }
  }
}

/// Single source of truth for SM-2 spaced repetition calculation.
///
/// Modified SM-2: Easy produces noticeably longer intervals from the
/// very first review (Anki-style), unlike standard SM-2 which gives
/// identical intervals for Good and Easy on the first two reviews.
///
///   Hard  (q<3): reset → 1 day
///   Good  (q=4): 1d → 6d → ease-based growth
///   Easy  (q=5): 4d → 10d → accelerated ease-based growth
class SM2 {
  const SM2._();

  /// Calculate next review for a word given the current progress and quality.
  ///
  /// [progress] is the current SM-2 state of the word.
  /// [quality] is the response quality (0-5). Use SM2Response.toQuality().
  ///
  /// Returns a new [VocabularyProgress] with updated SM-2 values.
  static VocabularyProgress calculateNextReview(
    VocabularyProgress progress,
    int quality,
  ) {
    // Ease factor recalculation (standard SM-2 formula)
    var newEaseFactor = progress.easeFactor +
        (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    if (newEaseFactor < 1.3) newEaseFactor = 1.3;

    int newInterval;
    int newRepetitions;
    VocabularyStatus newStatus;

    final isEasy = quality == 5;

    if (quality < 3) {
      // Failed - reset
      newRepetitions = 0;
      newInterval = 1;
      newStatus = VocabularyStatus.learning;
    } else {
      newRepetitions = progress.repetitions + 1;
      if (newRepetitions == 1) {
        newInterval = isEasy ? 4 : 1;
        newStatus =
            isEasy ? VocabularyStatus.reviewing : VocabularyStatus.learning;
      } else if (newRepetitions == 2) {
        newInterval = isEasy ? 10 : 6;
        newStatus = VocabularyStatus.reviewing;
      } else {
        newInterval = (progress.intervalDays * newEaseFactor).round();
        newStatus = newInterval > 21
            ? VocabularyStatus.mastered
            : VocabularyStatus.reviewing;
      }
    }

    // Cap interval at 365 days
    if (newInterval > 365) newInterval = 365;

    return VocabularyProgress(
      id: progress.id,
      userId: progress.userId,
      wordId: progress.wordId,
      status: newStatus,
      easeFactor: newEaseFactor,
      intervalDays: newInterval,
      repetitions: newRepetitions,
      nextReviewAt: DateTime.now().add(Duration(days: newInterval)),
      lastReviewedAt: DateTime.now(),
      createdAt: progress.createdAt,
    );
  }
}
