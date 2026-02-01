import 'package:equatable/equatable.dart';

/// Activity types for end-of-chapter quizzes (legacy)
enum ActivityType {
  multipleChoice,
  trueFalse,
  matching,
  ordering,
  fillBlank,
  shortAnswer,
}

/// Inline activity types for microlearning during reading
enum InlineActivityType {
  trueFalse,        // D/Y soruları
  wordTranslation,  // Kelime çevirisi seç
  findWords,        // Paragraftan kelime bul
}

// ============================================
// INLINE ACTIVITIES (Microlearning)
// ============================================

/// Base class for inline activity content
abstract class InlineActivityContent extends Equatable {
  const InlineActivityContent();
}

/// True/False activity content
class TrueFalseContent extends InlineActivityContent {

  const TrueFalseContent({
    required this.statement,
    required this.correctAnswer,
  });
  final String statement;
  final bool correctAnswer;

  @override
  List<Object?> get props => [statement, correctAnswer];
}

/// Word translation activity content
class WordTranslationContent extends InlineActivityContent {

  const WordTranslationContent({
    required this.word,
    required this.correctAnswer,
    required this.options,
  });
  final String word;
  final String correctAnswer;
  final List<String> options;

  @override
  List<Object?> get props => [word, correctAnswer, options];
}

/// Find words activity content (multi-select)
class FindWordsContent extends InlineActivityContent {

  const FindWordsContent({
    required this.instruction,
    required this.options,
    required this.correctAnswers,
  });
  final String instruction;
  final List<String> options;
  final List<String> correctAnswers;

  @override
  List<Object?> get props => [instruction, options, correctAnswers];
}

/// Inline activity that appears between paragraphs during reading
class InlineActivity extends Equatable {

  const InlineActivity({
    required this.id,
    required this.type,
    required this.afterParagraphIndex,
    required this.content,
    this.xpReward = 5,
    this.vocabularyWords = const [],
  });
  final String id;
  final InlineActivityType type;
  final int afterParagraphIndex;
  final InlineActivityContent content;
  final int xpReward;

  /// Words to add to vocabulary when this activity is completed
  /// (for word_translation and find_words types)
  final List<String> vocabularyWords;

  @override
  List<Object?> get props => [
    id,
    type,
    afterParagraphIndex,
    content,
    xpReward,
    vocabularyWords,
  ];
}

/// Result of an inline activity answer
class InlineActivityResult extends Equatable {

  const InlineActivityResult({
    required this.activityId,
    required this.isCorrect,
    required this.xpEarned,
    this.wordsLearned = const [],
    required this.answeredAt,
  });
  final String activityId;
  final bool isCorrect;
  final int xpEarned;
  final List<String> wordsLearned;
  final DateTime answeredAt;

  @override
  List<Object?> get props => [
    activityId,
    isCorrect,
    xpEarned,
    wordsLearned,
    answeredAt,
  ];
}

// ============================================
// LEGACY ACTIVITIES (End-of-chapter)
// ============================================

class Activity extends Equatable {

  const Activity({
    required this.id,
    required this.chapterId,
    required this.type,
    required this.orderIndex,
    this.title,
    this.instructions,
    this.questions = const [],
    this.settings = const {},
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String chapterId;
  final ActivityType type;
  final int orderIndex;
  final String? title;
  final String? instructions;
  final List<ActivityQuestion> questions;
  final Map<String, dynamic> settings;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get totalPoints => questions.fold(0, (sum, q) => sum + q.points);
  int get questionCount => questions.length;

  @override
  List<Object?> get props => [
        id,
        chapterId,
        type,
        orderIndex,
        title,
        instructions,
        questions,
        settings,
        createdAt,
        updatedAt,
      ];
}

class ActivityQuestion extends Equatable {

  const ActivityQuestion({
    required this.id,
    required this.question,
    this.options = const [],
    required this.correctAnswer,
    this.explanation,
    this.imageUrl,
    this.points = 1,
  });
  final String id;
  final String question;
  final List<String> options; // For multiple choice, matching
  final dynamic correctAnswer; // String, List<String>, Map, etc.
  final String? explanation;
  final String? imageUrl;
  final int points;

  bool checkAnswer(dynamic userAnswer) {
    if (correctAnswer is List && userAnswer is List) {
      if (correctAnswer.length != userAnswer.length) return false;
      for (var i = 0; i < correctAnswer.length; i++) {
        if (correctAnswer[i] != userAnswer[i]) return false;
      }
      return true;
    }
    return correctAnswer == userAnswer;
  }

  @override
  List<Object?> get props => [
        id,
        question,
        options,
        correctAnswer,
        explanation,
        imageUrl,
        points,
      ];
}

class ActivityResult extends Equatable {

  const ActivityResult({
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
  final String id;
  final String userId;
  final String activityId;
  final double score;
  final double maxScore;
  final Map<String, dynamic> answers;
  final int? timeSpent; // in seconds
  final int attemptNumber;
  final DateTime completedAt;

  double get percentage => maxScore > 0 ? (score / maxScore) * 100 : 0;
  bool get isPassing => percentage >= 60;
  bool get isExcellent => percentage >= 90;
  bool get isPerfect => score == maxScore;

  @override
  List<Object?> get props => [
        id,
        userId,
        activityId,
        score,
        maxScore,
        answers,
        timeSpent,
        attemptNumber,
        completedAt,
      ];
}
