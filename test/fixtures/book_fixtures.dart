import 'package:readeng/domain/entities/book.dart';
import 'package:readeng/domain/entities/chapter.dart';
import 'package:readeng/domain/entities/reading_progress.dart';

/// Test fixtures for Book-related tests
class BookFixtures {
  BookFixtures._();

  // ============================================
  // JSON Fixtures (matching actual BookModel)
  // ============================================

  /// Valid complete book JSON from Supabase
  static Map<String, dynamic> validBookJson() => {
        'id': 'book-123',
        'title': 'The Great Adventure',
        'slug': 'the-great-adventure',
        'description': 'An exciting story about adventure and discovery.',
        'cover_url': 'https://example.com/covers/book-123.jpg',
        'level': 'B1',
        'genre': 'adventure',
        'age_group': '12-15',
        'estimated_minutes': 25,
        'word_count': 5000,
        'chapter_count': 10,
        'status': 'published',
        'metadata': {'author': 'Jane Author', 'isbn': '978-0-123456-78-9'},
        'published_at': '2024-01-01T00:00:00Z',
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-15T10:30:00Z',
      };

  /// Minimal valid book JSON (only required fields)
  static Map<String, dynamic> minimalBookJson() => {
        'id': 'book-minimal',
        'title': 'Minimal Book',
        'slug': 'minimal-book',
        'level': 'A1',
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      };

  /// Draft book JSON
  static Map<String, dynamic> draftBookJson() => {
        'id': 'book-draft',
        'title': 'Work in Progress',
        'slug': 'work-in-progress',
        'level': 'A2',
        'status': 'draft',
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      };

  /// Book with null optional fields
  static Map<String, dynamic> bookJsonWithNulls() => {
        'id': 'book-nulls',
        'title': 'Book With Nulls',
        'slug': 'book-with-nulls',
        'description': null,
        'cover_url': null,
        'level': 'A1',
        'genre': null,
        'age_group': null,
        'estimated_minutes': null,
        'word_count': null,
        'chapter_count': null,
        'status': null,
        'metadata': null,
        'published_at': null,
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      };

  /// Invalid JSON - missing required field (id)
  static Map<String, dynamic> invalidBookJsonMissingId() => {
        'title': 'No ID Book',
        'slug': 'no-id-book',
        'level': 'A1',
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      };

  /// Invalid JSON - missing required field (slug)
  static Map<String, dynamic> invalidBookJsonMissingSlug() => {
        'id': 'book-no-slug',
        'title': 'No Slug Book',
        'level': 'A1',
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      };

  /// Invalid JSON - bad date format
  static Map<String, dynamic> invalidBookJsonBadDate() => {
        'id': 'book-bad-date',
        'title': 'Bad Date Book',
        'slug': 'bad-date-book',
        'level': 'A1',
        'created_at': 'not-a-valid-date',
        'updated_at': '2024-01-01T00:00:00Z',
      };

  /// Book list JSON (for testing list parsing)
  static List<Map<String, dynamic>> bookListJson() => [
        validBookJson(),
        minimalBookJson(),
        draftBookJson(),
      ];

  // ============================================
  // Entity Fixtures
  // ============================================

  /// Valid published book entity
  static Book validBook() => Book(
        id: 'book-123',
        title: 'The Great Adventure',
        slug: 'the-great-adventure',
        description: 'An exciting story about adventure and discovery.',
        coverUrl: 'https://example.com/covers/book-123.jpg',
        level: 'B1',
        genre: 'adventure',
        ageGroup: '12-15',
        estimatedMinutes: 25,
        wordCount: 5000,
        chapterCount: 10,
        status: BookStatus.published,
        metadata: const {'author': 'Jane Author', 'isbn': '978-0-123456-78-9'},
        publishedAt: DateTime.parse('2024-01-01T00:00:00Z'),
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2024-01-15T10:30:00Z'),
      );

  /// Minimal book entity (defaults for optional fields)
  static Book minimalBook() => Book(
        id: 'book-minimal',
        title: 'Minimal Book',
        slug: 'minimal-book',
        level: 'A1',
        chapterCount: 0,
        status: BookStatus.draft,
        metadata: const {},
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2024-01-01T00:00:00Z'),
      );

  /// List of books
  static List<Book> bookList() => [
        validBook(),
        minimalBook(),
      ];
}

/// Test fixtures for Chapter-related tests
class ChapterFixtures {
  ChapterFixtures._();

  /// Valid chapter JSON
  static Map<String, dynamic> validChapterJson() => {
        'id': 'chapter-1',
        'book_id': 'book-123',
        'title': 'The Beginning',
        'slug': 'the-beginning',
        'order_index': 1,
        'content': 'Once upon a time, in a land far away...',
        'word_count': 500,
        'estimated_minutes': 3,
        'audio_url': 'https://example.com/audio/chapter-1.mp3',
        'status': 'published',
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      };

  /// Minimal chapter JSON
  static Map<String, dynamic> minimalChapterJson() => {
        'id': 'chapter-1',
        'book_id': 'book-123',
        'title': 'Chapter 1',
        'slug': 'chapter-1',
        'order_index': 1,
        'content': 'Content here',
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      };

