import '../../entities/book_quiz.dart';

class GradeBookQuizParams {
  const GradeBookQuizParams({
    required this.quiz,
    required this.answers,
  });
  final BookQuiz quiz;
  final Map<String, dynamic> answers;
}

class GradeQuizResult {
  const GradeQuizResult({
    required this.totalScore,
    required this.maxScore,
    required this.percentage,
    required this.isPassing,
    required this.answersJson,
  });
  final double totalScore;
  final double maxScore;
  final double percentage;
  final bool isPassing;
  final Map<String, dynamic> answersJson;
}

class GradeBookQuizUseCase {
  GradeQuizResult call(GradeBookQuizParams params) {
    final quiz = params.quiz;
    final answers = params.answers;
    double totalScore = 0;
    double maxScore = 0;
    final answersJson = <String, dynamic>{};

    for (final question in quiz.questions) {
      final answer = answers[question.id];
      maxScore += question.points;

      final isCorrect = _gradeQuestion(question, answer);
      if (isCorrect) {
        totalScore += question.points;
      }

      answersJson[question.id] = {
        'answer': _serializeAnswer(answer),
        'correct': isCorrect,
      };
    }

    final percentage = maxScore > 0 ? (totalScore / maxScore) * 100 : 0.0;

    return GradeQuizResult(
      totalScore: totalScore,
      maxScore: maxScore,
      percentage: percentage,
      isPassing: percentage >= quiz.passingScore,
      answersJson: answersJson,
    );
  }

  bool _gradeQuestion(BookQuizQuestion question, dynamic answer) {
    if (answer == null) return false;

    switch (question.type) {
      case BookQuizQuestionType.multipleChoice:
        final content = question.content as MultipleChoiceContent;
        return answer == content.correctAnswer;

      case BookQuizQuestionType.fillBlank:
        final content = question.content as FillBlankContent;
        return content.checkAnswer(answer as String);

      case BookQuizQuestionType.eventSequencing:
        final content = question.content as EventSequencingContent;
        return content.checkAnswer(answer as List<int>);

      case BookQuizQuestionType.matching:
        final content = question.content as QuizMatchingContent;
        final pairs = answer as Map<int, int>;
        if (pairs.length != content.correctPairs.length) return false;
        return content.correctPairs.entries
            .every((e) => pairs[e.key] == e.value);

      case BookQuizQuestionType.whoSaysWhat:
        final content = question.content as WhoSaysWhatContent;
        final pairs = answer as Map<int, int>;
        if (pairs.length != content.correctPairs.length) return false;
        return content.correctPairs.entries
            .every((e) => pairs[e.key] == e.value);
    }
  }

  dynamic _serializeAnswer(dynamic answer) {
    if (answer is Map<int, int>) {
      return answer.map((k, v) => MapEntry(k.toString(), v));
    }
    if (answer is List<int>) {
      return answer;
    }
    return answer;
  }
}
