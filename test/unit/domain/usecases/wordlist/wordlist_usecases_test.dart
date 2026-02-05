import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:readeng/core/errors/failures.dart';
import 'package:readeng/domain/entities/vocabulary.dart';
import 'package:readeng/domain/entities/word_list.dart';
import 'package:readeng/domain/repositories/word_list_repository.dart';
import 'package:readeng/domain/usecases/wordlist/get_all_word_lists_usecase.dart';
import 'package:readeng/domain/usecases/wordlist/get_word_list_by_id_usecase.dart';
import 'package:readeng/domain/usecases/wordlist/get_words_for_list_usecase.dart';
import 'package:readeng/domain/usecases/wordlist/get_user_word_list_progress_usecase.dart';
import 'package:readeng/domain/usecases/wordlist/get_progress_for_list_usecase.dart';
import 'package:readeng/domain/usecases/wordlist/update_word_list_progress_usecase.dart';
import 'package:readeng/domain/usecases/wordlist/complete_phase_usecase.dart';
import 'package:readeng/domain/usecases/wordlist/reset_progress_usecase.dart';

import '../../../../fixtures/vocabulary_fixtures.dart';
import '../../../../fixtures/wordlist_fixtures.dart';
import 'wordlist_usecases_test.mocks.dart';

@GenerateMocks([WordListRepository])
void main() {
  late MockWordListRepository mockWordListRepository;

  setUp(() {
    mockWordListRepository = MockWordListRepository();
  });

  // ============================================
  // GetAllWordListsUseCase Tests
  // ============================================
  group('GetAllWordListsUseCase', () {
    late GetAllWordListsUseCase usecase;

    setUp(() {
      usecase = GetAllWordListsUseCase(mockWordListRepository);
    });

    test('withNoFilters_shouldReturnAllWordLists', () async {
      // Arrange
      final wordLists = WordListFixtures.wordListList();
      when(mockWordListRepository.getAllWordLists(
        category: null,
        isSystem: null,
      )).thenAnswer((_) async => Right(wordLists));

      const params = GetAllWordListsParams();

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedLists) {
          expect(returnedLists.length, 4);
          expect(returnedLists[0].name, 'Common Words Level 1');
        },
      );
    });

    test('withCategoryFilter_shouldReturnFilteredLists', () async {
      // Arrange
      final wordLists = [WordListFixtures.validWordList()];
      when(mockWordListRepository.getAllWordLists(
        category: WordListCategory.commonWords,
        isSystem: null,
      )).thenAnswer((_) async => Right(wordLists));

      const params = GetAllWordListsParams(category: WordListCategory.commonWords);

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedLists) {
          expect(returnedLists.length, 1);
          expect(returnedLists[0].category, WordListCategory.commonWords);
        },
      );
    });

    test('withSystemFilter_shouldReturnSystemLists', () async {
      // Arrange
      final wordLists = WordListFixtures.systemWordLists();
      when(mockWordListRepository.getAllWordLists(
        category: null,
        isSystem: true,
      )).thenAnswer((_) async => Right(wordLists));

      const params = GetAllWordListsParams(isSystem: true);

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedLists) {
          expect(returnedLists.every((l) => l.isSystem), true);
        },
      );
    });

    test('withNoLists_shouldReturnEmptyList', () async {
      // Arrange
      when(mockWordListRepository.getAllWordLists(
        category: WordListCategory.gradeLevel,
        isSystem: null,
      )).thenAnswer((_) async => const Right(<WordList>[]));

      const params = GetAllWordListsParams(category: WordListCategory.gradeLevel);

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedLists) => expect(returnedLists, isEmpty),
      );
    });

    test('withServerError_shouldReturnServerFailure', () async {
      // Arrange
      when(mockWordListRepository.getAllWordLists(
        category: null,
        isSystem: null,
      )).thenAnswer((_) async => const Left(ServerFailure('Server error')));

      const params = GetAllWordListsParams();

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
  // GetWordListByIdUseCase Tests
  // ============================================
  group('GetWordListByIdUseCase', () {
    late GetWordListByIdUseCase usecase;

    setUp(() {
      usecase = GetWordListByIdUseCase(mockWordListRepository);
    });

    test('withValidId_shouldReturnWordList', () async {
      // Arrange
      final wordList = WordListFixtures.validWordList();
      when(mockWordListRepository.getWordListById('list-123'))
          .thenAnswer((_) async => Right(wordList));

      const params = GetWordListByIdParams(listId: 'list-123');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedList) {
          expect(returnedList.id, 'list-123');
          expect(returnedList.name, 'Common Words Level 1');
          expect(returnedList.wordCount, 500);
        },
      );
    });

    test('withNotFoundId_shouldReturnNotFoundFailure', () async {
      // Arrange
      when(mockWordListRepository.getWordListById('non-existent'))
          .thenAnswer((_) async => const Left(NotFoundFailure('List not found')));

      const params = GetWordListByIdParams(listId: 'non-existent');

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
  // GetWordsForListUseCase Tests
  // ============================================
  group('GetWordsForListUseCase', () {
    late GetWordsForListUseCase usecase;

    setUp(() {
      usecase = GetWordsForListUseCase(mockWordListRepository);
    });

    test('withValidListId_shouldReturnWords', () async {
      // Arrange
      final words = VocabularyWordFixtures.wordList();
      when(mockWordListRepository.getWordsForList('list-123'))
          .thenAnswer((_) async => Right(words));

      const params = GetWordsForListParams(listId: 'list-123');

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
    });

    test('withEmptyList_shouldReturnEmptyList', () async {
      // Arrange
      when(mockWordListRepository.getWordsForList('empty-list'))
          .thenAnswer((_) async => const Right(<VocabularyWord>[]));

      const params = GetWordsForListParams(listId: 'empty-list');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedWords) => expect(returnedWords, isEmpty),
      );
    });

    test('withNotFoundListId_shouldReturnNotFoundFailure', () async {
      // Arrange
      when(mockWordListRepository.getWordsForList('non-existent'))
          .thenAnswer((_) async => const Left(NotFoundFailure('List not found')));

      const params = GetWordsForListParams(listId: 'non-existent');

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
  // GetUserWordListProgressUseCase Tests
  // ============================================
  group('GetUserWordListProgressUseCase', () {
    late GetUserWordListProgressUseCase usecase;

    setUp(() {
      usecase = GetUserWordListProgressUseCase(mockWordListRepository);
    });

    test('withValidUserId_shouldReturnProgressList', () async {
      // Arrange
      final progressList = UserWordListProgressFixtures.progressList();
      when(mockWordListRepository.getUserWordListProgress('user-123'))
          .thenAnswer((_) async => Right(progressList));

      const params = GetUserWordListProgressParams(userId: 'user-123');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedProgress) {
          expect(returnedProgress.length, 3);
          expect(returnedProgress[0].userId, 'user-123');
        },
      );
    });

    test('withNewUser_shouldReturnEmptyList', () async {
      // Arrange
      when(mockWordListRepository.getUserWordListProgress('new-user'))
          .thenAnswer((_) async => const Right(<UserWordListProgress>[]));

      const params = GetUserWordListProgressParams(userId: 'new-user');

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
  // GetProgressForListUseCase Tests
  // ============================================
  group('GetProgressForListUseCase', () {
    late GetProgressForListUseCase usecase;

    setUp(() {
      usecase = GetProgressForListUseCase(mockWordListRepository);
    });

    test('withExistingProgress_shouldReturnProgress', () async {
      // Arrange
      final progress = UserWordListProgressFixtures.validProgress();
      when(mockWordListRepository.getProgressForList(
        userId: 'user-123',
        listId: 'list-123',
      )).thenAnswer((_) async => Right(progress));

      const params = GetProgressForListParams(
        userId: 'user-123',
        listId: 'list-123',
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedProgress) {
          expect(returnedProgress, isNotNull);
          expect(returnedProgress!.userId, 'user-123');
          expect(returnedProgress.wordListId, 'list-123');
          expect(returnedProgress.phase1Complete, true);
          expect(returnedProgress.phase2Complete, true);
          expect(returnedProgress.phase3Complete, false);
        },
      );
    });

    test('withNoProgress_shouldReturnNull', () async {
      // Arrange
      when(mockWordListRepository.getProgressForList(
        userId: 'user-123',
        listId: 'new-list',
      )).thenAnswer((_) async => const Right(null));

      const params = GetProgressForListParams(
        userId: 'user-123',
        listId: 'new-list',
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedProgress) => expect(returnedProgress, isNull),
      );
    });
  });

  // ============================================
  // UpdateWordListProgressUseCase Tests
  // ============================================
  group('UpdateWordListProgressUseCase', () {
    late UpdateWordListProgressUseCase usecase;

    setUp(() {
      usecase = UpdateWordListProgressUseCase(mockWordListRepository);
    });

    test('withValidProgress_shouldReturnUpdatedProgress', () async {
      // Arrange
      final progress = UserWordListProgressFixtures.validProgress();
      when(mockWordListRepository.updateWordListProgress(progress))
          .thenAnswer((_) async => Right(progress));

      final params = UpdateWordListProgressParams(progress: progress);

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedProgress) {
          expect(returnedProgress.id, progress.id);
          expect(returnedProgress.phase1Complete, progress.phase1Complete);
        },
      );
    });

    test('withCompletedProgress_shouldReturnCompletedProgress', () async {
      // Arrange
      final progress = UserWordListProgressFixtures.completedProgress();
      when(mockWordListRepository.updateWordListProgress(progress))
          .thenAnswer((_) async => Right(progress));

      final params = UpdateWordListProgressParams(progress: progress);

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedProgress) {
          expect(returnedProgress.isFullyComplete, true);
          expect(returnedProgress.completedAt, isNotNull);
        },
      );
    });

    test('withServerError_shouldReturnServerFailure', () async {
      // Arrange
      final progress = UserWordListProgressFixtures.validProgress();
      when(mockWordListRepository.updateWordListProgress(progress))
          .thenAnswer((_) async => const Left(ServerFailure('Update failed')));

      final params = UpdateWordListProgressParams(progress: progress);

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
  // CompletePhaseUseCase Tests
  // ============================================
  group('CompletePhaseUseCase', () {
    late CompletePhaseUseCase usecase;

    setUp(() {
      usecase = CompletePhaseUseCase(mockWordListRepository);
    });

    test('withPhase1_shouldReturnProgressWithPhase1Complete', () async {
      // Arrange
      final progress = UserWordListProgressFixtures.phase1CompleteProgress();
      when(mockWordListRepository.completePhase(
        userId: 'user-123',
        listId: 'list-123',
        phase: 1,
        score: null,
        total: null,
      )).thenAnswer((_) async => Right(progress));

      const params = CompletePhaseParams(
        userId: 'user-123',
        listId: 'list-123',
        phase: 1,
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedProgress) {
          expect(returnedProgress.phase1Complete, true);
          expect(returnedProgress.nextPhase, 2);
        },
      );
    });

    test('withPhase4AndScore_shouldReturnProgressWithScore', () async {
      // Arrange
      final progress = UserWordListProgressFixtures.completedProgress();
      when(mockWordListRepository.completePhase(
        userId: 'user-123',
        listId: 'list-789',
        phase: 4,
        score: 18,
        total: 20,
      )).thenAnswer((_) async => Right(progress));

      const params = CompletePhaseParams(
        userId: 'user-123',
        listId: 'list-789',
        phase: 4,
        score: 18,
        total: 20,
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedProgress) {
          expect(returnedProgress.phase4Complete, true);
          expect(returnedProgress.phase4Score, 18);
          expect(returnedProgress.phase4Total, 20);
          expect(returnedProgress.isFullyComplete, true);
        },
      );
    });

    test('withInvalidPhase_shouldReturnValidationFailure', () async {
      // Arrange
      when(mockWordListRepository.completePhase(
        userId: 'user-123',
        listId: 'list-123',
        phase: 5, // Invalid phase
        score: null,
        total: null,
      )).thenAnswer((_) async => const Left(ValidationFailure('Invalid phase')));

      const params = CompletePhaseParams(
        userId: 'user-123',
        listId: 'list-123',
        phase: 5,
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('Should return failure'),
      );
    });
  });

  // ============================================
  // ResetProgressUseCase Tests
  // ============================================
  group('ResetProgressUseCase', () {
    late ResetProgressUseCase usecase;

    setUp(() {
      usecase = ResetProgressUseCase(mockWordListRepository);
    });

    test('withValidParams_shouldReturnSuccess', () async {
      // Arrange
      when(mockWordListRepository.resetProgress(
        userId: 'user-123',
        listId: 'list-123',
      )).thenAnswer((_) async => const Right(null));

      const params = ResetProgressParams(
        userId: 'user-123',
        listId: 'list-123',
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      verify(mockWordListRepository.resetProgress(
        userId: 'user-123',
        listId: 'list-123',
      )).called(1);
    });

    test('withNotFoundProgress_shouldReturnNotFoundFailure', () async {
      // Arrange
      when(mockWordListRepository.resetProgress(
        userId: 'user-123',
        listId: 'non-existent',
      )).thenAnswer((_) async => const Left(NotFoundFailure('Progress not found')));

      const params = ResetProgressParams(
        userId: 'user-123',
        listId: 'non-existent',
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
    test('getAllWordLists_withBothFilters_shouldWork', () async {
      // Arrange
      final usecase = GetAllWordListsUseCase(mockWordListRepository);
      final wordLists = [WordListFixtures.testPrepList()];
      when(mockWordListRepository.getAllWordLists(
        category: WordListCategory.testPrep,
        isSystem: true,
      )).thenAnswer((_) async => Right(wordLists));

      const params = GetAllWordListsParams(
        category: WordListCategory.testPrep,
        isSystem: true,
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedLists) {
          expect(returnedLists[0].category, WordListCategory.testPrep);
          expect(returnedLists[0].isSystem, true);
        },
      );
    });

    test('userWordListProgress_progressPercentage_shouldCalculateCorrectly', () {
      // Test progress percentage calculation
      final progress = UserWordListProgressFixtures.validProgress();
      expect(progress.progressPercentage, 0.5); // 2 of 4 phases complete
      expect(progress.completedPhases, 2);

      final completedProgress = UserWordListProgressFixtures.completedProgress();
      expect(completedProgress.progressPercentage, 1.0); // All 4 phases complete
      expect(completedProgress.completedPhases, 4);

      final freshProgress = UserWordListProgressFixtures.freshProgress();
      expect(freshProgress.progressPercentage, 0.0); // No phases complete
      expect(freshProgress.completedPhases, 0);
    });

    test('userWordListProgress_nextPhase_shouldReturnCorrectPhase', () {
      final freshProgress = UserWordListProgressFixtures.freshProgress();
      expect(freshProgress.nextPhase, 1);

      final phase1Progress = UserWordListProgressFixtures.phase1CompleteProgress();
      expect(phase1Progress.nextPhase, 2);

      final phase3Progress = UserWordListProgressFixtures.phase3CompleteProgress();
      expect(phase3Progress.nextPhase, 4);

      final completedProgress = UserWordListProgressFixtures.completedProgress();
      expect(completedProgress.nextPhase, isNull);
    });
  });

  // ============================================
  // Params Tests
  // ============================================
  group('paramsTests', () {
    test('getAllWordListsParams_shouldHaveCorrectDefaults', () {
      // Act
      const params = GetAllWordListsParams();

      // Assert
      expect(params.category, isNull);
      expect(params.isSystem, isNull);
    });

    test('getWordListByIdParams_shouldStoreListId', () {
      // Act
      const params = GetWordListByIdParams(listId: 'test-list');

      // Assert
      expect(params.listId, 'test-list');
    });

    test('getWordsForListParams_shouldStoreListId', () {
      // Act
      const params = GetWordsForListParams(listId: 'test-list');

      // Assert
      expect(params.listId, 'test-list');
    });

    test('getUserWordListProgressParams_shouldStoreUserId', () {
      // Act
      const params = GetUserWordListProgressParams(userId: 'test-user');

      // Assert
      expect(params.userId, 'test-user');
    });

    test('getProgressForListParams_shouldStoreUserIdAndListId', () {
      // Act
      const params = GetProgressForListParams(
        userId: 'test-user',
        listId: 'test-list',
      );

      // Assert
      expect(params.userId, 'test-user');
      expect(params.listId, 'test-list');
    });

    test('completePhaseParams_shouldStoreAllFields', () {
      // Act
      const params = CompletePhaseParams(
        userId: 'test-user',
        listId: 'test-list',
        phase: 4,
        score: 18,
        total: 20,
      );

      // Assert
      expect(params.userId, 'test-user');
      expect(params.listId, 'test-list');
      expect(params.phase, 4);
      expect(params.score, 18);
      expect(params.total, 20);
    });

    test('completePhaseParams_shouldHaveOptionalScoreAndTotal', () {
      // Act
      const params = CompletePhaseParams(
        userId: 'test-user',
        listId: 'test-list',
        phase: 1,
      );

      // Assert
      expect(params.score, isNull);
      expect(params.total, isNull);
    });

    test('resetProgressParams_shouldStoreUserIdAndListId', () {
      // Act
      const params = ResetProgressParams(
        userId: 'test-user',
        listId: 'test-list',
      );

      // Assert
      expect(params.userId, 'test-user');
      expect(params.listId, 'test-list');
    });
  });
}
