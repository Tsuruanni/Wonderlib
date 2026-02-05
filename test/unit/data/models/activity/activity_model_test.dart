import 'package:flutter_test/flutter_test.dart';
import 'package:readeng/data/models/activity/activity_model.dart';
import 'package:readeng/domain/entities/activity.dart';

import '../../../../fixtures/activity_fixtures.dart';

void main() {
  group('ActivityModel', () {
    // ============================================
    // fromJson Tests
    // ============================================
    group('fromJson', () {
      test('withValidData_shouldCreateModel', () {
        // Arrange
        final json = ActivityFixtures.validActivityJson();

        // Act
        final model = ActivityModel.fromJson(json);

        // Assert
        expect(model.id, 'activity-123');
        expect(model.chapterId, 'chapter-1');
        expect(model.type, 'multiple_choice');
        expect(model.orderIndex, 1);
        expect(model.title, 'Chapter 1 Quiz');
        expect(model.instructions, isNotNull);
        expect(model.questions.length, 2);
        expect(model.settings['time_limit'], 300);
      });

      test('withMinimalData_shouldUseDefaults', () {
        // Arrange
        final json = ActivityFixtures.minimalActivityJson();

        // Act
        final model = ActivityModel.fromJson(json);

        // Assert
        expect(model.id, 'activity-min');
        expect(model.type, 'multiple_choice'); // default
        expect(model.orderIndex, 0); // default
        expect(model.title, isNull);
        expect(model.instructions, isNull);
        expect(model.questions, isEmpty);
        expect(model.settings, isEmpty);
      });

      test('withNullOptionalFields_shouldUseDefaults', () {
        // Arrange
        final json = ActivityFixtures.activityJsonWithNulls();

        // Act
        final model = ActivityModel.fromJson(json);

        // Assert
        expect(model.type, 'multiple_choice');
        expect(model.orderIndex, 0);
        expect(model.title, isNull);
        expect(model.instructions, isNull);
        expect(model.questions, isEmpty);
        expect(model.settings, isEmpty);
      });

      test('withTrueFalseType_shouldParseCorrectly', () {
        // Arrange
        final json = ActivityFixtures.trueFalseActivityJson();

        // Act
        final model = ActivityModel.fromJson(json);

        // Assert
        expect(model.type, 'true_false');
        expect(model.questions.length, 1);
      });

      test('withMissingId_shouldThrowTypeError', () {
        // Arrange
        final json = ActivityFixtures.invalidActivityJsonMissingId();

        // Act & Assert
        expect(
          () => ActivityModel.fromJson(json),
          throwsA(isA<TypeError>()),
        );
      });
    });

    // ============================================
    // toJson Tests
    // ============================================
    group('toJson', () {
      test('always_shouldIncludeAllFields', () {
        // Arrange
        final model = ActivityModel.fromJson(ActivityFixtures.validActivityJson());

        // Act
        final json = model.toJson();

        // Assert
        expect(json['id'], 'activity-123');
        expect(json['chapter_id'], 'chapter-1');
        expect(json['type'], 'multiple_choice');
        expect(json['order_index'], 1);
        expect(json['title'], 'Chapter 1 Quiz');
        expect(json['instructions'], isNotNull);
        expect(json['questions'], isA<List>());
        expect((json['questions'] as List).length, 2);
        expect(json['settings'], isA<Map>());
        expect(json['created_at'], isNotNull);
        expect(json['updated_at'], isNotNull);
      });
    });

    // ============================================
    // toEntity Tests
    // ============================================
    group('toEntity', () {
      test('always_shouldMapAllFieldsCorrectly', () {
        // Arrange
        final model = ActivityModel.fromJson(ActivityFixtures.validActivityJson());

        // Act
        final entity = model.toEntity();

        // Assert
        expect(entity, isA<Activity>());
        expect(entity.id, model.id);
        expect(entity.chapterId, model.chapterId);
        expect(entity.type, ActivityType.multipleChoice);
        expect(entity.orderIndex, model.orderIndex);
        expect(entity.title, model.title);
        expect(entity.instructions, model.instructions);
        expect(entity.questions.length, model.questions.length);
        expect(entity.settings, model.settings);
      });

      test('withDifferentTypes_shouldMapCorrectly', () {
        // Test all activity types
        final types = {
          'multiple_choice': ActivityType.multipleChoice,
          'true_false': ActivityType.trueFalse,
          'matching': ActivityType.matching,
          'ordering': ActivityType.ordering,
          'fill_blank': ActivityType.fillBlank,
          'short_answer': ActivityType.shortAnswer,
        };

        for (final entry in types.entries) {
          // Arrange
          final json = ActivityFixtures.minimalActivityJson();
          json['type'] = entry.key;

          // Act
          final entity = ActivityModel.fromJson(json).toEntity();

          // Assert
          expect(entity.type, entry.value, reason: 'Type ${entry.key} should map to ${entry.value}');
        }
      });

      test('withUnknownType_shouldDefaultToMultipleChoice', () {
        // Arrange
        final json = ActivityFixtures.minimalActivityJson();
        json['type'] = 'unknown_type';

        // Act
        final entity = ActivityModel.fromJson(json).toEntity();

        // Assert
        expect(entity.type, ActivityType.multipleChoice);
      });
    });

    // ============================================
    // fromEntity Tests
    // ============================================
    group('fromEntity', () {
      test('always_shouldMapAllFieldsCorrectly', () {
        // Arrange
        final entity = ActivityFixtures.validActivity();

        // Act
        final model = ActivityModel.fromEntity(entity);

        // Assert
        expect(model.id, entity.id);
        expect(model.chapterId, entity.chapterId);
        expect(model.type, 'multiple_choice');
        expect(model.orderIndex, entity.orderIndex);
        expect(model.title, entity.title);
        expect(model.instructions, entity.instructions);
        expect(model.questions.length, entity.questions.length);
      });

      test('roundTrip_shouldPreserveData', () {
        // Arrange
        final originalJson = ActivityFixtures.validActivityJson();

        // Act
        final model = ActivityModel.fromJson(originalJson);
        final entity = model.toEntity();
        final modelFromEntity = ActivityModel.fromEntity(entity);
        final resultJson = modelFromEntity.toJson();

        // Assert
        expect(resultJson['id'], originalJson['id']);
        expect(resultJson['chapter_id'], originalJson['chapter_id']);
        expect(resultJson['type'], originalJson['type']);
        expect(resultJson['order_index'], originalJson['order_index']);
      });
    });
  });

  // ============================================
  // ActivityQuestionModel Tests
  // ============================================
  group('ActivityQuestionModel', () {
    group('fromJson', () {
      test('withValidData_shouldCreateModel', () {
        // Arrange
        final json = ActivityFixtures.validQuestionJson();

        // Act
        final model = ActivityQuestionModel.fromJson(json);

        // Assert
        expect(model.id, 'q-1');
        expect(model.question, 'What is the capital of France?');
        expect(model.options.length, 4);
        expect(model.correctAnswer, 'Paris');
        expect(model.explanation, isNotNull);
        expect(model.imageUrl, isNotNull);
        expect(model.points, 10);
      });

      test('withMinimalData_shouldUseDefaults', () {
        // Arrange
        final json = ActivityFixtures.minimalQuestionJson();

        // Act
        final model = ActivityQuestionModel.fromJson(json);

        // Assert
        expect(model.id, 'q-min');
        expect(model.question, 'Is the sky blue?');
        expect(model.options, isEmpty);
        expect(model.correctAnswer, true);
        expect(model.explanation, isNull);
        expect(model.imageUrl, isNull);
        expect(model.points, 1); // default
      });

      test('withMissingId_shouldUseEmptyString', () {
        // Arrange
        final json = <String, dynamic>{
          'question': 'Test question?',
          'correct_answer': 'answer',
        };

        // Act
        final model = ActivityQuestionModel.fromJson(json);

        // Assert
        expect(model.id, '');
      });
    });

    group('toJson', () {
      test('always_shouldIncludeAllFields', () {
        // Arrange
        final model = ActivityQuestionModel.fromJson(ActivityFixtures.validQuestionJson());

        // Act
        final json = model.toJson();

        // Assert
        expect(json['id'], 'q-1');
        expect(json['question'], isNotNull);
        expect(json['options'], isA<List>());
        expect(json['correct_answer'], 'Paris');
        expect(json['explanation'], isNotNull);
        expect(json['image_url'], isNotNull);
        expect(json['points'], 10);
      });
    });

    group('toEntity', () {
      test('always_shouldMapCorrectly', () {
        // Arrange
        final model = ActivityQuestionModel.fromJson(ActivityFixtures.validQuestionJson());

        // Act
        final entity = model.toEntity();

        // Assert
        expect(entity, isA<ActivityQuestion>());
        expect(entity.id, model.id);
        expect(entity.question, model.question);
        expect(entity.options, model.options);
        expect(entity.correctAnswer, model.correctAnswer);
        expect(entity.explanation, model.explanation);
        expect(entity.imageUrl, model.imageUrl);
        expect(entity.points, model.points);
      });
    });
  });
}
