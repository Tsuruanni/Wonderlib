import 'package:flutter_test/flutter_test.dart';
import 'package:readeng/data/models/book/reading_progress_model.dart';
import 'package:readeng/domain/entities/reading_progress.dart';

import '../../../../fixtures/book_fixtures.dart';

void main() {
  group('ReadingProgressModel', () {
    // ============================================
    // fromJson Tests
    // ============================================
    group('fromJson', () {
      test('withValidData_shouldCreateModel', () {
        // Arrange
        final json = ReadingProgressFixtures.validProgressJson();

        // Act
        final model = ReadingProgressModel.fromJson(json);

        // Assert
        expect(model.id, 'progress-1');
        expect(model.userId, 'user-123');
        expect(model.bookId, 'book-123');
        expect(model.chapterId, 'chapter-2');
        expect(model.currentPage, 5);
        expect(model.isCompleted, false);
        expect(model.completionPercentage, 33.3);
        expect(model.totalReadingTime, 600);
        expect(model.completedChapterIds, ['chapter-1']);
        expect(model.startedAt, isNotNull);
        expect(model.completedAt, isNull);
        expect(model.updatedAt, isNotNull);
      });

      test('withMinimalData_shouldUseDefaults', () {
        // Arrange
        final json = ReadingProgressFixtures.minimalProgressJson();

        // Act
        final model = ReadingProgressModel.fromJson(json);

        // Assert
        expect(model.id, 'progress-minimal');
        expect(model.userId, 'user-123');
        expect(model.bookId, 'book-123');
        expect(model.chapterId, isNull);
        expect(model.currentPage, 1); // default
        expect(model.isCompleted, false); // default
        expect(model.completionPercentage, 0.0); // default
        expect(model.totalReadingTime, 0); // default
        expect(model.completedChapterIds, isEmpty); // default
      });

      test('withCompletedProgress_shouldParseCorrectly', () {
        // Arrange
        final json = ReadingProgressFixtures.completedProgressJson();

        // Act
        final model = ReadingProgressModel.fromJson(json);

        // Assert
        expect(model.isCompleted, true);
        expect(model.completionPercentage, 100.0);
        expect(model.completedChapterIds.length, 10);
        expect(model.completedAt, isNotNull);
      });

      test('withFreshProgress_shouldParseCorrectly', () {
        // Arrange
        final json = ReadingProgressFixtures.freshProgressJson();

        // Act
        final model = ReadingProgressModel.fromJson(json);

        // Assert
        expect(model.chapterId, isNull);
        expect(model.currentPage, 1);
        expect(model.isCompleted, false);
        expect(model.completionPercentage, 0.0);
        expect(model.totalReadingTime, 0);
        expect(model.completedChapterIds, isEmpty);
        expect(model.completedAt, isNull);
      });

      test('withNullOptionalFields_shouldUseDefaults', () {
        // Arrange
        final json = ReadingProgressFixtures.progressJsonWithNulls();

        // Act
        final model = ReadingProgressModel.fromJson(json);

        // Assert
        expect(model.chapterId, isNull);
        expect(model.currentPage, 1);
        expect(model.isCompleted, false);
        expect(model.completionPercentage, 0.0);
        expect(model.totalReadingTime, 0);
        expect(model.completedChapterIds, isEmpty);
      });

      test('withMissingId_shouldThrowTypeError', () {
        // Arrange
        final json = ReadingProgressFixtures.invalidProgressJsonMissingId();

        // Act & Assert
        expect(
          () => ReadingProgressModel.fromJson(json),
          throwsA(isA<TypeError>()),
        );
      });

      test('withInvalidDateFormat_shouldThrowFormatException', () {
        // Arrange
        final json = <String, dynamic>{
          'id': 'progress-1',
          'user_id': 'user-123',
          'book_id': 'book-123',
          'started_at': 'invalid-date',
          'updated_at': '2024-01-01T00:00:00Z',
        };

        // Act & Assert
        expect(
          () => ReadingProgressModel.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });

      test('withIntegerCompletionPercentage_shouldConvertToDouble', () {
        // Arrange
        final json = ReadingProgressFixtures.validProgressJson();
        json['completion_percentage'] = 50; // integer

        // Act
        final model = ReadingProgressModel.fromJson(json);

        // Assert
        expect(model.completionPercentage, 50.0);
        expect(model.completionPercentage, isA<double>());
      });
    });

    // ============================================
    // toJson Tests
    // ============================================
    group('toJson', () {
      test('always_shouldIncludeAllFields', () {
        // Arrange
        final model = ReadingProgressModel(
          id: 'progress-1',
          userId: 'user-123',
          bookId: 'book-123',
          chapterId: 'chapter-2',
          currentPage: 5,
          isCompleted: false,
          completionPercentage: 33.3,
          totalReadingTime: 600,
          completedChapterIds: const ['chapter-1'],
          startedAt: DateTime.parse('2024-01-01T00:00:00Z'),
          completedAt: null,
          updatedAt: DateTime.parse('2024-01-15T10:30:00Z'),
        );

        // Act
        final json = model.toJson();

        // Assert
        expect(json['id'], 'progress-1');
        expect(json['user_id'], 'user-123');
        expect(json['book_id'], 'book-123');
        expect(json['chapter_id'], 'chapter-2');
        expect(json['current_page'], 5);
        expect(json['is_completed'], false);
        expect(json['completion_percentage'], 33.3);
        expect(json['total_reading_time'], 600);
        expect(json['completed_chapter_ids'], ['chapter-1']);
        expect(json['started_at'], isNotNull);
        expect(json['completed_at'], isNull);
        expect(json['updated_at'], isNotNull);
      });

      test('withCompletedProgress_shouldIncludeCompletedAt', () {
        // Arrange
        final model = ReadingProgressModel(
          id: 'progress-1',
          userId: 'user-123',
          bookId: 'book-123',
          isCompleted: true,
          completionPercentage: 100.0,
          startedAt: DateTime.parse('2024-01-01T00:00:00Z'),
          completedAt: DateTime.parse('2024-01-15T10:30:00Z'),
          updatedAt: DateTime.parse('2024-01-15T10:30:00Z'),
        );

        // Act
        final json = model.toJson();

        // Assert
        expect(json['is_completed'], true);
        expect(json['completed_at'], isNotNull);
      });
    });

    // ============================================
    // toEntity Tests
    // ============================================
    group('toEntity', () {
      test('always_shouldMapAllFieldsCorrectly', () {
        // Arrange
        final model = ReadingProgressModel.fromJson(
          ReadingProgressFixtures.validProgressJson(),
        );

        // Act
        final entity = model.toEntity();

        // Assert
        expect(entity, isA<ReadingProgress>());
        expect(entity.id, model.id);
        expect(entity.userId, model.userId);
        expect(entity.bookId, model.bookId);
        expect(entity.chapterId, model.chapterId);
        expect(entity.currentPage, model.currentPage);
        expect(entity.isCompleted, model.isCompleted);
        expect(entity.completionPercentage, model.completionPercentage);
        expect(entity.totalReadingTime, model.totalReadingTime);
        expect(entity.completedChapterIds, model.completedChapterIds);
        expect(entity.startedAt, model.startedAt);
        expect(entity.completedAt, model.completedAt);
        expect(entity.updatedAt, model.updatedAt);
      });

      test('roundTrip_shouldPreserveData', () {
        // Arrange
        final originalJson = ReadingProgressFixtures.validProgressJson();

        // Act
        final model = ReadingProgressModel.fromJson(originalJson);
        final entity = model.toEntity();
        final modelFromEntity = ReadingProgressModel.fromEntity(entity);
        final resultJson = modelFromEntity.toJson();

        // Assert
        expect(resultJson['id'], originalJson['id']);
        expect(resultJson['user_id'], originalJson['user_id']);
        expect(resultJson['book_id'], originalJson['book_id']);
        expect(resultJson['chapter_id'], originalJson['chapter_id']);
        expect(resultJson['current_page'], originalJson['current_page']);
        expect(resultJson['is_completed'], originalJson['is_completed']);
      });
    });

    // ============================================
    // fromEntity Tests
    // ============================================
    group('fromEntity', () {
      test('always_shouldMapAllFieldsCorrectly', () {
        // Arrange
        final entity = ReadingProgressFixtures.validProgress();

        // Act
        final model = ReadingProgressModel.fromEntity(entity);

        // Assert
        expect(model.id, entity.id);
        expect(model.userId, entity.userId);
        expect(model.bookId, entity.bookId);
        expect(model.chapterId, entity.chapterId);
        expect(model.currentPage, entity.currentPage);
        expect(model.isCompleted, entity.isCompleted);
        expect(model.completionPercentage, entity.completionPercentage);
        expect(model.totalReadingTime, entity.totalReadingTime);
        expect(model.completedChapterIds, entity.completedChapterIds);
        expect(model.startedAt, entity.startedAt);
        expect(model.completedAt, entity.completedAt);
        expect(model.updatedAt, entity.updatedAt);
      });

      test('withCompletedEntity_shouldMapCorrectly', () {
        // Arrange
        final entity = ReadingProgressFixtures.completedProgress();

        // Act
        final model = ReadingProgressModel.fromEntity(entity);

        // Assert
        expect(model.isCompleted, true);
        expect(model.completionPercentage, 100.0);
        expect(model.completedAt, isNotNull);
      });
    });

    // ============================================
    // Edge Cases
    // ============================================
    group('edgeCases', () {
      test('withZeroCurrentPage_shouldAccept', () {
        // Arrange
        final json = ReadingProgressFixtures.validProgressJson();
        json['current_page'] = 0;

        // Act
        final model = ReadingProgressModel.fromJson(json);

        // Assert
        expect(model.currentPage, 0);
      });

      test('withNegativeReadingTime_shouldAccept', () {
        // Arrange - edge case that shouldn't happen but model should handle
        final json = ReadingProgressFixtures.validProgressJson();
        json['total_reading_time'] = -100;

        // Act
        final model = ReadingProgressModel.fromJson(json);

        // Assert
        expect(model.totalReadingTime, -100);
      });

      test('withVeryHighCompletionPercentage_shouldAccept', () {
        // Arrange - bonus percentage scenario
        final json = ReadingProgressFixtures.validProgressJson();
        json['completion_percentage'] = 105.5;

        // Act
        final model = ReadingProgressModel.fromJson(json);

        // Assert
        expect(model.completionPercentage, 105.5);
      });

      test('withManyCompletedChapters_shouldParseAll', () {
        // Arrange
        final json = ReadingProgressFixtures.validProgressJson();
        json['completed_chapter_ids'] = List.generate(100, (i) => 'chapter-$i');

        // Act
        final model = ReadingProgressModel.fromJson(json);

        // Assert
        expect(model.completedChapterIds.length, 100);
        expect(model.completedChapterIds[0], 'chapter-0');
        expect(model.completedChapterIds[99], 'chapter-99');
      });

      test('withVeryLargeReadingTime_shouldAccept', () {
        // Arrange - 100 hours in seconds
        final json = ReadingProgressFixtures.validProgressJson();
        json['total_reading_time'] = 360000;

        // Act
        final model = ReadingProgressModel.fromJson(json);

        // Assert
        expect(model.totalReadingTime, 360000);
      });

      test('withFractionalCompletionPercentage_shouldPreservePrecision', () {
        // Arrange
        final json = ReadingProgressFixtures.validProgressJson();
        json['completion_percentage'] = 66.6666666667;

        // Act
        final model = ReadingProgressModel.fromJson(json);

        // Assert
        expect(model.completionPercentage, closeTo(66.6666666667, 0.0000001));
      });
    });

    // ============================================
    // Completion State Tests
    // ============================================
    group('completionState', () {
      test('freshProgress_shouldBeIncomplete', () {
        // Arrange
        final model = ReadingProgressModel.fromJson(
          ReadingProgressFixtures.freshProgressJson(),
        );

        // Assert
        expect(model.isCompleted, false);
        expect(model.completionPercentage, 0.0);
        expect(model.completedChapterIds, isEmpty);
        expect(model.completedAt, isNull);
      });

      test('inProgressProgress_shouldHavePartialCompletion', () {
        // Arrange
        final model = ReadingProgressModel.fromJson(
          ReadingProgressFixtures.validProgressJson(),
        );

        // Assert
        expect(model.isCompleted, false);
        expect(model.completionPercentage, greaterThan(0));
        expect(model.completionPercentage, lessThan(100));
        expect(model.completedChapterIds, isNotEmpty);
        expect(model.completedAt, isNull);
      });

      test('completedProgress_shouldBeFullyComplete', () {
        // Arrange
        final model = ReadingProgressModel.fromJson(
          ReadingProgressFixtures.completedProgressJson(),
        );

        // Assert
        expect(model.isCompleted, true);
        expect(model.completionPercentage, 100.0);
        expect(model.completedChapterIds, isNotEmpty);
        expect(model.completedAt, isNotNull);
      });
    });
  });
}
