import 'package:equatable/equatable.dart';

class VocabularyWord extends Equatable {

  const VocabularyWord({
    required this.id,
    required this.word,
    this.phonetic,
    this.partOfSpeech,
    required this.meaningTR,
    this.meaningEN,
    this.exampleSentences = const [],
    this.audioUrl,
    this.audioStartMs,
    this.audioEndMs,
    this.imageUrl,
    this.level,
    this.categories = const [],
    this.synonyms = const [],
    this.antonyms = const [],
    required this.createdAt,
    this.sourceBookId,
    this.sourceBookTitle,
  });
  final String id;
  final String word;
  final String? phonetic;
  final String? partOfSpeech; // noun, verb, adjective, adverb, etc.
  final String meaningTR;
  final String? meaningEN;
  final List<String> exampleSentences; // Up to 2 example sentences
  final String? audioUrl;
  final int? audioStartMs;
  final int? audioEndMs;
  final String? imageUrl;
  final String? level;
  final List<String> categories;
  final List<String> synonyms;
  final List<String> antonyms;
  final DateTime createdAt;
  final String? sourceBookId; // Book from which this meaning was extracted
  final String? sourceBookTitle; // Joined from books table

  bool get hasAudio => audioUrl != null && audioUrl!.isNotEmpty;
  bool get hasAudioSegment => hasAudio && audioStartMs != null && audioEndMs != null;
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasExamples => exampleSentences.isNotEmpty;
  bool get hasSynonyms => synonyms.isNotEmpty;
  bool get hasAntonyms => antonyms.isNotEmpty;

  /// Get the first example sentence (for backward compatibility)
  String? get exampleSentence => exampleSentences.isNotEmpty ? exampleSentences.first : null;

  @override
  List<Object?> get props => [
        id,
        word,
        phonetic,
        partOfSpeech,
        meaningTR,
        meaningEN,
        exampleSentences,
        audioUrl,
        audioStartMs,
        audioEndMs,
        imageUrl,
        level,
        categories,
        synonyms,
        antonyms,
        createdAt,
        sourceBookId,
        sourceBookTitle,
      ];
}

enum VocabularyStatus { newWord, learning, reviewing, mastered }

class VocabularyProgress extends Equatable {

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

  bool get isDueForReview {
    if (nextReviewAt == null) return true;
    return DateTime.now().isAfter(nextReviewAt!);
  }

  bool get isMastered => status == VocabularyStatus.mastered;
  bool get isNew => status == VocabularyStatus.newWord;

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

/// Tracks completion of a special path node (flipbook, daily_review, game, treasure)
class NodeCompletion extends Equatable {
  const NodeCompletion({
    required this.unitId,
    required this.nodeType,
    required this.completedAt,
  });

  final String unitId;
  final String nodeType; // 'flipbook', 'daily_review', 'game', 'treasure'
  final DateTime completedAt;

  @override
  List<Object?> get props => [unitId, nodeType, completedAt];
}
