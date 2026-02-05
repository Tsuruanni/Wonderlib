import 'package:flutter_test/flutter_test.dart';
import 'package:readeng/data/models/activity/activity_result_model.dart';
import 'package:readeng/domain/entities/activity.dart';

import '../../../../fixtures/activity_fixtures.dart';

void main() {
  group('ActivityResultModel', () {
    // ============================================
    // fromJson Tests
    // ============================================
    group('fromJson', () {
      test('withValidData_shouldCreateModel', () {
        // Arrange
        final json = ActivityResultFixtures.validResultJson();

        // Act
        final model = ActivityResultModel.fromJson(json);

        // Assert
        expect(model.id, 'result-123');
        expect(model.userId, 'user-456');
        expect(model.activityId, 'activity-789');
        expect(model.score, 80.0);
        expect(model.maxScore, 100.0);
        expect(model.answers, isNotEmpty);
        expect(model.answers['q-1'], 'Paris');
        expect(model.answers['q-2'], '4');
        expect(model.timeSpent, 120);
        expect(model.attemptNumber, 1);
        expect(model.completedAt, isNotNull);
      });

      test('withPerfectScore_shouldParseCorrectly', () {
        // Arrange
        final json = ActivityResultFixtures.perfectScoreResultJson();

        // Act
        final model = ActivityResultModel.fromJson(json);

        // Assert
        expect(model.score, 100.0);
        expect(model.maxScore, 100.0);
        expect(model.score / model.maxScore, 1.0); // 100%
      });

      test('withZeroScore_shouldParseCorrectly', () {
        // Arrange
        final json = ActivityResultFixtures.zeroScoreResultJson();

        // Act
        final model = ActivityResultModel.fromJson(json);

        // Assert
        expect(model.score, 0.0);
        expect(model.maxScore, 100.0);
        expect(model.answers, isEmpty);
        expect(model.attemptNumber, 3);
      });

      test('withNullOptionalFields_shouldUseDefaults', () {
        // Arrange
        final json = ActivityResultFixtures.resultJsonWithNulls();

        // Act
        final model = ActivityResultModel.fromJson(json);

        // Assert
        expect(model.answers, isEmpty); // default empty map
        expect(model.timeSpent, isNull);
        expect(model.attemptNumber, 1); // default
      });

      test('withMissingId_shouldThrowTypeError', () {
        // Arrange
        final json = ActivityResultFixtures.invalidResultJsonMissingId();

        // Act & Assert
        expect(
          () => ActivityResultModel.fromJson(json),
          throwsA(isA<TypeError>()),
        );
      });

      test('withIntegerScore_shouldConvertToDouble', () {
        // Arrange
        final json = ActivityResultFixtures.resultJsonWithNulls();
        // score is 50 (int) in this fixture

        // Act
        final model = ActivityResultModel.fromJson(json);

        // Assert
        expect(model.score, 50.0);
        expect(model.score, isA<double>());
      });

      test('withInvalidDateFormat_shouldThrowFormatException', () {
        // Arrange
        final json = <String, dynamic>{
          'id': 'result-123',
          'user_id': 'user-456',
          'activity_id': 'activity-789',
          'score': 80.0,
          'max_score': 100.0,
          'answers': <String, dynamic>{},
          'completed_at': 'invalid-date',
        };

        // Act & Assert
        expect(
          () => ActivityResultModel.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });
    });

    // ============================================
    // toJson Tests
    // ============================================
    group('toJson', () {
      test('always_shouldIncludeAllFields', () {
        // Arrange
        final model = ActivityResultModel(
          id: 'result-123',
          userId: 'user-456',
          activityId: 'activity-789',
          score: 80.0,
          maxScore: 100.0,
          answers: const {'q-1': 'Paris'},
          timeSpent: 120,
          attemptNumber: 1,
          completedAt: DateTime.parse('2024-01-15T10:30:00Z'),
        );

        // Act
        final json = model.toJson();

        // Assert
        expect(json['id'], 'result-123');
        expect(json['user_id'], 'user-456');
        expect(json['activity_id'], 'activity-789');
        expect(json['score'], 80.0);
        expect(json['max_score'], 100.0);
        expect(json['answers'], {'q-1': 'Paris'});
        expect(json['time_spent'], 120);
        expect(json['attempt_number'], 1);
        expect(json['completed_at'], isNotNull);
      });

      test('withNullTimeSpent_shouldIncludeNull', () {
        // Arrange
        final model = ActivityResultModel(
          id: 'result-123',
          userId: 'user-456',
          activityId: 'activity-789',
          score: 50.0,
          maxScore: 100.0,
          answers: const <String, dynamic>{},
          completedAt: DateTime.parse('2024-01-15T10:30:00Z'),
        );

        // Act
        final json = model.toJson();

        // Assert
        expect(json.containsKey('time_spent'), true);
        expect(json['time_spent'], isNull);
      });
    });

    // ============================================
    // toInsertJson Tests
    // ============================================
    group('toInsertJson', () {
      test('always_shouldExcludeId', () {
        // Arrange
        final model = ActivityResultModel(
          id: 'result-123',
          userId: 'user-456',
          activityId: 'activity-789',
          score: 80.0,
          maxScore: 100.0,
          answers: const {'q-1': 'Paris'},
          timeSpent: 120,
          attemptNumber: 1,
          completedAt: DateTime.parse('2024-01-15T10:30:00Z'),
        );

        // Act
        final json = model.toInsertJson();

        // Assert
        expect(json.containsKey('id'), false);
        expect(json['user_id'], 'user-456');
        expect(json['activity_id'], 'activity-789');
        expect(json['score'], 80.0);
      });
    });

    // ============================================
    // toEntity Tests
    // ============================================
    group('toEntity', () {
      test('always_shouldMapAllFieldsCorrectly', () {
        // Arrange
        final model = ActivityResultModel.fromJson(ActivityResultFixtures.validResultJson());

        // Act
        final entity = model.toEntity();

        // Assert
        expect(entity, isA<ActivityResult>());
        expect(entity.id, model.id);
        expect(entity.userId, model.userId);
        expect(entity.activityId, model.activityId);
        expect(entity.score, model.score);
        expect(entity.maxScore, model.maxScore);
        expect(entity.answers, model.answers);
        expect(entity.timeSpent, model.timeSpent);
        expect(entity.attemptNumber, model.attemptNumber);
        expect(entity.completedAt, model.completedAt);
      });

      test('roundTrip_shouldPreserveData', () {
        // Arrange
        final originalJson = ActivityResultFixtures.validResultJson();

        // Act
        final model = ActivityResultModel.fromJson(originalJson);
        final entity = model.toEntity();
        final modelFromEntity = ActivityResultModel.fromEntity(entity);
        final resultJson = modelFromEntity.toJson();

        // Assert
        expect(resultJson['id'], originalJson['id']);
        expect(resultJson['user_id'], originalJson['user_id']);
        expect(resultJson['activity_id'], originalJson['activity_id']);
        expect(resultJson['score'], originalJson['score']);
        expect(resultJson['max_score'], originalJson['max_score']);
        expect(resultJson['attempt_number'], originalJson['attempt_number']);
      });
    });

    // ============================================
    // fromEntity Tests
    // ============================================
    group('fromEntity', () {
      test('always_shouldMapAllFieldsCorrectly', () {
        // Arrange
        final entity = ActivityResultFixtures.validResult();

        // Act
        final model = ActivityResultModel.fromEntity(entity);

        // Assert
        expect(model.id, entity.id);
        expect(model.userId, entity.userId);
        expect(model.activityId, entity.activityId);
        expect(model.score, entity.score);
        expect(model.maxScore, entity.maxScore);
        expect(model.answers, entity.answers);
        expect(model.timeSpent, entity.timeSpent);
        expect(model.attemptNumber, entity.attemptNumber);
        expect(model.completedAt, entity.completedAt);
      });
    });

    // ============================================
    // Edge Cases
    // ============================================
    group('edgeCases', () {
      test('withZeroMaxScore_shouldAccept', () {
        // Arrange - edge case for division safety
        final json = ActivityResultFixtures.validResultJson();
        json['max_score'] = 0;
        json['score'] = 0;

        // Act
        final model = ActivityResultModel.fromJson(json);

        // Assert
        expect(model.maxScore, 0.0);
        expect(model.score, 0.0);
      });

      test('withVeryHighAttemptNumber_shouldAccept', () {
        // Arrange
        final json = ActivityResultFixtures.validResultJson();
        json['attempt_number'] = 999;

        // Act
        final model = ActivityResultModel.fromJson(json);

        // Assert
        expect(model.attemptNumber, 999);
      });

      test('withNegativeTimeSpent_shouldAccept', () {
        // Arrange - edge case that shouldn't happen but model should handle
        final json = ActivityResultFixtures.validResultJson();
        json['time_spent'] = -10;

        // Act
        final model = ActivityResultModel.fromJson(json);

        // Assert
        expect(model.timeSpent, -10);
      });

      test('withComplexAnswersMap_shouldPreserveStructure', () {
        // Arrange
        final json = ActivityResultFixtures.validResultJson();
        json['answers'] = <String, dynamic>{
          'q-1': 'text answer',
          'q-2': true,
          'q-3': 42,
          'q-4': ['option1', 'option2'],
          'q-5': {'nested': 'value'},
        };

        // Act
        final model = ActivityResultModel.fromJson(json);

        // Assert
        expect(model.answers['q-1'], 'text answer');
        expect(model.answers['q-2'], true);
        expect(model.answers['q-3'], 42);
        expect(model.answers['q-4'], isA<List>());
        expect(model.answers['q-5'], isA<Map>());
      });

      test('withFractionalScore_shouldPreservePrecision', () {
        // Arrange
        final json = ActivityResultFixtures.validResultJson();
        json['score'] = 66.6666666667;

        // Act
        final model = ActivityResultModel.fromJson(json);

        // Assert
        expect(model.score, closeTo(66.6666666667, 0.0000001));
      });

      test('withScoreGreaterThanMaxScore_shouldAccept', () {
        // Arrange - bonus points scenario
        final json = ActivityResultFixtures.validResultJson();
        json['score'] = 120.0;
        json['max_score'] = 100.0;

        // Act
        final model = ActivityResultModel.fromJson(json);

        // Assert
        expect(model.score, 120.0);
        expect(model.maxScore, 100.0);
      });
    });

    // ============================================
    // Percentage Calculation Tests
    // ============================================
    group('percentageCalculation', () {
      test('withPerfectScore_shouldCalculate100Percent', () {
        // Arrange
        final model = ActivityResultModel.fromJson(ActivityResultFixtures.perfectScoreResultJson());

        // Act
        final percentage = (model.score / model.maxScore) * 100;

        // Assert
        expect(percentage, 100.0);
      });

      test('withZeroScore_shouldCalculate0Percent', () {
        // Arrange
        final model = ActivityResultModel.fromJson(ActivityResultFixtures.zeroScoreResultJson());

        // Act
        final percentage = model.maxScore > 0 ? (model.score / model.maxScore) * 100 : 0;

        // Assert
        expect(percentage, 0.0);
      });

      test('withPartialScore_shouldCalculateCorrectPercentage', () {
        // Arrange
        final model = ActivityResultModel.fromJson(ActivityResultFixtures.validResultJson());

        // Act
        final percentage = (model.score / model.maxScore) * 100;

        // Assert
        expect(percentage, 80.0);
      });
    });
  });
}
