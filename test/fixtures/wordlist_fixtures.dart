import 'package:readeng/domain/entities/word_list.dart';

/// Test fixtures for WordList-related tests
class WordListFixtures {
  WordListFixtures._();

  // ============================================
  // JSON Fixtures
  // ============================================

  static Map<String, dynamic> validWordListJson() => {
        'id': 'list-123',
        'name': 'Common Words Level 1',
        'description': 'Most frequently used 500 English words',
        'level': 'A1',
        'category': 'common_words',
        'word_count': 500,
        'cover_image_url': 'https://example.com/covers/common1.jpg',
        'is_system': true,
        'source_book_id': null,
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-15T10:30:00Z',
      };

  static Map<String, dynamic> storyVocabListJson() => {
        'id': 'list-story-123',
        'name': 'The Great Adventure - Vocabulary',
        'description': 'Key vocabulary from The Great Adventure',
        'level': 'B1',
        'category': 'story_vocab',
        'word_count': 50,
        'cover_image_url': null,
        'is_system': false,
        'source_book_id': 'book-123',
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      };

  static Map<String, dynamic> testPrepListJson() => {
        'id': 'list-yds',
        'name': 'YDS Essential Words',
        'description': 'Essential vocabulary for YDS exam',
        'level': 'B2',
        'category': 'test_prep',
        'word_count': 1000,
        'cover_image_url': 'https://example.com/covers/yds.jpg',
        'is_system': true,
        'source_book_id': null,
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      };

  static Map<String, dynamic> thematicListJson() => {
        'id': 'list-animals',
        'name': 'Animals',
        'description': 'Learn animal names in English',
        'level': 'A2',
        'category': 'thematic',
        'word_count': 100,
        'cover_image_url': 'https://example.com/covers/animals.jpg',
        'is_system': true,
        'source_book_id': null,
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      };

  static List<Map<String, dynamic>> wordListListJson() => [
        validWordListJson(),
        storyVocabListJson(),
        testPrepListJson(),
        thematicListJson(),
      ];

  // ============================================
  // Entity Fixtures
  // ============================================

  static WordList validWordList() => WordList(
        id: 'list-123',
        name: 'Common Words Level 1',
        description: 'Most frequently used 500 English words',
        level: 'A1',
        category: WordListCategory.commonWords,
        wordCount: 500,
        coverImageUrl: 'https://example.com/covers/common1.jpg',
        isSystem: true,
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2024-01-15T10:30:00Z'),
      );

  static WordList storyVocabList() => WordList(
        id: 'list-story-123',
        name: 'The Great Adventure - Vocabulary',
        description: 'Key vocabulary from The Great Adventure',
        level: 'B1',
        category: WordListCategory.storyVocab,
        wordCount: 50,
        isSystem: false,
        sourceBookId: 'book-123',
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2024-01-01T00:00:00Z'),
      );

  static WordList testPrepList() => WordList(
        id: 'list-yds',
        name: 'YDS Essential Words',
        description: 'Essential vocabulary for YDS exam',
        level: 'B2',
        category: WordListCategory.testPrep,
        wordCount: 1000,
        coverImageUrl: 'https://example.com/covers/yds.jpg',
        isSystem: true,
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2024-01-01T00:00:00Z'),
      );

  static WordList thematicList() => WordList(
        id: 'list-animals',
        name: 'Animals',
        description: 'Learn animal names in English',
        level: 'A2',
        category: WordListCategory.thematic,
        wordCount: 100,
        coverImageUrl: 'https://example.com/covers/animals.jpg',
        isSystem: true,
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2024-01-01T00:00:00Z'),
      );

  static List<WordList> wordListList() => [
        validWordList(),
        storyVocabList(),
        testPrepList(),
        thematicList(),
      ];

  static List<WordList> systemWordLists() => [
        validWordList(),
        testPrepList(),
        thematicList(),
      ];

  static List<WordList> userWordLists() => [
        storyVocabList(),
      ];
}

/// Test fixtures for UserWordListProgress-related tests
class UserWordListProgressFixtures {
  UserWordListProgressFixtures._();

  // ============================================
  // JSON Fixtures
  // ============================================

