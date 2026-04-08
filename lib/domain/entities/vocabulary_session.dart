import 'package:equatable/equatable.dart';

// =============================================
// ENUMS
// =============================================

/// Types of questions in a vocabulary session
enum QuestionType {
  multipleChoice,        // EN word → pick TR meaning (4 options)
  reverseMultipleChoice, // TR meaning → pick EN word (4 options)
  listeningSelect,       // Audio plays → pick correct word (4 options)
  imageMatch,            // EN word shown → pick correct image (2 options)
  matching,              // Match 4 words ↔ 4 meanings
  scrambledLetters,      // Rearrange shuffled letter buttons
  wordWheel,             // Circular drag-to-connect letter wheel
  scrambledWords,        // Rearrange shuffled word tiles (for phrases)
  spelling,              // TR meaning given → type EN word
  listeningWrite,        // Audio plays → type the word
  sentenceGap,           // Fill the blank in a sentence
  pronunciation,          // Say the word — recall + speak into microphone (production)
}

/// Difficulty tiers for question types
extension QuestionTypeTier on QuestionType {
  /// Recognition (easy), Bridge (medium), Production (hard)
  QuestionTier get tier {
    switch (this) {
      case QuestionType.multipleChoice:
      case QuestionType.reverseMultipleChoice:
      case QuestionType.listeningSelect:
      case QuestionType.imageMatch:
        return QuestionTier.recognition;
      case QuestionType.matching:
      case QuestionType.scrambledLetters:
      case QuestionType.wordWheel:
      case QuestionType.scrambledWords:
        return QuestionTier.bridge;
      case QuestionType.spelling:
      case QuestionType.listeningWrite:
      case QuestionType.sentenceGap:
      case QuestionType.pronunciation:
        return QuestionTier.production;
    }
  }
}

enum QuestionTier { recognition, bridge, production }

/// Per-word mastery progression within a session
enum WordMasteryLevel {
  unseen,      // Not yet introduced
  introduced,  // Shown in Faz 1 (Explore)
  recognized,  // Passed a recognition question
  bridged,     // Passed a bridge question
  produced,    // Passed a production question
}

/// Session phase
enum SessionPhase {
  explore,    // Faz 1: Introduce words in pairs
  reinforce,  // Faz 2: Mixed question types
  finalPhase, // Faz 3: Hardest questions on weakest words
}

// =============================================
// SESSION STATE (in-memory, during session)
// =============================================

/// Tracks one word's state during a session
class WordSessionState extends Equatable {
  const WordSessionState({
    required this.wordId,
    required this.word,
    required this.meaningTR,
    this.meaningEN,
    this.imageUrl,
    this.audioUrl,
    this.audioStartMs,
    this.audioEndMs,
    this.exampleSentence,
    this.phonetic,
    this.masteryLevel = WordMasteryLevel.unseen,
    this.correctCount = 0,
    this.incorrectCount = 0,
    this.isFirstTryPerfect = true,
    this.needsRemediation = false,
  });

  final String wordId;
  final String word;
  final String meaningTR;
  final String? meaningEN;
  final String? imageUrl;
  final String? audioUrl;
  final int? audioStartMs;
  final int? audioEndMs;
  final String? exampleSentence;
  final String? phonetic;
  final WordMasteryLevel masteryLevel;
  final int correctCount;
  final int incorrectCount;
  final bool isFirstTryPerfect;
  final bool needsRemediation;

  bool get hasErrors => incorrectCount > 0;

  /// Word status for summary: strong (green), medium (yellow), weak (red)
  WordResultStatus get resultStatus {
    if (incorrectCount == 0) return WordResultStatus.strong;
    if (correctCount > incorrectCount) return WordResultStatus.medium;
    return WordResultStatus.weak;
  }

  WordSessionState copyWith({
    WordMasteryLevel? masteryLevel,
    int? correctCount,
    int? incorrectCount,
    bool? isFirstTryPerfect,
    bool? needsRemediation,
  }) {
    return WordSessionState(
      wordId: wordId,
      word: word,
      meaningTR: meaningTR,
      meaningEN: meaningEN,
      imageUrl: imageUrl,
      audioUrl: audioUrl,
      audioStartMs: audioStartMs,
      audioEndMs: audioEndMs,
      exampleSentence: exampleSentence,
      phonetic: phonetic,
      masteryLevel: masteryLevel ?? this.masteryLevel,
      correctCount: correctCount ?? this.correctCount,
      incorrectCount: incorrectCount ?? this.incorrectCount,
      isFirstTryPerfect: isFirstTryPerfect ?? this.isFirstTryPerfect,
      needsRemediation: needsRemediation ?? this.needsRemediation,
    );
  }

