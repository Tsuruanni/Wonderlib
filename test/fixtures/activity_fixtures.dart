import 'package:readeng/domain/entities/activity.dart';

/// Test fixtures for Activity-related tests
class ActivityFixtures {
  ActivityFixtures._();

  // ============================================
  // Question JSON Fixtures
  // ============================================

  static Map<String, dynamic> validQuestionJson() => {
        'id': 'q-1',
        'question': 'What is the capital of France?',
        'options': ['London', 'Paris', 'Berlin', 'Madrid'],
        'correct_answer': 'Paris',
        'explanation': 'Paris is the capital city of France.',
        'image_url': 'https://example.com/paris.jpg',
        'points': 10,
      };

  static Map<String, dynamic> minimalQuestionJson() => {
        'id': 'q-min',
        'question': 'Is the sky blue?',
        'correct_answer': true,
      };

  static List<Map<String, dynamic>> questionListJson() => [
        validQuestionJson(),
        {
          'id': 'q-2',
          'question': 'What is 2 + 2?',
          'options': ['3', '4', '5', '6'],
          'correct_answer': '4',
          'points': 5,
        },
      ];

  // ============================================
  // Activity JSON Fixtures
  // ============================================

  static Map<String, dynamic> validActivityJson() => {
        'id': 'activity-123',
        'chapter_id': 'chapter-1',
        'type': 'multiple_choice',
        'order_index': 1,
        'title': 'Chapter 1 Quiz',
        'instructions': 'Answer all questions to the best of your ability.',
        'questions': questionListJson(),
        'settings': <String, dynamic>{'time_limit': 300, 'shuffle_questions': true},
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-15T10:30:00Z',
      };

  static Map<String, dynamic> minimalActivityJson() => {
        'id': 'activity-min',
        'chapter_id': 'chapter-1',
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      };

  static Map<String, dynamic> trueFalseActivityJson() => {
        'id': 'activity-tf',
        'chapter_id': 'chapter-1',
        'type': 'true_false',
        'order_index': 2,
        'title': 'True or False',
        'questions': [minimalQuestionJson()],
        'settings': <String, dynamic>{},
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      };

  static Map<String, dynamic> activityJsonWithNulls() => {
        'id': 'activity-nulls',
        'chapter_id': 'chapter-1',
        'type': null,
        'order_index': null,
        'title': null,
        'instructions': null,
        'questions': null,
        'settings': null,
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      };

  static Map<String, dynamic> invalidActivityJsonMissingId() => {
        'chapter_id': 'chapter-1',
        'type': 'multiple_choice',
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      };

  // ============================================
  // Entity Fixtures
  // ============================================

  static ActivityQuestion validQuestion() => ActivityQuestion(
        id: 'q-1',
        question: 'What is the capital of France?',
        options: const ['London', 'Paris', 'Berlin', 'Madrid'],
        correctAnswer: 'Paris',
        explanation: 'Paris is the capital city of France.',
        imageUrl: 'https://example.com/paris.jpg',
        points: 10,
      );

  static Activity validActivity() => Activity(
        id: 'activity-123',
        chapterId: 'chapter-1',
        type: ActivityType.multipleChoice,
        orderIndex: 1,
        title: 'Chapter 1 Quiz',
        instructions: 'Answer all questions to the best of your ability.',
        questions: [validQuestion()],
        settings: const {'time_limit': 300, 'shuffle_questions': true},
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2024-01-15T10:30:00Z'),
      );
}

/// Test fixtures for ActivityResult
class ActivityResultFixtures {
  ActivityResultFixtures._();

  // ============================================
  // JSON Fixtures
  // ============================================

  static Map<String, dynamic> validResultJson() => {
        'id': 'result-123',
        'user_id': 'user-456',
        'activity_id': 'activity-789',
        'score': 80.0,
        'max_score': 100.0,
        'answers': <String, dynamic>{
          'q-1': 'Paris',
          'q-2': '4',
        },
        'time_spent': 120,
        'attempt_number': 1,
        'completed_at': '2024-01-15T10:30:00Z',
      };

  static Map<String, dynamic> perfectScoreResultJson() => {
        'id': 'result-perfect',
        'user_id': 'user-456',
        'activity_id': 'activity-789',
        'score': 100.0,
        'max_score': 100.0,
        'answers': <String, dynamic>{
          'q-1': 'Paris',
          'q-2': '4',
        },
        'time_spent': 60,
        'attempt_number': 1,
        'completed_at': '2024-01-15T10:30:00Z',
      };

  static Map<String, dynamic> zeroScoreResultJson() => {
        'id': 'result-zero',
        'user_id': 'user-456',
        'activity_id': 'activity-789',
        'score': 0.0,
        'max_score': 100.0,
        'answers': <String, dynamic>{},
        'time_spent': 300,
        'attempt_number': 3,
        'completed_at': '2024-01-15T10:30:00Z',
      };

  static Map<String, dynamic> resultJsonWithNulls() => {
        'id': 'result-nulls',
        'user_id': 'user-456',
        'activity_id': 'activity-789',
        'score': 50,
        'max_score': 100,
        'answers': null,
        'time_spent': null,
        'attempt_number': null,
        'completed_at': '2024-01-15T10:30:00Z',
      };

  static Map<String, dynamic> invalidResultJsonMissingId() => {
        'user_id': 'user-456',
        'activity_id': 'activity-789',
        'score': 80.0,
        'max_score': 100.0,
        'answers': <String, dynamic>{},
        'completed_at': '2024-01-15T10:30:00Z',
      };

  // ============================================
  // Entity Fixtures
  // ============================================

  static ActivityResult validResult() => ActivityResult(
        id: 'result-123',
        userId: 'user-456',
        activityId: 'activity-789',
        score: 80.0,
        maxScore: 100.0,
        answers: const {
          'q-1': 'Paris',
          'q-2': '4',
        },
        timeSpent: 120,
        attemptNumber: 1,
        completedAt: DateTime.parse('2024-01-15T10:30:00Z'),
      );
}
