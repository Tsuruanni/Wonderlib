import 'package:flutter_test/flutter_test.dart';
import 'package:readeng/data/models/book/chapter_model.dart';
import 'package:readeng/domain/entities/chapter.dart';

import '../../../../fixtures/book_fixtures.dart';

void main() {
  group('ChapterModel', () {
    // ============================================
    // fromJson Tests
    // ============================================
    group('fromJson', () {
      test('withValidData_shouldCreateModel', () {
        // Arrange
        final json = ChapterFixtures.validChapterJson();

        // Act
        final model = ChapterModel.fromJson(json);

        // Assert
        expect(model.id, 'chapter-1');
        expect(model.bookId, 'book-123');
        expect(model.title, 'The Beginning');
        expect(model.orderIndex, 1);
        expect(model.content, isNotNull);
        expect(model.audioUrl, 'https://example.com/audio/chapter-1.mp3');
        expect(model.wordCount, 500);
        expect(model.estimatedMinutes, 3);
      });

      test('withMinimalData_shouldUseDefaults', () {
        // Arrange
        final json = ChapterFixtures.minimalChapterJson();

        // Act
        final model = ChapterModel.fromJson(json);

        // Assert
        expect(model.id, 'chapter-1');
        expect(model.bookId, 'book-123');
        expect(model.title, 'Chapter 1');
        expect(model.orderIndex, 1);
        expect(model.content, 'Content here');
        expect(model.audioUrl, isNull);
        expect(model.imageUrls, isEmpty);
        expect(model.wordCount, isNull);
        expect(model.estimatedMinutes, isNull);
        expect(model.vocabulary, isEmpty);
      });

      test('withVocabulary_shouldParseVocabularyList', () {
        // Arrange
        final json = <String, dynamic>{
          'id': 'chapter-vocab',
          'book_id': 'book-123',
          'title': 'Vocabulary Chapter',
          'order_index': 1,
          'vocabulary': [
            {
              'word': 'adventure',
              'meaning': 'An exciting experience',
              'phonetic': '/ədˈventʃər/',
              'startIndex': 0,
              'endIndex': 9,
            },
            {
              'word': 'journey',
              'meaning': 'A trip from one place to another',
            },
          ],
          'created_at': '2024-01-01T00:00:00Z',
          'updated_at': '2024-01-01T00:00:00Z',
        };

        // Act
        final model = ChapterModel.fromJson(json);

        // Assert
        expect(model.vocabulary.length, 2);
        expect(model.vocabulary[0].word, 'adventure');
        expect(model.vocabulary[0].meaning, 'An exciting experience');
        expect(model.vocabulary[0].phonetic, '/ədˈventʃər/');
        expect(model.vocabulary[0].startIndex, 0);
        expect(model.vocabulary[0].endIndex, 9);
        expect(model.vocabulary[1].word, 'journey');
        expect(model.vocabulary[1].startIndex, isNull);
      });

      test('withImageUrls_shouldParseImageList', () {
        // Arrange
        final json = <String, dynamic>{
          'id': 'chapter-images',
          'book_id': 'book-123',
          'title': 'Image Chapter',
          'order_index': 1,
          'image_urls': [
            'https://example.com/img1.jpg',
            'https://example.com/img2.jpg',
          ],
          'created_at': '2024-01-01T00:00:00Z',
          'updated_at': '2024-01-01T00:00:00Z',
        };

        // Act
        final model = ChapterModel.fromJson(json);

        // Assert
        expect(model.imageUrls.length, 2);
        expect(model.imageUrls[0], 'https://example.com/img1.jpg');
        expect(model.imageUrls[1], 'https://example.com/img2.jpg');
      });

      test('withNullOptionalFields_shouldUseDefaults', () {
        // Arrange
        final json = <String, dynamic>{
          'id': 'chapter-nulls',
          'book_id': 'book-123',
          'title': 'Null Fields Chapter',
          'order_index': 1,
          'content': null,
          'audio_url': null,
          'image_urls': null,
          'word_count': null,
          'estimated_minutes': null,
          'vocabulary': null,
          'created_at': '2024-01-01T00:00:00Z',
          'updated_at': '2024-01-01T00:00:00Z',
        };

        // Act
        final model = ChapterModel.fromJson(json);

        // Assert
        expect(model.content, isNull);
        expect(model.audioUrl, isNull);
        expect(model.imageUrls, isEmpty);
        expect(model.wordCount, isNull);
        expect(model.estimatedMinutes, isNull);
        expect(model.vocabulary, isEmpty);
      });

      test('withMissingId_shouldThrowTypeError', () {
        // Arrange
        final json = <String, dynamic>{
          'book_id': 'book-123',
          'title': 'No ID Chapter',
          'order_index': 1,
          'created_at': '2024-01-01T00:00:00Z',
          'updated_at': '2024-01-01T00:00:00Z',
        };

        // Act & Assert
        expect(
          () => ChapterModel.fromJson(json),
          throwsA(isA<TypeError>()),
        );
      });

      test('withInvalidDateFormat_shouldThrowFormatException', () {
        // Arrange
        final json = <String, dynamic>{
          'id': 'chapter-1',
          'book_id': 'book-123',
          'title': 'Bad Date Chapter',
          'order_index': 1,
          'created_at': 'invalid-date',
          'updated_at': '2024-01-01T00:00:00Z',
        };

        // Act & Assert
        expect(
          () => ChapterModel.fromJson(json),
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
        final model = ChapterModel(
          id: 'chapter-1',
          bookId: 'book-123',
          title: 'Test Chapter',
          orderIndex: 1,
          content: 'Chapter content here',
          audioUrl: 'https://example.com/audio.mp3',
          imageUrls: const ['https://example.com/img.jpg'],
          wordCount: 100,
          estimatedMinutes: 5,
          vocabulary: const [
            ChapterVocabularyModel(word: 'test', meaning: 'a test'),
          ],
          createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
          updatedAt: DateTime.parse('2024-01-15T10:30:00Z'),
        );

        // Act
        final json = model.toJson();

        // Assert
        expect(json['id'], 'chapter-1');
        expect(json['book_id'], 'book-123');
        expect(json['title'], 'Test Chapter');
        expect(json['order_index'], 1);
        expect(json['content'], 'Chapter content here');
        expect(json['audio_url'], 'https://example.com/audio.mp3');
        expect(json['image_urls'], isA<List>());
        expect(json['word_count'], 100);
        expect(json['estimated_minutes'], 5);
        expect(json['vocabulary'], isA<List>());
        expect((json['vocabulary'] as List).length, 1);
      });
    });

    // ============================================
    // toEntity Tests
    // ============================================
    group('toEntity', () {
      test('always_shouldMapAllFieldsCorrectly', () {
        // Arrange
        final model = ChapterModel.fromJson(ChapterFixtures.validChapterJson());

        // Act
        final entity = model.toEntity();

        // Assert
        expect(entity, isA<Chapter>());
        expect(entity.id, model.id);
        expect(entity.bookId, model.bookId);
        expect(entity.title, model.title);
        expect(entity.orderIndex, model.orderIndex);
        expect(entity.content, model.content);
        expect(entity.audioUrl, model.audioUrl);
        expect(entity.imageUrls, model.imageUrls);
        expect(entity.wordCount, model.wordCount);
        expect(entity.estimatedMinutes, model.estimatedMinutes);
      });

      test('roundTrip_shouldPreserveData', () {
        // Arrange
        final originalJson = ChapterFixtures.validChapterJson();

        // Act
        final model = ChapterModel.fromJson(originalJson);
        final entity = model.toEntity();
        final modelFromEntity = ChapterModel.fromEntity(entity);
        final resultJson = modelFromEntity.toJson();

        // Assert
        expect(resultJson['id'], originalJson['id']);
        expect(resultJson['book_id'], originalJson['book_id']);
        expect(resultJson['title'], originalJson['title']);
        expect(resultJson['order_index'], originalJson['order_index']);
      });
    });

    // ============================================
    // fromEntity Tests
    // ============================================
    group('fromEntity', () {
      test('always_shouldMapAllFieldsCorrectly', () {
        // Arrange
        final entity = ChapterEntityFixtures.validChapter();

        // Act
        final model = ChapterModel.fromEntity(entity);

        // Assert
        expect(model.id, entity.id);
        expect(model.bookId, entity.bookId);
        expect(model.title, entity.title);
        expect(model.orderIndex, entity.orderIndex);
        expect(model.content, entity.content);
        expect(model.audioUrl, entity.audioUrl);
        expect(model.imageUrls, entity.imageUrls);
        expect(model.wordCount, entity.wordCount);
        expect(model.estimatedMinutes, entity.estimatedMinutes);
        expect(model.vocabulary.length, entity.vocabulary.length);
      });
    });

    // ============================================
    // Edge Cases
    // ============================================
    group('edgeCases', () {
      test('withEmptyContent_shouldAccept', () {
        // Arrange
        final json = ChapterFixtures.minimalChapterJson();
        json['content'] = '';

        // Act
        final model = ChapterModel.fromJson(json);

        // Assert
        expect(model.content, '');
      });

      test('withVeryLongContent_shouldAccept', () {
        // Arrange
        final json = ChapterFixtures.minimalChapterJson();
        json['content'] = 'A' * 100000; // 100K characters

        // Act
        final model = ChapterModel.fromJson(json);

        // Assert
        expect(model.content?.length, 100000);
      });

      test('withZeroOrderIndex_shouldAccept', () {
        // Arrange
        final json = ChapterFixtures.minimalChapterJson();
        json['order_index'] = 0;

        // Act
        final model = ChapterModel.fromJson(json);

        // Assert
        expect(model.orderIndex, 0);
      });

      test('withSpecialCharactersInTitle_shouldAccept', () {
        // Arrange
        final json = ChapterFixtures.minimalChapterJson();
        json['title'] = "Chapter's \"Title\" — Vol. 1";

        // Act
        final model = ChapterModel.fromJson(json);

        // Assert
        expect(model.title, "Chapter's \"Title\" — Vol. 1");
      });

      test('withUnicodeInContent_shouldAccept', () {
        // Arrange
        final json = ChapterFixtures.minimalChapterJson();
        json['content'] = '日本語コンテンツ 📚 Émojis and ümlauts';

        // Act
        final model = ChapterModel.fromJson(json);

        // Assert
        expect(model.content, '日本語コンテンツ 📚 Émojis and ümlauts');
      });
    });

    // ============================================
    // List Parsing Tests
    // ============================================
    group('listParsing', () {
      test('parseChapterList_shouldReturnCorrectCount', () {
        // Arrange
        final jsonList = ChapterFixtures.chapterListJson();

        // Act
        final models = jsonList.map((json) => ChapterModel.fromJson(json)).toList();

        // Assert
        expect(models.length, 3);
        expect(models[0].orderIndex, 1);
        expect(models[1].orderIndex, 2);
        expect(models[2].orderIndex, 3);
      });
    });
  });

  // ============================================
  // ChapterVocabularyModel Tests
  // ============================================
  group('ChapterVocabularyModel', () {
    group('fromJson', () {
      test('withValidData_shouldCreateModel', () {
        // Arrange
        final json = <String, dynamic>{
          'word': 'adventure',
          'meaning': 'An exciting experience',
          'phonetic': '/ədˈventʃər/',
          'startIndex': 0,
          'endIndex': 9,
        };

        // Act
        final model = ChapterVocabularyModel.fromJson(json);

        // Assert
        expect(model.word, 'adventure');
        expect(model.meaning, 'An exciting experience');
        expect(model.phonetic, '/ədˈventʃər/');
        expect(model.startIndex, 0);
        expect(model.endIndex, 9);
      });

      test('withMinimalData_shouldUseDefaults', () {
        // Arrange
        final json = <String, dynamic>{
          'word': 'test',
        };

        // Act
        final model = ChapterVocabularyModel.fromJson(json);

        // Assert
        expect(model.word, 'test');
        expect(model.meaning, isNull);
        expect(model.phonetic, isNull);
        expect(model.startIndex, isNull);
        expect(model.endIndex, isNull);
      });
    });

    group('toJson', () {
      test('always_shouldIncludeAllFields', () {
        // Arrange
        const model = ChapterVocabularyModel(
          word: 'test',
          meaning: 'a test',
          phonetic: '/test/',
          startIndex: 10,
          endIndex: 14,
        );

        // Act
        final json = model.toJson();

        // Assert
        expect(json['word'], 'test');
        expect(json['meaning'], 'a test');
        expect(json['phonetic'], '/test/');
        expect(json['startIndex'], 10);
        expect(json['endIndex'], 14);
      });
    });

    group('toEntity', () {
      test('always_shouldMapCorrectly', () {
        // Arrange
        const model = ChapterVocabularyModel(
          word: 'adventure',
          meaning: 'An exciting experience',
          phonetic: '/ədˈventʃər/',
          startIndex: 0,
          endIndex: 9,
        );

        // Act
        final entity = model.toEntity();

        // Assert
        expect(entity, isA<ChapterVocabulary>());
        expect(entity.word, model.word);
        expect(entity.meaning, model.meaning);
        expect(entity.phonetic, model.phonetic);
        expect(entity.startIndex, model.startIndex);
        expect(entity.endIndex, model.endIndex);
      });
    });
  });
}
