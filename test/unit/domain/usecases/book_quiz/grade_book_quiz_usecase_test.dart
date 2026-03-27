import 'package:flutter_test/flutter_test.dart';
import 'package:owlio/domain/entities/book_quiz.dart';
import 'package:owlio/domain/usecases/book_quiz/grade_book_quiz_usecase.dart';
import 'package:owlio_shared/owlio_shared.dart';

void main() {
  late GradeBookQuizUseCase useCase;

  setUp(() {
    useCase = GradeBookQuizUseCase();
  });

  BookQuiz _buildQuiz({
    List<BookQuizQuestion>? questions,
    double passingScore = 70.0,
  }) {
    return BookQuiz(
      id: 'quiz-1',
      bookId: 'book-1',
      title: 'Test Quiz',
      passingScore: passingScore,
      totalPoints: questions?.fold<int>(0, (sum, q) => sum + q.points) ?? 0,
      questions: questions ?? [],
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  BookQuizQuestion _mcQuestion({
    String id = 'q1',
    int points = 1,
    String correctAnswer = 'A',
    List<String> options = const ['A', 'B', 'C', 'D'],
  }) {
    return BookQuizQuestion(
      id: id,
      quizId: 'quiz-1',
      type: BookQuizQuestionType.multipleChoice,
      orderIndex: 0,
      question: 'Test question?',
      content: MultipleChoiceContent(
        options: options,
        correctAnswer: correctAnswer,
      ),
      points: points,
    );
  }

  BookQuizQuestion _fillBlankQuestion({
    String id = 'q2',
    int points = 1,
    String correctAnswer = 'answer',
    List<String> alternatives = const [],
  }) {
    return BookQuizQuestion(
      id: id,
      quizId: 'quiz-1',
      type: BookQuizQuestionType.fillBlank,
      orderIndex: 1,
      question: 'Fill in the ___.',
      content: FillBlankContent(
        sentence: 'Fill in the ___.',
        correctAnswer: correctAnswer,
        acceptAlternatives: alternatives,
      ),
      points: points,
    );
  }

  BookQuizQuestion _eventSequencingQuestion({
    String id = 'q3',
    int points = 1,
  }) {
    return BookQuizQuestion(
      id: id,
      quizId: 'quiz-1',
      type: BookQuizQuestionType.eventSequencing,
      orderIndex: 2,
      question: 'Order these events.',
      content: const EventSequencingContent(
        events: ['First', 'Second', 'Third'],
        correctOrder: [0, 1, 2],
      ),
      points: points,
    );
  }

  group('GradeBookQuizUseCase', () {
    test('all correct answers returns 100% and isPassing true', () {
      final quiz = _buildQuiz(
        questions: [
          _mcQuestion(id: 'q1', correctAnswer: 'B'),
          _fillBlankQuestion(id: 'q2', correctAnswer: 'hello'),
          _eventSequencingQuestion(id: 'q3'),
        ],
      );

      final result = useCase(GradeBookQuizParams(
        quiz: quiz,
        answers: {
          'q1': 'B',
          'q2': 'hello',
          'q3': [0, 1, 2],
        },
      ));

      expect(result.totalScore, 3.0);
      expect(result.maxScore, 3.0);
      expect(result.percentage, 100.0);
      expect(result.isPassing, true);
      expect(result.answersJson['q1']['correct'], true);
      expect(result.answersJson['q2']['correct'], true);
      expect(result.answersJson['q3']['correct'], true);
    });

    test('no answers returns 0% and isPassing false', () {
      final quiz = _buildQuiz(
        questions: [
          _mcQuestion(id: 'q1'),
          _fillBlankQuestion(id: 'q2'),
        ],
      );

      final result = useCase(GradeBookQuizParams(
        quiz: quiz,
        answers: {},
      ));

      expect(result.totalScore, 0.0);
      expect(result.maxScore, 2.0);
      expect(result.percentage, 0.0);
      expect(result.isPassing, false);
      expect(result.answersJson['q1']['correct'], false);
      expect(result.answersJson['q2']['correct'], false);
    });

    test('below passing score (50%) returns isPassing false', () {
      final quiz = _buildQuiz(
        passingScore: 50.0,
        questions: [
          _mcQuestion(id: 'q1', correctAnswer: 'A', points: 1),
          _mcQuestion(id: 'q2', correctAnswer: 'B', points: 1),
          _mcQuestion(id: 'q3', correctAnswer: 'C', points: 1),
          _mcQuestion(id: 'q4', correctAnswer: 'D', points: 1),
        ],
      );

      // Only 1 out of 4 correct = 25%
      final result = useCase(GradeBookQuizParams(
        quiz: quiz,
        answers: {
          'q1': 'A', // correct
          'q2': 'A', // wrong
          'q3': 'A', // wrong
          'q4': 'A', // wrong
        },
      ));

      expect(result.totalScore, 1.0);
      expect(result.maxScore, 4.0);
      expect(result.percentage, 25.0);
      expect(result.isPassing, false);
    });

    test('exactly at passing score returns isPassing true', () {
      final quiz = _buildQuiz(
        passingScore: 50.0,
        questions: [
          _mcQuestion(id: 'q1', correctAnswer: 'A', points: 1),
          _mcQuestion(id: 'q2', correctAnswer: 'B', points: 1),
        ],
      );

      // 1 out of 2 correct = 50%
      final result = useCase(GradeBookQuizParams(
        quiz: quiz,
        answers: {
          'q1': 'A', // correct
          'q2': 'A', // wrong
        },
      ));

      expect(result.percentage, 50.0);
      expect(result.isPassing, true);
    });

    test('fill blank accepts alternatives case-insensitively', () {
      final quiz = _buildQuiz(
        questions: [
          _fillBlankQuestion(
            id: 'q1',
            correctAnswer: 'colour',
            alternatives: ['color'],
          ),
        ],
      );

      final result = useCase(GradeBookQuizParams(
        quiz: quiz,
        answers: {'q1': 'Color'},
      ));

      expect(result.totalScore, 1.0);
      expect(result.answersJson['q1']['correct'], true);
    });

    test('answersJson serializes Map<int,int> to string keys', () {
      final quiz = _buildQuiz(
        questions: [
          BookQuizQuestion(
            id: 'q1',
            quizId: 'quiz-1',
            type: BookQuizQuestionType.matching,
            orderIndex: 0,
            question: 'Match these items.',
            content: const QuizMatchingContent(
              leftItems: ['Cat', 'Dog'],
              rightItems: ['Meow', 'Bark'],
              correctPairs: {0: 0, 1: 1},
            ),
            points: 1,
          ),
        ],
      );

      final result = useCase(GradeBookQuizParams(
        quiz: quiz,
        answers: {
          'q1': {0: 0, 1: 1},
        },
      ));

      expect(result.totalScore, 1.0);
      expect(result.answersJson['q1']['correct'], true);
      // Verify serialization: Map<int,int> -> Map<String,int>
      final serialized = result.answersJson['q1']['answer'] as Map;
      expect(serialized.keys.first, isA<String>());
    });

    test('event sequencing wrong order returns incorrect', () {
      final quiz = _buildQuiz(
        questions: [_eventSequencingQuestion(id: 'q1')],
      );

      final result = useCase(GradeBookQuizParams(
        quiz: quiz,
        answers: {
          'q1': [2, 1, 0], // reversed
        },
      ));

      expect(result.totalScore, 0.0);
      expect(result.answersJson['q1']['correct'], false);
    });

    test('empty quiz returns 0% with isPassing false', () {
      final quiz = _buildQuiz(questions: []);

      final result = useCase(GradeBookQuizParams(
        quiz: quiz,
        answers: {},
      ));

      expect(result.totalScore, 0.0);
      expect(result.maxScore, 0.0);
      expect(result.percentage, 0.0);
      expect(result.isPassing, false);
    });
  });
}
