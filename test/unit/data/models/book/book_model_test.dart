import 'package:flutter_test/flutter_test.dart';
import 'package:readeng/data/models/book/book_model.dart';
import 'package:readeng/domain/entities/book.dart';

import '../../../../fixtures/book_fixtures.dart';

void main() {
  group('BookModel', () {
    // ============================================
    // fromJson Tests
    // ============================================
    group('fromJson', () {
      test('withValidData_shouldCreateModel', () {
        // Arrange
        final json = BookFixtures.validBookJson();

        // Act
        final model = BookModel.fromJson(json);

        // Assert
        expect(model.id, 'book-123');
        expect(model.title, 'The Great Adventure');
        expect(model.slug, 'the-great-adventure');
        expect(model.description, 'An exciting story about adventure and discovery.');
        expect(model.coverUrl, 'https://example.com/covers/book-123.jpg');
        expect(model.level, 'B1');
        expect(model.genre, 'adventure');
        expect(model.ageGroup, '12-15');
        expect(model.estimatedMinutes, 25);
        expect(model.wordCount, 5000);
        expect(model.chapterCount, 10);
        expect(model.status, BookStatus.published);
        expect(model.metadata, isNotEmpty);
        expect(model.metadata['author'], 'Jane Author');
        expect(model.publishedAt, isNotNull);
      });

      test('withMinimalData_shouldUseDefaults', () {
        // Arrange
        final json = BookFixtures.minimalBookJson();

        // Act
        final model = BookModel.fromJson(json);

        // Assert
        expect(model.id, 'book-minimal');
        expect(model.title, 'Minimal Book');
        expect(model.slug, 'minimal-book');
        expect(model.level, 'A1');
        expect(model.description, isNull);
        expect(model.coverUrl, isNull);
        expect(model.genre, isNull);
        expect(model.ageGroup, isNull);
        expect(model.estimatedMinutes, isNull);
        expect(model.wordCount, isNull);
        expect(model.chapterCount, 0); // default
        expect(model.status, BookStatus.draft); // default
        expect(model.metadata, isEmpty); // default empty map
        expect(model.publishedAt, isNull);
      });

      test('withNullOptionalFields_shouldUseDefaults', () {
        // Arrange
        final json = BookFixtures.bookJsonWithNulls();

        // Act
        final model = BookModel.fromJson(json);

        // Assert
        expect(model.description, isNull);
        expect(model.coverUrl, isNull);
        expect(model.genre, isNull);
        expect(model.ageGroup, isNull);
        expect(model.estimatedMinutes, isNull);
        expect(model.wordCount, isNull);
        expect(model.chapterCount, 0);
        expect(model.status, BookStatus.draft);
        expect(model.metadata, isEmpty);
        expect(model.publishedAt, isNull);
      });

      test('withDraftStatus_shouldParseCorrectly', () {
        // Arrange
        final json = BookFixtures.draftBookJson();

        // Act
        final model = BookModel.fromJson(json);

        // Assert
        expect(model.status, BookStatus.draft);
      });

      test('withArchivedStatus_shouldParseCorrectly', () {
        // Arrange
        final json = BookFixtures.validBookJson();
        json['status'] = 'archived';

        // Act
        final model = BookModel.fromJson(json);

        // Assert
        expect(model.status, BookStatus.archived);
      });

      test('withUnknownStatus_shouldDefaultToDraft', () {
        // Arrange
        final json = BookFixtures.validBookJson();
        json['status'] = 'unknown_status';

        // Act
        final model = BookModel.fromJson(json);

        // Assert
        expect(model.status, BookStatus.draft);
      });

      test('withMissingId_shouldThrowTypeError', () {
        // Arrange
        final json = BookFixtures.invalidBookJsonMissingId();

        // Act & Assert
        expect(
          () => BookModel.fromJson(json),
          throwsA(isA<TypeError>()),
        );
      });

      test('withMissingSlug_shouldThrowTypeError', () {
        // Arrange
        final json = BookFixtures.invalidBookJsonMissingSlug();

        // Act & Assert
        expect(
          () => BookModel.fromJson(json),
          throwsA(isA<TypeError>()),
        );
      });

      test('withInvalidDateFormat_shouldThrowFormatException', () {
        // Arrange
        final json = BookFixtures.invalidBookJsonBadDate();

        // Act & Assert
        expect(
          () => BookModel.fromJson(json),
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
        final model = BookModel(
          id: 'book-123',
          title: 'Test Book',
          slug: 'test-book',
          description: 'A test description',
          coverUrl: 'https://example.com/cover.jpg',
          level: 'B1',
          genre: 'fiction',
          ageGroup: '12-15',
          estimatedMinutes: 30,
          wordCount: 3000,
          chapterCount: 5,
          status: BookStatus.published,
          metadata: const {'key': 'value'},
          publishedAt: DateTime.parse('2024-01-01T00:00:00Z'),
          createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
          updatedAt: DateTime.parse('2024-01-15T10:30:00Z'),
        );

        // Act
        final json = model.toJson();

        // Assert
        expect(json['id'], 'book-123');
        expect(json['title'], 'Test Book');
        expect(json['slug'], 'test-book');
        expect(json['description'], 'A test description');
        expect(json['cover_url'], 'https://example.com/cover.jpg');
        expect(json['level'], 'B1');
        expect(json['genre'], 'fiction');
        expect(json['age_group'], '12-15');
        expect(json['estimated_minutes'], 30);
        expect(json['word_count'], 3000);
        expect(json['chapter_count'], 5);
        expect(json['status'], 'published');
        expect(json['metadata'], {'key': 'value'});
        expect(json['published_at'], isNotNull);
        expect(json['created_at'], isNotNull);
        expect(json['updated_at'], isNotNull);
      });

      test('withNullOptionalFields_shouldIncludeNulls', () {
        // Arrange
        final model = BookModel(
          id: 'book-123',
          title: 'Test Book',
          slug: 'test-book',
          level: 'A1',
          createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
          updatedAt: DateTime.parse('2024-01-01T00:00:00Z'),
        );

        // Act
        final json = model.toJson();

        // Assert
        expect(json.containsKey('description'), true);
        expect(json['description'], isNull);
        expect(json.containsKey('cover_url'), true);
        expect(json['cover_url'], isNull);
        expect(json.containsKey('published_at'), true);
        expect(json['published_at'], isNull);
      });
    });

    // ============================================
    // toEntity Tests
    // ============================================
    group('toEntity', () {
      test('always_shouldMapAllFieldsCorrectly', () {
        // Arrange
        final model = BookModel.fromJson(BookFixtures.validBookJson());

        // Act
        final entity = model.toEntity();

        // Assert
        expect(entity, isA<Book>());
        expect(entity.id, model.id);
        expect(entity.title, model.title);
        expect(entity.slug, model.slug);
        expect(entity.description, model.description);
        expect(entity.coverUrl, model.coverUrl);
        expect(entity.level, model.level);
        expect(entity.genre, model.genre);
        expect(entity.ageGroup, model.ageGroup);
        expect(entity.estimatedMinutes, model.estimatedMinutes);
        expect(entity.wordCount, model.wordCount);
        expect(entity.chapterCount, model.chapterCount);
        expect(entity.status, model.status);
        expect(entity.metadata, model.metadata);
        expect(entity.publishedAt, model.publishedAt);
        expect(entity.createdAt, model.createdAt);
        expect(entity.updatedAt, model.updatedAt);
      });

      test('roundTrip_jsonToEntityAndBack_shouldPreserveData', () {
        // Arrange
        final originalJson = BookFixtures.validBookJson();

        // Act
        final model = BookModel.fromJson(originalJson);
        final entity = model.toEntity();
        final modelFromEntity = BookModel.fromEntity(entity);
        final resultJson = modelFromEntity.toJson();

        // Assert
        expect(resultJson['id'], originalJson['id']);
        expect(resultJson['title'], originalJson['title']);
        expect(resultJson['slug'], originalJson['slug']);
        expect(resultJson['level'], originalJson['level']);
        expect(resultJson['chapter_count'], originalJson['chapter_count']);
        expect(resultJson['status'], originalJson['status']);
      });
    });

    // ============================================
    // fromEntity Tests
    // ============================================
    group('fromEntity', () {
      test('always_shouldMapAllFieldsCorrectly', () {
        // Arrange
        final entity = BookFixtures.validBook();

        // Act
        final model = BookModel.fromEntity(entity);

        // Assert
        expect(model.id, entity.id);
        expect(model.title, entity.title);
        expect(model.slug, entity.slug);
        expect(model.description, entity.description);
        expect(model.coverUrl, entity.coverUrl);
        expect(model.level, entity.level);
        expect(model.genre, entity.genre);
        expect(model.ageGroup, entity.ageGroup);
        expect(model.estimatedMinutes, entity.estimatedMinutes);
        expect(model.wordCount, entity.wordCount);
        expect(model.chapterCount, entity.chapterCount);
        expect(model.status, entity.status);
        expect(model.metadata, entity.metadata);
        expect(model.publishedAt, entity.publishedAt);
        expect(model.createdAt, entity.createdAt);
        expect(model.updatedAt, entity.updatedAt);
      });
    });

    // ============================================
    // Edge Cases
    // ============================================
    group('edgeCases', () {
      test('withEmptyTitle_shouldAccept', () {
        // Arrange
        final json = BookFixtures.minimalBookJson();
        json['title'] = '';

        // Act
        final model = BookModel.fromJson(json);

        // Assert
        expect(model.title, '');
      });

      test('withVeryLongTitle_shouldAccept', () {
        // Arrange
        final json = BookFixtures.minimalBookJson();
        json['title'] = 'A' * 1000; // Very long title

        // Act
        final model = BookModel.fromJson(json);

        // Assert
        expect(model.title.length, 1000);
      });

      test('withZeroChapterCount_shouldAccept', () {
        // Arrange
        final json = BookFixtures.minimalBookJson();
        json['chapter_count'] = 0;

        // Act
        final model = BookModel.fromJson(json);

        // Assert
        expect(model.chapterCount, 0);
      });

      test('withNegativeWordCount_shouldAccept', () {
        // Arrange - edge case that shouldn't happen but model should handle
        final json = BookFixtures.validBookJson();
        json['word_count'] = -100;

        // Act
        final model = BookModel.fromJson(json);

        // Assert
        expect(model.wordCount, -100);
      });

      test('withSpecialCharactersInTitle_shouldAccept', () {
        // Arrange
        final json = BookFixtures.minimalBookJson();
        json['title'] = "Book's Title: A \"Special\" Edition — Vol. 1";

        // Act
        final model = BookModel.fromJson(json);

        // Assert
        expect(model.title, "Book's Title: A \"Special\" Edition — Vol. 1");
      });

      test('withUnicodeInTitle_shouldAccept', () {
        // Arrange
        final json = BookFixtures.minimalBookJson();
        json['title'] = '日本語タイトル 📚';

        // Act
        final model = BookModel.fromJson(json);

        // Assert
        expect(model.title, '日本語タイトル 📚');
      });

      test('withEmptyMetadata_shouldReturnEmptyMap', () {
        // Arrange
        final json = BookFixtures.minimalBookJson();
        json['metadata'] = <String, dynamic>{};

        // Act
        final model = BookModel.fromJson(json);

        // Assert
        expect(model.metadata, isEmpty);
        expect(model.metadata, isA<Map<String, dynamic>>());
      });

      test('withNestedMetadata_shouldPreserveStructure', () {
        // Arrange
        final json = BookFixtures.validBookJson();
        json['metadata'] = {
          'author': {'name': 'John', 'bio': 'Writer'},
          'tags': ['fiction', 'adventure'],
          'rating': 4.5,
        };

        // Act
        final model = BookModel.fromJson(json);

        // Assert
        expect(model.metadata['author'], isA<Map>());
        expect(model.metadata['tags'], isA<List>());
        expect(model.metadata['rating'], 4.5);
      });
    });

    // ============================================
    // List Parsing Tests
    // ============================================
    group('listParsing', () {
      test('parseBookList_shouldReturnCorrectCount', () {
        // Arrange
        final jsonList = BookFixtures.bookListJson();

        // Act
        final models = jsonList.map((json) => BookModel.fromJson(json)).toList();

        // Assert
        expect(models.length, 3);
        expect(models[0].id, 'book-123');
        expect(models[1].id, 'book-minimal');
        expect(models[2].id, 'book-draft');
      });

      test('parseEmptyList_shouldReturnEmptyList', () {
        // Arrange
        final jsonList = <Map<String, dynamic>>[];

        // Act
        final models = jsonList.map((json) => BookModel.fromJson(json)).toList();

        // Assert
        expect(models, isEmpty);
      });
    });
  });
}
