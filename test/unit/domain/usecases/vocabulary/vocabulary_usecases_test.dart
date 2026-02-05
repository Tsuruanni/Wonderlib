import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:readeng/core/errors/failures.dart';
import 'package:readeng/domain/entities/vocabulary.dart';
import 'package:readeng/domain/repositories/vocabulary_repository.dart';
import 'package:readeng/domain/usecases/vocabulary/get_all_words_usecase.dart';
import 'package:readeng/domain/usecases/vocabulary/get_word_by_id_usecase.dart';
import 'package:readeng/domain/usecases/vocabulary/search_words_usecase.dart';
import 'package:readeng/domain/usecases/vocabulary/get_user_vocabulary_progress_usecase.dart';
import 'package:readeng/domain/usecases/vocabulary/get_word_progress_usecase.dart';
import 'package:readeng/domain/usecases/vocabulary/update_word_progress_usecase.dart';
import 'package:readeng/domain/usecases/vocabulary/get_due_for_review_usecase.dart';
import 'package:readeng/domain/usecases/vocabulary/get_new_words_usecase.dart';
import 'package:readeng/domain/usecases/vocabulary/get_vocabulary_stats_usecase.dart';
import 'package:readeng/domain/usecases/vocabulary/add_word_to_vocabulary_usecase.dart';

import '../../../../fixtures/vocabulary_fixtures.dart';
import 'vocabulary_usecases_test.mocks.dart';