  @override
  List<Object?> get props => [
        wordId, word, meaningTR, meaningEN, imageUrl, audioUrl,
        audioStartMs, audioEndMs, exampleSentence, phonetic, masteryLevel, correctCount,
        incorrectCount, isFirstTryPerfect, needsRemediation,
      ];
}

enum WordResultStatus { strong, medium, weak }

/// A single question in the session
class SessionQuestion extends Equatable {
  const SessionQuestion({
    required this.type,
    required this.targetWordId,
    required this.targetWord,
    required this.targetMeaning,
    required this.correctAnswer,
    this.options,
    this.sentence,
    this.audioUrl,
    this.audioStartMs,
    this.audioEndMs,
    this.imageUrl,
    this.matchingPairs,
    this.scrambledLetters,
    this.scrambledWordTiles,
    this.isRemediation = false,
  });

  final QuestionType type;
  final String targetWordId;
  final String targetWord;
  final String targetMeaning;
  final String correctAnswer;
  final List<String>? options;         // For MC / listening select / image match (URLs)
  final String? sentence;              // For sentence gap
  final String? audioUrl;              // For listening questions
  final int? audioStartMs;             // Segment start in batch audio
  final int? audioEndMs;               // Segment end in batch audio
  final String? imageUrl;              // For visual support
  final List<SessionMatchingPair>? matchingPairs; // For matching questions
  final List<String>? scrambledLetters;    // For scrambled letters
  final List<String>? scrambledWordTiles;  // For scrambled words (phrases)

  final bool isRemediation; // Whether this is a remediation retry

  @override
  List<Object?> get props => [
        type, targetWordId, targetWord, targetMeaning, correctAnswer,
        options, sentence, audioUrl, audioStartMs, audioEndMs, imageUrl, matchingPairs,
        scrambledLetters, scrambledWordTiles, isRemediation,
      ];
}

/// A pair for matching questions
class SessionMatchingPair extends Equatable {
  const SessionMatchingPair({
    required this.word,
    required this.meaning,
    required this.wordId,
  });

  final String word;
  final String meaning;
  final String wordId;

  @override
  List<Object?> get props => [word, meaning, wordId];
}

// =============================================
// SESSION RESULT (persisted to DB)
// =============================================

/// Result of a completed vocabulary session
class VocabularySessionResult extends Equatable {
  const VocabularySessionResult({
    required this.id,
    required this.userId,
    required this.wordListId,
    required this.totalQuestions,
    required this.correctCount,
    required this.incorrectCount,
    required this.accuracy,
    required this.maxCombo,
    required this.xpEarned,
    required this.durationSeconds,
    required this.wordsStrong,
    required this.wordsWeak,
    required this.firstTryPerfectCount,
    required this.completedAt,
    this.wordResults = const [],
  });

  final String id;
  final String userId;
  final String wordListId;
  final int totalQuestions;
  final int correctCount;
  final int incorrectCount;
  final double accuracy;
  final int maxCombo;
  final int xpEarned;
  final int durationSeconds;
  final int wordsStrong;
  final int wordsWeak;
  final int firstTryPerfectCount;
  final DateTime completedAt;
  final List<SessionWordResult> wordResults;

  @override
  List<Object?> get props => [
        id, userId, wordListId, totalQuestions, correctCount, incorrectCount,
        accuracy, maxCombo, xpEarned, durationSeconds, wordsStrong, wordsWeak,
        firstTryPerfectCount, completedAt, wordResults,
      ];
}

/// Per-word result within a session
class SessionWordResult extends Equatable {
  const SessionWordResult({
    required this.wordId,
    required this.correctCount,
    required this.incorrectCount,
    required this.masteryLevel,
    required this.isFirstTryPerfect,
  });

  final String wordId;
  final int correctCount;
  final int incorrectCount;
  final WordMasteryLevel masteryLevel;
  final bool isFirstTryPerfect;

  @override
  List<Object?> get props => [
        wordId, correctCount, incorrectCount, masteryLevel, isFirstTryPerfect,
      ];
}
