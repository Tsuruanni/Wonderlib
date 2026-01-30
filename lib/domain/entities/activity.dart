import 'package:equatable/equatable.dart';

enum ActivityType {
  multipleChoice,
  trueFalse,
  matching,
  ordering,
  fillBlank,
  shortAnswer,
}

class Activity extends Equatable {
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
  final String id;
  final String question;
  final List<String> options; // For multiple choice, matching
  final dynamic correctAnswer; // String, List<String>, Map, etc.
  final String? explanation;
  final String? imageUrl;
  final int points;

  const ActivityQuestion({
    required this.id,
    required this.question,
    this.options = const [],
    required this.correctAnswer,
    this.explanation,
    this.imageUrl,
    this.points = 1,
  });

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
  final String id;
  final String userId;
  final String activityId;
  final double score;
  final double maxScore;
  final Map<String, dynamic> answers;
  final int? timeSpent; // in seconds
  final int attemptNumber;
  final DateTime completedAt;

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