@GenerateMocks([VocabularyRepository])
void main() {
  late MockVocabularyRepository mockVocabularyRepository;

  setUp(() {
    mockVocabularyRepository = MockVocabularyRepository();
  });

  // ============================================
  // GetAllWordsUseCase Tests
  // ============================================
  group('GetAllWordsUseCase', () {
    late GetAllWordsUseCase usecase;

    setUp(() {
      usecase = GetAllWordsUseCase(mockVocabularyRepository);
    });

    test('withDefaultParams_shouldReturnWordList', () async {
      // Arrange
      final words = VocabularyWordFixtures.wordList();
      when(mockVocabularyRepository.getAllWords(
        level: null,
        categories: null,
        page: 1,
        pageSize: 50,
      )).thenAnswer((_) async => Right(words));

      const params = GetAllWordsParams();

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedWords) {
          expect(returnedWords.length, 3);
          expect(returnedWords[0].word, 'adventure');
        },
      );
      verify(mockVocabularyRepository.getAllWords(
        level: null,
        categories: null,
        page: 1,
        pageSize: 50,
      )).called(1);
    });

    test('withLevelFilter_shouldReturnFilteredWords', () async {
      // Arrange
      final words = [VocabularyWordFixtures.validWord()];
      when(mockVocabularyRepository.getAllWords(
        level: 'B1',
        categories: null,
        page: 1,
        pageSize: 50,
      )).thenAnswer((_) async => Right(words));

      const params = GetAllWordsParams(level: 'B1');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedWords) {
          expect(returnedWords.length, 1);
          expect(returnedWords[0].level, 'B1');
        },
      );
    });

    test('withCategoryFilter_shouldReturnFilteredWords', () async {
      // Arrange
      final words = [VocabularyWordFixtures.validWord()];
      when(mockVocabularyRepository.getAllWords(
        level: null,
        categories: ['travel'],
        page: 1,
        pageSize: 50,
      )).thenAnswer((_) async => Right(words));

      const params = GetAllWordsParams(categories: ['travel']);

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedWords) {
          expect(returnedWords[0].categories, contains('travel'));
        },
      );
    });

    test('withPagination_shouldPassPaginationParams', () async {
      // Arrange
      final words = [VocabularyWordFixtures.minimalWord()];
      when(mockVocabularyRepository.getAllWords(
        level: null,
        categories: null,
        page: 2,
        pageSize: 25,
      )).thenAnswer((_) async => Right(words));

      const params = GetAllWordsParams(page: 2, pageSize: 25);

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      verify(mockVocabularyRepository.getAllWords(
        level: null,
        categories: null,
        page: 2,
        pageSize: 25,
      )).called(1);
    });

    test('withNoWords_shouldReturnEmptyList', () async {
      // Arrange
      when(mockVocabularyRepository.getAllWords(
        level: 'C2',
        categories: null,
        page: 1,
        pageSize: 50,
      )).thenAnswer((_) async => const Right(<VocabularyWord>[]));

      const params = GetAllWordsParams(level: 'C2');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedWords) => expect(returnedWords, isEmpty),
      );
    });

    test('withServerError_shouldReturnServerFailure', () async {
      // Arrange
      when(mockVocabularyRepository.getAllWords(
        level: null,
        categories: null,
        page: 1,
        pageSize: 50,
      )).thenAnswer((_) async => const Left(ServerFailure('Server error')));

      const params = GetAllWordsParams();

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('Should return failure'),
      );
    });
  });

  // ============================================
  // GetWordByIdUseCase Tests
  // ============================================
  group('GetWordByIdUseCase', () {
    late GetWordByIdUseCase usecase;

    setUp(() {
      usecase = GetWordByIdUseCase(mockVocabularyRepository);
    });

    test('withValidId_shouldReturnWord', () async {
      // Arrange
      final word = VocabularyWordFixtures.validWord();
      when(mockVocabularyRepository.getWordById('word-123'))
          .thenAnswer((_) async => Right(word));

      const params = GetWordByIdParams(wordId: 'word-123');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedWord) {
          expect(returnedWord.id, 'word-123');
          expect(returnedWord.word, 'adventure');
        },
      );
    });

    test('withNotFoundId_shouldReturnNotFoundFailure', () async {
      // Arrange
      when(mockVocabularyRepository.getWordById('non-existent'))
          .thenAnswer((_) async => const Left(NotFoundFailure('Word not found')));

      const params = GetWordByIdParams(wordId: 'non-existent');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<NotFoundFailure>()),
        (_) => fail('Should return failure'),
      );
    });
  });

  // ============================================
  // SearchWordsUseCase Tests
  // ============================================
  group('SearchWordsUseCase', () {
    late SearchWordsUseCase usecase;

    setUp(() {
      usecase = SearchWordsUseCase(mockVocabularyRepository);
    });

    test('withValidQuery_shouldReturnMatchingWords', () async {
      // Arrange
      final words = [VocabularyWordFixtures.validWord()];
      when(mockVocabularyRepository.searchWords('adventure'))
          .thenAnswer((_) async => Right(words));

      const params = SearchWordsParams(query: 'adventure');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedWords) {
          expect(returnedWords.length, 1);
          expect(returnedWords[0].word, 'adventure');
        },
      );
    });

    test('withPartialQuery_shouldReturnMatchingWords', () async {
      // Arrange
      final words = [VocabularyWordFixtures.validWord()];
      when(mockVocabularyRepository.searchWords('adv'))
          .thenAnswer((_) async => Right(words));

      const params = SearchWordsParams(query: 'adv');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedWords) => expect(returnedWords.length, 1),
      );
    });

    test('withNoMatches_shouldReturnEmptyList', () async {
      // Arrange
      when(mockVocabularyRepository.searchWords('xyz123'))
          .thenAnswer((_) async => const Right(<VocabularyWord>[]));

      const params = SearchWordsParams(query: 'xyz123');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedWords) => expect(returnedWords, isEmpty),
      );
    });
  });

  // ============================================
  // GetUserVocabularyProgressUseCase Tests
  // ============================================
  group('GetUserVocabularyProgressUseCase', () {
    late GetUserVocabularyProgressUseCase usecase;

    setUp(() {
      usecase = GetUserVocabularyProgressUseCase(mockVocabularyRepository);
    });

    test('withValidUserId_shouldReturnProgressList', () async {
      // Arrange
      final progressList = VocabularyProgressFixtures.progressList();
      when(mockVocabularyRepository.getUserProgress('user-123'))
          .thenAnswer((_) async => Right(progressList));

      const params = GetUserVocabularyProgressParams(userId: 'user-123');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedProgress) {
          expect(returnedProgress.length, 4);
          expect(returnedProgress[0].userId, 'user-123');
        },
      );
    });

    test('withNewUser_shouldReturnEmptyList', () async {
      // Arrange
      when(mockVocabularyRepository.getUserProgress('new-user'))
          .thenAnswer((_) async => const Right(<VocabularyProgress>[]));

      const params = GetUserVocabularyProgressParams(userId: 'new-user');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedProgress) => expect(returnedProgress, isEmpty),
      );
    });
  });

  // ============================================
  // GetWordProgressUseCase Tests
  // ============================================
  group('GetWordProgressUseCase', () {
    late GetWordProgressUseCase usecase;

    setUp(() {
      usecase = GetWordProgressUseCase(mockVocabularyRepository);
    });

    test('withValidParams_shouldReturnProgress', () async {
      // Arrange
      final progress = VocabularyProgressFixtures.validProgress();
      when(mockVocabularyRepository.getWordProgress(
        userId: 'user-123',
        wordId: 'word-123',
      )).thenAnswer((_) async => Right(progress));

      const params = GetWordProgressParams(
        userId: 'user-123',
        wordId: 'word-123',
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedProgress) {
          expect(returnedProgress.userId, 'user-123');
          expect(returnedProgress.wordId, 'word-123');
          expect(returnedProgress.status, VocabularyStatus.learning);
        },
      );
    });

    test('withNotFoundProgress_shouldReturnNotFoundFailure', () async {
      // Arrange
      when(mockVocabularyRepository.getWordProgress(
        userId: 'user-123',
        wordId: 'non-existent',
      )).thenAnswer((_) async => const Left(NotFoundFailure('Progress not found')));

      const params = GetWordProgressParams(
        userId: 'user-123',
        wordId: 'non-existent',
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<NotFoundFailure>()),
        (_) => fail('Should return failure'),
      );
    });
  });

  // ============================================
  // UpdateWordProgressUseCase Tests
  // ============================================
  group('UpdateWordProgressUseCase', () {
    late UpdateWordProgressUseCase usecase;

    setUp(() {
      usecase = UpdateWordProgressUseCase(mockVocabularyRepository);
    });

    test('withValidProgress_shouldReturnUpdatedProgress', () async {
      // Arrange
      final progress = VocabularyProgressFixtures.validProgress();
      when(mockVocabularyRepository.updateWordProgress(progress))
          .thenAnswer((_) async => Right(progress));

      final params = UpdateWordProgressParams(progress: progress);

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedProgress) {
          expect(returnedProgress.id, progress.id);
          expect(returnedProgress.status, VocabularyStatus.learning);
        },
      );
    });

    test('withMasteredProgress_shouldReturnMasteredStatus', () async {
      // Arrange
      final progress = VocabularyProgressFixtures.masteredProgress();
      when(mockVocabularyRepository.updateWordProgress(progress))
          .thenAnswer((_) async => Right(progress));

      final params = UpdateWordProgressParams(progress: progress);

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedProgress) {
          expect(returnedProgress.status, VocabularyStatus.mastered);
          expect(returnedProgress.isMastered, true);
        },
      );
    });

    test('withServerError_shouldReturnServerFailure', () async {
      // Arrange
      final progress = VocabularyProgressFixtures.validProgress();
      when(mockVocabularyRepository.updateWordProgress(progress))
          .thenAnswer((_) async => const Left(ServerFailure('Update failed')));

      final params = UpdateWordProgressParams(progress: progress);

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('Should return failure'),
      );
    });
  });

  // ============================================
  // GetDueForReviewUseCase Tests
  // ============================================
  group('GetDueForReviewUseCase', () {
    late GetDueForReviewUseCase usecase;

    setUp(() {
      usecase = GetDueForReviewUseCase(mockVocabularyRepository);
    });

    test('withValidUserId_shouldReturnDueWords', () async {
      // Arrange
      final words = VocabularyWordFixtures.wordList();
      when(mockVocabularyRepository.getDueForReview('user-123'))
          .thenAnswer((_) async => Right(words));

      const params = GetDueForReviewParams(userId: 'user-123');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedWords) {
          expect(returnedWords.length, 3);
        },
      );
    });

    test('withNoDueWords_shouldReturnEmptyList', () async {
      // Arrange
      when(mockVocabularyRepository.getDueForReview('user-123'))
          .thenAnswer((_) async => const Right(<VocabularyWord>[]));

      const params = GetDueForReviewParams(userId: 'user-123');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedWords) => expect(returnedWords, isEmpty),
      );
    });
  });

  // ============================================
  // GetNewWordsUseCase Tests
  // ============================================
  group('GetNewWordsUseCase', () {
    late GetNewWordsUseCase usecase;

    setUp(() {
      usecase = GetNewWordsUseCase(mockVocabularyRepository);
    });

    test('withDefaultLimit_shouldReturnNewWords', () async {
      // Arrange
      final words = VocabularyWordFixtures.wordList();
      when(mockVocabularyRepository.getNewWords(
        userId: 'user-123',
        limit: 10,
      )).thenAnswer((_) async => Right(words));

      const params = GetNewWordsParams(userId: 'user-123');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedWords) {
          expect(returnedWords.length, 3);
        },
      );
      verify(mockVocabularyRepository.getNewWords(
        userId: 'user-123',
        limit: 10,
      )).called(1);
    });

    test('withCustomLimit_shouldPassLimitToRepository', () async {
      // Arrange
      final words = [VocabularyWordFixtures.validWord()];
      when(mockVocabularyRepository.getNewWords(
        userId: 'user-123',
        limit: 5,
      )).thenAnswer((_) async => Right(words));

      const params = GetNewWordsParams(userId: 'user-123', limit: 5);

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      verify(mockVocabularyRepository.getNewWords(
        userId: 'user-123',
        limit: 5,
      )).called(1);
    });
  });

  // ============================================
  // GetVocabularyStatsUseCase Tests
  // ============================================
  group('GetVocabularyStatsUseCase', () {
    late GetVocabularyStatsUseCase usecase;

    setUp(() {
      usecase = GetVocabularyStatsUseCase(mockVocabularyRepository);
    });

    test('withValidUserId_shouldReturnStats', () async {
      // Arrange
      final stats = VocabularyProgressFixtures.validStats();
      when(mockVocabularyRepository.getVocabularyStats('user-123'))
          .thenAnswer((_) async => Right(stats));

      const params = GetVocabularyStatsParams(userId: 'user-123');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedStats) {
          expect(returnedStats['total'], 150);
          expect(returnedStats['mastered'], 25);
          expect(returnedStats['learning'], 45);
          expect(returnedStats['due_today'], 12);
        },
      );
    });

    test('withNewUser_shouldReturnZeroStats', () async {
      // Arrange
      final stats = <String, int>{
        'total': 0,
        'new': 0,
        'learning': 0,
        'reviewing': 0,
        'mastered': 0,
        'due_today': 0,
      };
      when(mockVocabularyRepository.getVocabularyStats('new-user'))
          .thenAnswer((_) async => Right(stats));

      const params = GetVocabularyStatsParams(userId: 'new-user');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedStats) {
          expect(returnedStats['total'], 0);
          expect(returnedStats['mastered'], 0);
        },
      );
    });

    test('withServerError_shouldReturnServerFailure', () async {
      // Arrange
      when(mockVocabularyRepository.getVocabularyStats('user-123'))
          .thenAnswer((_) async => const Left(ServerFailure('Stats unavailable')));

      const params = GetVocabularyStatsParams(userId: 'user-123');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('Should return failure'),
      );
    });
  });

  // ============================================
  // AddWordToVocabularyUseCase Tests
  // ============================================
  group('AddWordToVocabularyUseCase', () {
    late AddWordToVocabularyUseCase usecase;

    setUp(() {
      usecase = AddWordToVocabularyUseCase(mockVocabularyRepository);
    });

    test('withValidParams_shouldReturnNewProgress', () async {
      // Arrange
      final progress = VocabularyProgressFixtures.newWordProgress();
      when(mockVocabularyRepository.addWordToVocabulary(
        userId: 'user-123',
        wordId: 'word-456',
      )).thenAnswer((_) async => Right(progress));

      const params = AddWordToVocabularyParams(
        userId: 'user-123',
        wordId: 'word-456',
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedProgress) {
          expect(returnedProgress.userId, 'user-123');
          expect(returnedProgress.wordId, 'word-456');
          expect(returnedProgress.status, VocabularyStatus.newWord);
          expect(returnedProgress.isNew, true);
        },
      );
    });

    test('withDuplicateWord_shouldReturnConflictFailure', () async {
      // Arrange
      when(mockVocabularyRepository.addWordToVocabulary(
        userId: 'user-123',
        wordId: 'word-123',
      )).thenAnswer((_) async => const Left(ServerFailure('Word already in vocabulary')));

      const params = AddWordToVocabularyParams(
        userId: 'user-123',
        wordId: 'word-123',
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('Should return failure'),
      );
    });

    test('withInvalidWordId_shouldReturnNotFoundFailure', () async {
      // Arrange
      when(mockVocabularyRepository.addWordToVocabulary(
        userId: 'user-123',
        wordId: 'non-existent',
      )).thenAnswer((_) async => const Left(NotFoundFailure('Word not found')));

      const params = AddWordToVocabularyParams(
        userId: 'user-123',
        wordId: 'non-existent',
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<NotFoundFailure>()),
        (_) => fail('Should return failure'),
      );
    });
  });

  // ============================================
  // Edge Cases
  // ============================================
  group('edgeCases', () {
    test('getAllWords_withAllFilters_shouldWork', () async {
      // Arrange
      final usecase = GetAllWordsUseCase(mockVocabularyRepository);
      final words = [VocabularyWordFixtures.advancedWord()];
      when(mockVocabularyRepository.getAllWords(
        level: 'C1',
        categories: ['advanced', 'abstract'],
        page: 3,
        pageSize: 10,
      )).thenAnswer((_) async => Right(words));

      const params = GetAllWordsParams(
        level: 'C1',
        categories: ['advanced', 'abstract'],
        page: 3,
        pageSize: 10,
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedWords) {
          expect(returnedWords[0].level, 'C1');
        },
      );
    });

    test('searchWords_withTurkishQuery_shouldWork', () async {
      // Arrange
      final usecase = SearchWordsUseCase(mockVocabularyRepository);
      final words = [VocabularyWordFixtures.validWord()];
      when(mockVocabularyRepository.searchWords('macera'))
          .thenAnswer((_) async => Right(words));

      const params = SearchWordsParams(query: 'macera');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
    });

    test('updateProgress_withCalculatedNextReview_shouldWork', () async {
      // Arrange
      final usecase = UpdateWordProgressUseCase(mockVocabularyRepository);
      final originalProgress = VocabularyProgressFixtures.validProgress();
      // Simulate SM-2 algorithm calculation
      final updatedProgress = originalProgress.calculateNextReview(4); // Good response

      when(mockVocabularyRepository.updateWordProgress(any))
          .thenAnswer((_) async => Right(updatedProgress));

      final params = UpdateWordProgressParams(progress: updatedProgress);

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedProgress) {
          expect(returnedProgress.repetitions, greaterThan(originalProgress.repetitions));
        },
      );
    });
  });

  // ============================================
  // Params Tests
  // ============================================
  group('paramsTests', () {
    test('getAllWordsParams_shouldHaveCorrectDefaults', () {
      // Act
      const params = GetAllWordsParams();

      // Assert
      expect(params.level, isNull);
      expect(params.categories, isNull);
      expect(params.page, 1);
      expect(params.pageSize, 50);
    });

    test('getNewWordsParams_shouldHaveCorrectDefaults', () {
      // Act
      const params = GetNewWordsParams(userId: 'user-123');

      // Assert
      expect(params.userId, 'user-123');
      expect(params.limit, 10);
    });

    test('searchWordsParams_shouldStoreQuery', () {
      // Act
      const params = SearchWordsParams(query: 'test query');

      // Assert
      expect(params.query, 'test query');
    });

    test('addWordToVocabularyParams_shouldStoreUserIdAndWordId', () {
      // Act
      const params = AddWordToVocabularyParams(
        userId: 'user-123',
        wordId: 'word-456',
      );

      // Assert
      expect(params.userId, 'user-123');
      expect(params.wordId, 'word-456');
    });
  });
}
