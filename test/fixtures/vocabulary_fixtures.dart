import 'package:readeng/domain/entities/vocabulary.dart';

/// Test fixtures for Vocabulary-related tests
class VocabularyWordFixtures {
  VocabularyWordFixtures._();

  // ============================================
  // JSON Fixtures
  // ============================================

  static Map<String, dynamic> validWordJson() => {
        'id': 'word-123',
        'word': 'adventure',
        'phonetic': '/ədˈventʃər/',
        'meaning_tr': 'macera',
        'meaning_en': 'an unusual and exciting experience',
        'example_sentences': [
          'Life is an adventure.',
          'She went on a great adventure.',
        ],
        'audio_url': 'https://example.com/audio/adventure.mp3',
        'image_url': 'https://example.com/images/adventure.jpg',
        'level': 'B1',
        'categories': ['travel', 'experience'],
        'synonyms': ['journey', 'expedition', 'quest'],
        'antonyms': ['boredom', 'routine'],
        'created_at': '2024-01-01T00:00:00Z',
      };

  static Map<String, dynamic> minimalWordJson() => {
        'id': 'word-minimal',
        'word': 'hello',
        'meaning_tr': 'merhaba',
        'created_at': '2024-01-01T00:00:00Z',
      };

  static Map<String, dynamic> advancedWordJson() => {
        'id': 'word-advanced',
        'word': 'ephemeral',
        'phonetic': '/ɪˈfemərəl/',
        'meaning_tr': 'geçici, kısa ömürlü',
        'meaning_en': 'lasting for a very short time',
        'example_sentences': ['Fame is ephemeral.'],
        'level': 'C1',
        'categories': ['advanced', 'abstract'],
        'synonyms': ['transient', 'fleeting', 'momentary'],
        'antonyms': ['permanent', 'lasting', 'eternal'],
        'created_at': '2024-01-01T00:00:00Z',
      };

  static Map<String, dynamic> wordJsonWithNulls() => {
        'id': 'word-nulls',
        'word': 'test',
        'phonetic': null,
        'meaning_tr': 'test',
        'meaning_en': null,
        'example_sentences': null,
        'audio_url': null,
        'image_url': null,
        'level': null,
        'categories': null,
        'synonyms': null,
        'antonyms': null,
        'created_at': '2024-01-01T00:00:00Z',
      };

  static Map<String, dynamic> invalidWordJsonMissingId() => {
        'word': 'missing',
        'meaning_tr': 'eksik',
        'created_at': '2024-01-01T00:00:00Z',
      };

  static List<Map<String, dynamic>> wordListJson() => [
        validWordJson(),
        minimalWordJson(),
        advancedWordJson(),
      ];

  // ============================================
  // Entity Fixtures
  // ============================================

  static VocabularyWord validWord() => VocabularyWord(
        id: 'word-123',
        word: 'adventure',
        phonetic: '/ədˈventʃər/',
        meaningTR: 'macera',
        meaningEN: 'an unusual and exciting experience',
        exampleSentences: const [
          'Life is an adventure.',
          'She went on a great adventure.',
        ],
        audioUrl: 'https://example.com/audio/adventure.mp3',
        imageUrl: 'https://example.com/images/adventure.jpg',
        level: 'B1',
        categories: const ['travel', 'experience'],
        synonyms: const ['journey', 'expedition', 'quest'],
        antonyms: const ['boredom', 'routine'],
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
      );

  static VocabularyWord minimalWord() => VocabularyWord(
        id: 'word-minimal',
        word: 'hello',
        meaningTR: 'merhaba',
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
      );

  static VocabularyWord advancedWord() => VocabularyWord(
        id: 'word-advanced',
        word: 'ephemeral',
        phonetic: '/ɪˈfemərəl/',
        meaningTR: 'geçici, kısa ömürlü',
        meaningEN: 'lasting for a very short time',
        exampleSentences: const ['Fame is ephemeral.'],
        level: 'C1',
        categories: const ['advanced', 'abstract'],
        synonyms: const ['transient', 'fleeting', 'momentary'],
        antonyms: const ['permanent', 'lasting', 'eternal'],
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
      );

  static List<VocabularyWord> wordList() => [
        validWord(),
        minimalWord(),
        advancedWord(),
      ];
}

/// Test fixtures for VocabularyProgress-related tests
class VocabularyProgressFixtures {
  VocabularyProgressFixtures._();

  // ============================================
  // JSON Fixtures
  // ============================================

