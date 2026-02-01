import 'package:readeng/domain/entities/book.dart';

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

/// Test fixtures for ReadingProgress-related tests
class ReadingProgressFixtures {
  ReadingProgressFixtures._();

  /// Valid reading progress JSON
  static Map<String, dynamic> validProgressJson() => {
        'id': 'progress-1',
        'user_id': 'user-123',
        'book_id': 'book-123',
        'current_chapter_id': 'chapter-2',
        'current_chapter_index': 2,
        'completed_chapter_ids': ['chapter-1'],
        'completion_percentage': 33.3,
        'total_time_spent': 600,
        'last_read_at': '2024-01-15T10:30:00Z',
        'is_completed': false,
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-15T10:30:00Z',
      };

  /// Completed book progress JSON
  static Map<String, dynamic> completedProgressJson() => {
        'id': 'progress-completed',
        'user_id': 'user-123',
        'book_id': 'book-123',
        'current_chapter_id': 'chapter-10',
        'current_chapter_index': 10,
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
        'completion_percentage': 100.0,
        'total_time_spent': 3600,
        'last_read_at': '2024-01-15T10:30:00Z',
        'is_completed': true,
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-15T10:30:00Z',
      };

  /// Fresh progress JSON (just started)
  static Map<String, dynamic> freshProgressJson() => {
        'id': 'progress-fresh',
        'user_id': 'user-123',
        'book_id': 'book-new',
        'current_chapter_id': null,
        'current_chapter_index': 0,
        'completed_chapter_ids': [],
        'completion_percentage': 0.0,
        'total_time_spent': 0,
        'last_read_at': null,
        'is_completed': false,
        'created_at': '2024-01-15T10:30:00Z',
        'updated_at': '2024-01-15T10:30:00Z',
      };
}
