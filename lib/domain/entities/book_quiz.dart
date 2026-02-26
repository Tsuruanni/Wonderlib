import 'package:equatable/equatable.dart';
import 'package:owlio_shared/owlio_shared.dart';

export 'package:owlio_shared/src/enums/book_quiz_question_type.dart';

// ============================================
// POLYMORPHIC QUESTION CONTENT
// ============================================

/// Base class for quiz question content
abstract class BookQuizQuestionContent extends Equatable {
  const BookQuizQuestionContent();
}

/// Multiple choice: 4 options, 1 correct
class MultipleChoiceContent extends BookQuizQuestionContent {
  const MultipleChoiceContent({
    required this.options,
    required this.correctAnswer,
  });

  final List<String> options;
  final String correctAnswer;

  @override
  List<Object?> get props => [options, correctAnswer];
}

/// Fill in the blank: sentence with ___ placeholder, typed answer
class FillBlankContent extends BookQuizQuestionContent {
  const FillBlankContent({
    required this.sentence,
    required this.correctAnswer,
    this.acceptAlternatives = const [],
  });

  final String sentence;
  final String correctAnswer;
  final List<String> acceptAlternatives;

  bool checkAnswer(String userAnswer) {
    final normalized = userAnswer.trim().toLowerCase();
    if (normalized == correctAnswer.toLowerCase()) return true;
    return acceptAlternatives.any((alt) => alt.toLowerCase() == normalized);
  }

  @override
  List<Object?> get props => [sentence, correctAnswer, acceptAlternatives];
}

/// Event sequencing: order events chronologically
class EventSequencingContent extends BookQuizQuestionContent {
  const EventSequencingContent({
    required this.events,
    required this.correctOrder,
  });

  final List<String> events;
  final List<int> correctOrder;

  bool checkAnswer(List<int> userOrder) {
    if (userOrder.length != correctOrder.length) return false;
    for (var i = 0; i < correctOrder.length; i++) {
      if (correctOrder[i] != userOrder[i]) return false;
    }
    return true;
  }

  @override
  List<Object?> get props => [events, correctOrder];
}

/// Matching: match items from two columns
class QuizMatchingContent extends BookQuizQuestionContent {
  const QuizMatchingContent({
    required this.leftItems,
    required this.rightItems,
    required this.correctPairs,
  });

  final List<String> leftItems;
  final List<String> rightItems;
  final Map<int, int> correctPairs;

  @override
  List<Object?> get props => [leftItems, rightItems, correctPairs];
}

/// Who says what: match character to their quote
class WhoSaysWhatContent extends BookQuizQuestionContent {
  const WhoSaysWhatContent({
    required this.characters,
    required this.quotes,
    required this.correctPairs,
  });

  final List<String> characters;
  final List<String> quotes;
  final Map<int, int> correctPairs;

  @override
  List<Object?> get props => [characters, quotes, correctPairs];
}

// ============================================
// BOOK QUIZ QUESTION
// ============================================

class BookQuizQuestion extends Equatable {
  const BookQuizQuestion({
    required this.id,
    required this.quizId,
    required this.type,
    required this.orderIndex,
    required this.question,
    required this.content,
    this.explanation,
    this.points = 1,
  });

  final String id;
  final String quizId;
  final BookQuizQuestionType type;
  final int orderIndex;
  final String question;
  final BookQuizQuestionContent content;
  final String? explanation;
  final int points;

  @override
  List<Object?> get props => [
        id,
        quizId,
        type,
        orderIndex,
        question,
        content,
        explanation,
        points,
      ];
}

// ============================================
// BOOK QUIZ
// ============================================

class BookQuiz extends Equatable {
  const BookQuiz({
    required this.id,
    required this.bookId,
    required this.title,
    this.instructions,
    this.passingScore = 70.0,
    required this.totalPoints,
    this.isPublished = false,
    required this.questions,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String bookId;
  final String title;
  final String? instructions;
  final double passingScore;
  final int totalPoints;
  final bool isPublished;
  final List<BookQuizQuestion> questions;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get questionCount => questions.length;

  @override
  List<Object?> get props => [
        id,
        bookId,
        title,
        instructions,
        passingScore,
        totalPoints,
        isPublished,
        questions,
        createdAt,
        updatedAt,
      ];
}

// ============================================
// BOOK QUIZ RESULT
// ============================================

class BookQuizResult extends Equatable {
  const BookQuizResult({
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

  @override
  List<Object?> get props => [
        id,
        userId,
        quizId,
        bookId,
        score,
        maxScore,
        percentage,
        isPassing,
        answers,
        timeSpent,
        attemptNumber,
        completedAt,
      ];
}

// ============================================
// STUDENT QUIZ PROGRESS (for teacher reporting)
// ============================================

class StudentQuizProgress extends Equatable {
  const StudentQuizProgress({
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

  @override
  List<Object?> get props => [
        bookId,
        bookTitle,
        quizTitle,
        bestScore,
        maxScore,
        bestPercentage,
        isPassing,
        totalAttempts,
        firstAttemptAt,
        bestAttemptAt,
      ];
}