  static Map<String, dynamic> validProgressJson() => {
        'id': 'progress-vocab-1',
        'user_id': 'user-123',
        'word_id': 'word-123',
        'status': 'learning',
        'ease_factor': 2.5,
        'interval_days': 6,
        'repetitions': 2,
        'next_review_at': '2024-01-20T00:00:00Z',
        'last_reviewed_at': '2024-01-14T10:30:00Z',
        'created_at': '2024-01-01T00:00:00Z',
      };

  static Map<String, dynamic> newWordProgressJson() => {
        'id': 'progress-new',
        'user_id': 'user-123',
        'word_id': 'word-456',
        'status': 'new_word',
        'ease_factor': 2.5,
        'interval_days': 0,
        'repetitions': 0,
        'next_review_at': null,
        'last_reviewed_at': null,
        'created_at': '2024-01-15T00:00:00Z',
      };

  static Map<String, dynamic> masteredProgressJson() => {
        'id': 'progress-mastered',
        'user_id': 'user-123',
        'word_id': 'word-789',
        'status': 'mastered',
        'ease_factor': 2.8,
        'interval_days': 30,
        'repetitions': 5,
        'next_review_at': '2024-02-15T00:00:00Z',
        'last_reviewed_at': '2024-01-15T10:30:00Z',
        'created_at': '2024-01-01T00:00:00Z',
      };

  static Map<String, dynamic> reviewingProgressJson() => {
        'id': 'progress-reviewing',
        'user_id': 'user-123',
        'word_id': 'word-abc',
        'status': 'reviewing',
        'ease_factor': 2.3,
        'interval_days': 12,
        'repetitions': 3,
        'next_review_at': '2024-01-27T00:00:00Z',
        'last_reviewed_at': '2024-01-15T10:30:00Z',
        'created_at': '2024-01-01T00:00:00Z',
      };

  static Map<String, dynamic> progressJsonWithNulls() => {
        'id': 'progress-nulls',
        'user_id': 'user-123',
        'word_id': 'word-xyz',
        'status': null,
        'ease_factor': null,
        'interval_days': null,
        'repetitions': null,
        'next_review_at': null,
        'last_reviewed_at': null,
        'created_at': '2024-01-01T00:00:00Z',
      };

  static Map<String, dynamic> invalidProgressJsonMissingId() => {
        'user_id': 'user-123',
        'word_id': 'word-123',
        'status': 'learning',
        'created_at': '2024-01-01T00:00:00Z',
      };

  // ============================================
  // Entity Fixtures
  // ============================================

  static VocabularyProgress validProgress() => VocabularyProgress(
        id: 'progress-vocab-1',
        userId: 'user-123',
        wordId: 'word-123',
        status: VocabularyStatus.learning,
        easeFactor: 2.5,
        intervalDays: 6,
        repetitions: 2,
        nextReviewAt: DateTime.parse('2024-01-20T00:00:00Z'),
        lastReviewedAt: DateTime.parse('2024-01-14T10:30:00Z'),
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
      );

  static VocabularyProgress newWordProgress() => VocabularyProgress(
        id: 'progress-new',
        userId: 'user-123',
        wordId: 'word-456',
        status: VocabularyStatus.newWord,
        easeFactor: 2.5,
        intervalDays: 0,
        repetitions: 0,
        createdAt: DateTime.parse('2024-01-15T00:00:00Z'),
      );

  static VocabularyProgress masteredProgress() => VocabularyProgress(
        id: 'progress-mastered',
        userId: 'user-123',
        wordId: 'word-789',
        status: VocabularyStatus.mastered,
        easeFactor: 2.8,
        intervalDays: 30,
        repetitions: 5,
        nextReviewAt: DateTime.parse('2024-02-15T00:00:00Z'),
        lastReviewedAt: DateTime.parse('2024-01-15T10:30:00Z'),
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
      );

  static VocabularyProgress reviewingProgress() => VocabularyProgress(
        id: 'progress-reviewing',
        userId: 'user-123',
        wordId: 'word-abc',
        status: VocabularyStatus.reviewing,
        easeFactor: 2.3,
        intervalDays: 12,
        repetitions: 3,
        nextReviewAt: DateTime.parse('2024-01-27T00:00:00Z'),
        lastReviewedAt: DateTime.parse('2024-01-15T10:30:00Z'),
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
      );

  static List<VocabularyProgress> progressList() => [
        validProgress(),
        newWordProgress(),
        masteredProgress(),
        reviewingProgress(),
      ];

  /// Stats map fixture
  static Map<String, int> validStats() => {
        'total': 150,
        'new': 30,
        'learning': 45,
        'reviewing': 50,
        'mastered': 25,
        'due_today': 12,
      };
}
