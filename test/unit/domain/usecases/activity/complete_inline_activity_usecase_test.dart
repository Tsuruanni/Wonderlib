import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:owlio/core/errors/failures.dart';
import 'package:owlio/domain/entities/vocabulary.dart';
import 'package:owlio/domain/usecases/activity/complete_inline_activity_usecase.dart';

import '../../../../mocks/mock_repositories.mocks.dart';

void main() {
  late MockBookRepository mockBookRepo;
  late MockVocabularyRepository mockVocabRepo;
  late CompleteInlineActivityUseCase useCase;

  setUp(() {
    mockBookRepo = MockBookRepository();
    mockVocabRepo = MockVocabularyRepository();
    useCase = CompleteInlineActivityUseCase(mockBookRepo, mockVocabRepo);
  });

  group('CompleteInlineActivityUseCase', () {
    test('new completion without words -> isNewCompletion=true, wordsAdded=0', () async {
      // Arrange
      when(mockBookRepo.saveInlineActivityResult(
        userId: 'user-1',
        activityId: 'act-1',
        isCorrect: true,
        xpEarned: 10,
      )).thenAnswer((_) async => const Right(true));

      // Act
      final result = await useCase(const CompleteInlineActivityParams(
        userId: 'user-1',
        activityId: 'act-1',
        isCorrect: true,
        xpEarned: 10,
        wordsLearned: [],
      ));

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should not fail'),
        (r) {
          expect(r.isNewCompletion, true);
          expect(r.wordsAdded, 0);
        },
      );
      verifyNever(mockVocabRepo.addWordsToVocabularyBatch(
        userId: anyNamed('userId'),
        wordIds: anyNamed('wordIds'),
        immediate: anyNamed('immediate'),
      ));
    });

    test('duplicate completion -> isNewCompletion=false', () async {
      // Arrange: DB returns false (already existed)
      when(mockBookRepo.saveInlineActivityResult(
        userId: 'user-1',
        activityId: 'act-1',
        isCorrect: true,
        xpEarned: 10,
      )).thenAnswer((_) async => const Right(false));

      final now = DateTime(2026, 3, 27);
      when(mockVocabRepo.addWordsToVocabularyBatch(
        userId: 'user-1',
        wordIds: ['word-1'],
        immediate: false, // isCorrect=true, so immediate=!true=false
      )).thenAnswer((_) async => Right([
            VocabularyProgress(
              id: 'vp-1',
              userId: 'user-1',
              wordId: 'word-1',
              nextReviewAt: now,
              createdAt: now,
            ),
          ]));

      // Act
      final result = await useCase(const CompleteInlineActivityParams(
        userId: 'user-1',
        activityId: 'act-1',
        isCorrect: true,
        xpEarned: 10,
        wordsLearned: ['word-1'],
      ));

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should not fail'),
        (r) {
          expect(r.isNewCompletion, false);
        },
      );
      // Words should still be added even on duplicate (idempotent vocab add)
      verify(mockVocabRepo.addWordsToVocabularyBatch(
        userId: 'user-1',
        wordIds: ['word-1'],
        immediate: false,
      )).called(1);
    });

    test('with words learned -> wordsAdded matches returned progress count', () async {
      // Arrange
      when(mockBookRepo.saveInlineActivityResult(
        userId: 'user-1',
        activityId: 'act-1',
        isCorrect: false,
        xpEarned: 5,
      )).thenAnswer((_) async => const Right(true));

      final now = DateTime(2026, 3, 27);
      when(mockVocabRepo.addWordsToVocabularyBatch(
        userId: 'user-1',
        wordIds: ['word-1', 'word-2', 'word-3'],
        immediate: true, // !isCorrect
      )).thenAnswer((_) async => Right([
            VocabularyProgress(
              id: 'vp-1',
              userId: 'user-1',
              wordId: 'word-1',
              nextReviewAt: now,
              createdAt: now,
            ),
            VocabularyProgress(
              id: 'vp-2',
              userId: 'user-1',
              wordId: 'word-2',
              nextReviewAt: now,
              createdAt: now,
            ),
            VocabularyProgress(
              id: 'vp-3',
              userId: 'user-1',
              wordId: 'word-3',
              nextReviewAt: now,
              createdAt: now,
            ),
          ]));

      // Act
      final result = await useCase(const CompleteInlineActivityParams(
        userId: 'user-1',
        activityId: 'act-1',
        isCorrect: false,
        xpEarned: 5,
        wordsLearned: ['word-1', 'word-2', 'word-3'],
      ));

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should not fail'),
        (r) {
          expect(r.isNewCompletion, true);
          expect(r.wordsAdded, 3);
        },
      );
      // immediate=true because isCorrect=false
      verify(mockVocabRepo.addWordsToVocabularyBatch(
        userId: 'user-1',
        wordIds: ['word-1', 'word-2', 'word-3'],
        immediate: true,
      )).called(1);
    });

    test('save failure -> returns failure', () async {
      // Arrange
      when(mockBookRepo.saveInlineActivityResult(
        userId: 'user-1',
        activityId: 'act-1',
        isCorrect: true,
        xpEarned: 10,
      )).thenAnswer((_) async => const Left(ServerFailure('DB error')));

      // Act
      final result = await useCase(const CompleteInlineActivityParams(
        userId: 'user-1',
        activityId: 'act-1',
        isCorrect: true,
        xpEarned: 10,
        wordsLearned: ['word-1'],
      ));

      // Assert
      expect(result.isLeft(), true);
      verifyNever(mockVocabRepo.addWordsToVocabularyBatch(
        userId: anyNamed('userId'),
        wordIds: anyNamed('wordIds'),
        immediate: anyNamed('immediate'),
      ));
    });
  });
}