  /// Chapter list JSON
  static List<Map<String, dynamic>> chapterListJson() => [
        validChapterJson(),
        {
          ...validChapterJson(),
          'id': 'chapter-2',
          'title': 'The Middle',
          'slug': 'the-middle',
          'order_index': 2,
        },
        {
          ...validChapterJson(),
          'id': 'chapter-3',
          'title': 'The End',
          'slug': 'the-end',
          'order_index': 3,
        },
      ];
}

/// Test fixtures for ReadingProgress-related tests (matching ReadingProgressModel)
class ReadingProgressFixtures {
  ReadingProgressFixtures._();

  /// Valid reading progress JSON (matching actual ReadingProgressModel)
  static Map<String, dynamic> validProgressJson() => {
        'id': 'progress-1',
        'user_id': 'user-123',
        'book_id': 'book-123',
        'chapter_id': 'chapter-2',
        'current_page': 5,
        'is_completed': false,
        'completion_percentage': 33.3,
        'total_reading_time': 600,
        'completed_chapter_ids': ['chapter-1'],
        'started_at': '2024-01-01T00:00:00Z',
        'completed_at': null,
        'updated_at': '2024-01-15T10:30:00Z',
      };

  /// Minimal progress JSON
  static Map<String, dynamic> minimalProgressJson() => {
        'id': 'progress-minimal',
        'user_id': 'user-123',
        'book_id': 'book-123',
        'started_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      };

  /// Completed book progress JSON
  static Map<String, dynamic> completedProgressJson() => {
        'id': 'progress-completed',
        'user_id': 'user-123',
        'book_id': 'book-123',
        'chapter_id': 'chapter-10',
        'current_page': 1,
        'is_completed': true,
        'completion_percentage': 100.0,
        'total_reading_time': 3600,
        'completed_chapter_ids': [
          'chapter-1',
          'chapter-2',
          'chapter-3',
          'chapter-4',
          'chapter-5',
          'chapter-6',
          'chapter-7',
          'chapter-8',
          'chapter-9',
          'chapter-10'
        ],
        'started_at': '2024-01-01T00:00:00Z',
        'completed_at': '2024-01-15T10:30:00Z',
        'updated_at': '2024-01-15T10:30:00Z',
      };

  /// Fresh progress JSON (just started)
  static Map<String, dynamic> freshProgressJson() => {
        'id': 'progress-fresh',
        'user_id': 'user-123',
        'book_id': 'book-new',
        'chapter_id': null,
        'current_page': 1,
        'is_completed': false,
        'completion_percentage': 0.0,
        'total_reading_time': 0,
        'completed_chapter_ids': <String>[],
        'started_at': '2024-01-15T10:30:00Z',
        'completed_at': null,
        'updated_at': '2024-01-15T10:30:00Z',
      };

  /// Progress with null optional fields
  static Map<String, dynamic> progressJsonWithNulls() => {
        'id': 'progress-nulls',
        'user_id': 'user-123',
        'book_id': 'book-123',
        'chapter_id': null,
        'current_page': null,
        'is_completed': null,
        'completion_percentage': null,
        'total_reading_time': null,
        'completed_chapter_ids': null,
        'started_at': '2024-01-01T00:00:00Z',
        'completed_at': null,
        'updated_at': '2024-01-01T00:00:00Z',
      };

  /// Invalid progress JSON - missing id
  static Map<String, dynamic> invalidProgressJsonMissingId() => {
        'user_id': 'user-123',
        'book_id': 'book-123',
        'started_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      };

  // ============================================
  // Entity Fixtures
  // ============================================

  static ReadingProgress validProgress() => ReadingProgress(
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
        updatedAt: DateTime.parse('2024-01-15T10:30:00Z'),
      );

  static ReadingProgress completedProgress() => ReadingProgress(
        id: 'progress-completed',
        userId: 'user-123',
        bookId: 'book-123',
        chapterId: 'chapter-10',
        currentPage: 1,
        isCompleted: true,
        completionPercentage: 100.0,
        totalReadingTime: 3600,
        completedChapterIds: const [
          'chapter-1',
          'chapter-2',
          'chapter-3',
          'chapter-4',
          'chapter-5',
        ],
        startedAt: DateTime.parse('2024-01-01T00:00:00Z'),
        completedAt: DateTime.parse('2024-01-15T10:30:00Z'),
        updatedAt: DateTime.parse('2024-01-15T10:30:00Z'),
      );
}

/// Test fixtures for Chapter entity
class ChapterEntityFixtures {
  ChapterEntityFixtures._();

  static Chapter validChapter() => Chapter(
        id: 'chapter-1',
        bookId: 'book-123',
        title: 'The Beginning',
        orderIndex: 1,
        content: 'Once upon a time, in a land far away...\n\nThe story continues here.',
        audioUrl: 'https://example.com/audio/chapter-1.mp3',
        imageUrls: const ['https://example.com/img1.jpg'],
        wordCount: 500,
        estimatedMinutes: 3,
        vocabulary: const [
          ChapterVocabulary(
            word: 'adventure',
            meaning: 'An exciting experience',
            phonetic: '/ədˈventʃər/',
          ),
        ],
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2024-01-01T00:00:00Z'),
      );

  static Chapter minimalChapter() => Chapter(
        id: 'chapter-minimal',
        bookId: 'book-123',
        title: 'Minimal Chapter',
        orderIndex: 1,
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2024-01-01T00:00:00Z'),
      );
}
