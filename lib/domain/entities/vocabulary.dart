import 'package:equatable/equatable.dart';

class VocabularyWord extends Equatable {
  final String id;
  final String word;
  final String? phonetic;
  final String meaningTR;
  final String? meaningEN;
  final String? exampleSentence;
  final String? audioUrl;
  final String? imageUrl;
  final String? level;
  final List<String> categories;
  final DateTime createdAt;

  const VocabularyWord({
    required this.id,
    required this.word,
    this.phonetic,
    required this.meaningTR,
    this.meaningEN,
    this.exampleSentence,
    this.audioUrl,
    this.imageUrl,
    this.level,
    this.categories = const [],
    required this.createdAt,
  });

  bool get hasAudio => audioUrl != null && audioUrl!.isNotEmpty;
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  @override
  List<Object?> get props => [
        id,
        word,
        phonetic,
        meaningTR,
        meaningEN,
        exampleSentence,
        audioUrl,
        imageUrl,
        level,
        categories,
        createdAt,
      ];
}

enum VocabularyStatus { newWord, learning, reviewing, mastered }

class VocabularyProgress extends Equatable {
  final String id;
  final String userId;
  final String wordId;
  final VocabularyStatus status;
  final double easeFactor; // SM-2 algorithm ease factor
  final int intervalDays;
  final int repetitions;
  final DateTime? nextReviewAt;
  final DateTime? lastReviewedAt;
  final DateTime createdAt;

  const VocabularyProgress({
    required this.id,
    required this.userId,
    required this.wordId,
    this.status = VocabularyStatus.newWord,
    this.easeFactor = 2.5,
    this.intervalDays = 0,
    this.repetitions = 0,
    this.nextReviewAt,
    this.lastReviewedAt,
    required this.createdAt,
  });

  bool get isDueForReview {
    if (nextReviewAt == null) return true;
    return DateTime.now().isAfter(nextReviewAt!);
  }

  bool get isMastered => status == VocabularyStatus.mastered;
  bool get isNew => status == VocabularyStatus.newWord;

  /// Calculate next review using SM-2 algorithm
  VocabularyProgress calculateNextReview(int quality) {
    // quality: 0-5 (0 = complete failure, 5 = perfect)
    var newEaseFactor = easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    if (newEaseFactor < 1.3) newEaseFactor = 1.3;

    int newInterval;
    int newRepetitions;
    VocabularyStatus newStatus;

    if (quality < 3) {
      // Failed - reset
      newRepetitions = 0;
      newInterval = 1;
      newStatus = VocabularyStatus.learning;
    } else {
      newRepetitions = repetitions + 1;
      if (newRepetitions == 1) {
        newInterval = 1;
        newStatus = VocabularyStatus.learning;
      } else if (newRepetitions == 2) {
        newInterval = 6;
        newStatus = VocabularyStatus.reviewing;
      } else {
        newInterval = (intervalDays * newEaseFactor).round();
        newStatus = newInterval > 21
            ? VocabularyStatus.mastered
            : VocabularyStatus.reviewing;
      }
    }

    // Cap interval at 365 days
    if (newInterval > 365) newInterval = 365;

    return VocabularyProgress(
      id: id,
      userId: userId,
      wordId: wordId,
      status: newStatus,
      easeFactor: newEaseFactor,
      intervalDays: newInterval,
      repetitions: newRepetitions,
      nextReviewAt: DateTime.now().add(Duration(days: newInterval)),
      lastReviewedAt: DateTime.now(),
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        wordId,
        status,
        easeFactor,
        intervalDays,
        repetitions,
        nextReviewAt,
        lastReviewedAt,
        createdAt,
      ];
}