  static Map<String, dynamic> validProgressJson() => {
        'id': 'progress-wl-1',
        'user_id': 'user-123',
        'word_list_id': 'list-123',
        'phase1_complete': true,
        'phase2_complete': true,
        'phase3_complete': false,
        'phase4_complete': false,
        'phase4_score': null,
        'phase4_total': null,
        'started_at': '2024-01-10T00:00:00Z',
        'completed_at': null,
        'updated_at': '2024-01-15T10:30:00Z',
      };

  static Map<String, dynamic> freshProgressJson() => {
        'id': 'progress-wl-fresh',
        'user_id': 'user-123',
        'word_list_id': 'list-456',
        'phase1_complete': false,
        'phase2_complete': false,
        'phase3_complete': false,
        'phase4_complete': false,
        'phase4_score': null,
        'phase4_total': null,
        'started_at': '2024-01-15T00:00:00Z',
        'completed_at': null,
        'updated_at': '2024-01-15T00:00:00Z',
      };

  static Map<String, dynamic> completedProgressJson() => {
        'id': 'progress-wl-complete',
        'user_id': 'user-123',
        'word_list_id': 'list-789',
        'phase1_complete': true,
        'phase2_complete': true,
        'phase3_complete': true,
        'phase4_complete': true,
        'phase4_score': 18,
        'phase4_total': 20,
        'started_at': '2024-01-01T00:00:00Z',
        'completed_at': '2024-01-15T10:30:00Z',
        'updated_at': '2024-01-15T10:30:00Z',
      };

  // ============================================
  // Entity Fixtures
  // ============================================

  static UserWordListProgress validProgress() => UserWordListProgress(
        id: 'progress-wl-1',
        userId: 'user-123',
        wordListId: 'list-123',
        phase1Complete: true,
        phase2Complete: true,
        phase3Complete: false,
        phase4Complete: false,
        startedAt: DateTime.parse('2024-01-10T00:00:00Z'),
        updatedAt: DateTime.parse('2024-01-15T10:30:00Z'),
      );

  static UserWordListProgress freshProgress() => UserWordListProgress(
        id: 'progress-wl-fresh',
        userId: 'user-123',
        wordListId: 'list-456',
        phase1Complete: false,
        phase2Complete: false,
        phase3Complete: false,
        phase4Complete: false,
        startedAt: DateTime.parse('2024-01-15T00:00:00Z'),
        updatedAt: DateTime.parse('2024-01-15T00:00:00Z'),
      );

  static UserWordListProgress completedProgress() => UserWordListProgress(
        id: 'progress-wl-complete',
        userId: 'user-123',
        wordListId: 'list-789',
        phase1Complete: true,
        phase2Complete: true,
        phase3Complete: true,
        phase4Complete: true,
        phase4Score: 18,
        phase4Total: 20,
        startedAt: DateTime.parse('2024-01-01T00:00:00Z'),
        completedAt: DateTime.parse('2024-01-15T10:30:00Z'),
        updatedAt: DateTime.parse('2024-01-15T10:30:00Z'),
      );

  static UserWordListProgress phase1CompleteProgress() => UserWordListProgress(
        id: 'progress-wl-p1',
        userId: 'user-123',
        wordListId: 'list-123',
        phase1Complete: true,
        phase2Complete: false,
        phase3Complete: false,
        phase4Complete: false,
        startedAt: DateTime.parse('2024-01-10T00:00:00Z'),
        updatedAt: DateTime.parse('2024-01-11T00:00:00Z'),
      );

  static UserWordListProgress phase3CompleteProgress() => UserWordListProgress(
        id: 'progress-wl-p3',
        userId: 'user-123',
        wordListId: 'list-123',
        phase1Complete: true,
        phase2Complete: true,
        phase3Complete: true,
        phase4Complete: false,
        startedAt: DateTime.parse('2024-01-10T00:00:00Z'),
        updatedAt: DateTime.parse('2024-01-14T00:00:00Z'),
      );

  static List<UserWordListProgress> progressList() => [
        validProgress(),
        freshProgress(),
        completedProgress(),
      ];
}
