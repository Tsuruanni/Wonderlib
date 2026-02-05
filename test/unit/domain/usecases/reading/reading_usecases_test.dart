import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:readeng/core/errors/failures.dart';
import 'package:readeng/domain/entities/reading_progress.dart';
import 'package:readeng/domain/usecases/reading/get_reading_progress_usecase.dart';
import 'package:readeng/domain/usecases/reading/mark_chapter_complete_usecase.dart';
import 'package:readeng/domain/usecases/reading/update_reading_progress_usecase.dart';

import '../../../../fixtures/book_fixtures.dart';
import '../../../../mocks/mock_repositories.mocks.dart';

void main() {
  late MockBookRepository mockBookRepository;

  setUp(() {
    mockBookRepository = MockBookRepository();
  });

  // ============================================
  // GetReadingProgressUseCase Tests
  // ============================================
  group('GetReadingProgressUseCase', () {
    late GetReadingProgressUseCase usecase;

    setUp(() {
      usecase = GetReadingProgressUseCase(mockBookRepository);
    });

    test('withValidParams_shouldReturnProgress', () async {
      // Arrange
      final progress = ReadingProgressFixtures.validProgress();
      when(mockBookRepository.getReadingProgress(
        userId: 'user-123',
        bookId: 'book-123',
      )).thenAnswer((_) async => Right(progress));

      const params = GetReadingProgressParams(
        userId: 'user-123',
        bookId: 'book-123',
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedProgress) {
          expect(returnedProgress.id, progress.id);
          expect(returnedProgress.userId, 'user-123');
          expect(returnedProgress.bookId, 'book-123');
          expect(returnedProgress.completionPercentage, 33.3);
        },
      );
      verify(mockBookRepository.getReadingProgress(
        userId: 'user-123',
        bookId: 'book-123',
      )).called(1);
    });

    test('withCompletedBook_shouldReturnCompletedProgress', () async {
      // Arrange
      final progress = ReadingProgressFixtures.completedProgress();
      when(mockBookRepository.getReadingProgress(
        userId: 'user-123',
        bookId: 'book-123',
      )).thenAnswer((_) async => Right(progress));

      const params = GetReadingProgressParams(
        userId: 'user-123',
        bookId: 'book-123',
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedProgress) {
          expect(returnedProgress.isCompleted, true);
          expect(returnedProgress.completionPercentage, 100.0);
        },
      );
    });

    test('withNotFoundProgress_shouldReturnNotFoundFailure', () async {
      // Arrange
      when(mockBookRepository.getReadingProgress(
        userId: 'user-123',
        bookId: 'nonexistent-book',
      )).thenAnswer((_) async => const Left(NotFoundFailure('Progress not found')));

      const params = GetReadingProgressParams(
        userId: 'user-123',
        bookId: 'nonexistent-book',
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<NotFoundFailure>());
          expect(failure.message, 'Progress not found');
        },
        (progress) => fail('Should not return progress'),
      );
    });

    test('withServerError_shouldReturnServerFailure', () async {
      // Arrange
      when(mockBookRepository.getReadingProgress(
        userId: 'user-123',
        bookId: 'book-123',
      )).thenAnswer((_) async => const Left(ServerFailure('Database error')));

      const params = GetReadingProgressParams(
        userId: 'user-123',
        bookId: 'book-123',
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (progress) => fail('Should not return progress'),
      );
    });

    test('withNetworkError_shouldReturnNetworkFailure', () async {
      // Arrange
      when(mockBookRepository.getReadingProgress(
        userId: 'user-123',
        bookId: 'book-123',
      )).thenAnswer((_) async => const Left(NetworkFailure()));

      const params = GetReadingProgressParams(
        userId: 'user-123',
        bookId: 'book-123',
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (progress) => fail('Should not return progress'),
      );
    });

    test('params_shouldStoreUserIdAndBookId', () {
      // Arrange & Act
      const params = GetReadingProgressParams(
        userId: 'test-user',
        bookId: 'test-book',
      );

      // Assert
      expect(params.userId, 'test-user');
      expect(params.bookId, 'test-book');
    });
  });

  // ============================================
  // MarkChapterCompleteUseCase Tests
  // ============================================
  group('MarkChapterCompleteUseCase', () {
    late MarkChapterCompleteUseCase usecase;

    setUp(() {
      usecase = MarkChapterCompleteUseCase(mockBookRepository);
    });

    test('withValidParams_shouldReturnUpdatedProgress', () async {
      // Arrange
      final progress = ReadingProgress(
        id: 'progress-1',
        userId: 'user-123',
        bookId: 'book-123',
        chapterId: 'chapter-2',
        completionPercentage: 50.0,
        completedChapterIds: const ['chapter-1', 'chapter-2'],
        startedAt: DateTime.parse('2024-01-01T00:00:00Z'),
        updatedAt: DateTime.now(),
      );
      when(mockBookRepository.markChapterComplete(
        userId: 'user-123',
        bookId: 'book-123',
        chapterId: 'chapter-2',
      )).thenAnswer((_) async => Right(progress));

      const params = MarkChapterCompleteParams(
        userId: 'user-123',
        bookId: 'book-123',
        chapterId: 'chapter-2',
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedProgress) {
          expect(returnedProgress.completedChapterIds, contains('chapter-2'));
          expect(returnedProgress.completionPercentage, greaterThan(0));
        },
      );
      verify(mockBookRepository.markChapterComplete(
        userId: 'user-123',
        bookId: 'book-123',
        chapterId: 'chapter-2',
      )).called(1);
    });

    test('withLastChapter_shouldMarkBookCompleted', () async {
      // Arrange
      final progress = ReadingProgressFixtures.completedProgress();
      when(mockBookRepository.markChapterComplete(
        userId: 'user-123',
        bookId: 'book-123',
        chapterId: 'chapter-10',
      )).thenAnswer((_) async => Right(progress));

      const params = MarkChapterCompleteParams(
        userId: 'user-123',
        bookId: 'book-123',
        chapterId: 'chapter-10',
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedProgress) {
          expect(returnedProgress.isCompleted, true);
          expect(returnedProgress.completionPercentage, 100.0);
        },
      );
    });

    test('withNonExistentChapter_shouldReturnNotFoundFailure', () async {
      // Arrange
      when(mockBookRepository.markChapterComplete(
        userId: 'user-123',
        bookId: 'book-123',
        chapterId: 'nonexistent-chapter',
      )).thenAnswer((_) async => const Left(NotFoundFailure('Chapter not found')));

      const params = MarkChapterCompleteParams(
        userId: 'user-123',
        bookId: 'book-123',
        chapterId: 'nonexistent-chapter',
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<NotFoundFailure>()),
        (progress) => fail('Should not return progress'),
      );
    });

    test('withServerError_shouldReturnServerFailure', () async {
      // Arrange
      when(mockBookRepository.markChapterComplete(
        userId: 'user-123',
        bookId: 'book-123',
        chapterId: 'chapter-1',
      )).thenAnswer((_) async => const Left(ServerFailure('Database error')));

      const params = MarkChapterCompleteParams(
        userId: 'user-123',
        bookId: 'book-123',
        chapterId: 'chapter-1',
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (progress) => fail('Should not return progress'),
      );
    });

    test('params_shouldStoreAllFields', () {
      // Arrange & Act
      const params = MarkChapterCompleteParams(
        userId: 'test-user',
        bookId: 'test-book',
        chapterId: 'test-chapter',
      );

      // Assert
      expect(params.userId, 'test-user');
      expect(params.bookId, 'test-book');
      expect(params.chapterId, 'test-chapter');
    });
  });

  // ============================================
  // UpdateReadingProgressUseCase Tests
  // ============================================
  group('UpdateReadingProgressUseCase', () {
    late UpdateReadingProgressUseCase usecase;

    setUp(() {
      usecase = UpdateReadingProgressUseCase(mockBookRepository);
    });

    test('withValidProgress_shouldReturnUpdatedProgress', () async {
      // Arrange
      final progress = ReadingProgressFixtures.validProgress();
      when(mockBookRepository.updateReadingProgress(progress))
          .thenAnswer((_) async => Right(progress));

      final params = UpdateReadingProgressParams(progress: progress);

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedProgress) {
          expect(returnedProgress.id, progress.id);
          expect(returnedProgress.currentPage, progress.currentPage);
        },
      );
      verify(mockBookRepository.updateReadingProgress(progress)).called(1);
    });

    test('withUpdatedPage_shouldSaveNewPage', () async {
      // Arrange
      final originalProgress = ReadingProgressFixtures.validProgress();
      final updatedProgress = originalProgress.copyWith(currentPage: 10);

      when(mockBookRepository.updateReadingProgress(updatedProgress))
          .thenAnswer((_) async => Right(updatedProgress));

      final params = UpdateReadingProgressParams(progress: updatedProgress);

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedProgress) {
          expect(returnedProgress.currentPage, 10);
        },
      );
    });

    test('withUpdatedReadingTime_shouldAccumulateTime', () async {
      // Arrange
      final originalProgress = ReadingProgressFixtures.validProgress();
      final updatedProgress = originalProgress.copyWith(totalReadingTime: 1200);

      when(mockBookRepository.updateReadingProgress(updatedProgress))
          .thenAnswer((_) async => Right(updatedProgress));

      final params = UpdateReadingProgressParams(progress: updatedProgress);

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedProgress) {
          expect(returnedProgress.totalReadingTime, 1200);
        },
      );
    });

    test('withServerError_shouldReturnServerFailure', () async {
      // Arrange
      final progress = ReadingProgressFixtures.validProgress();
      when(mockBookRepository.updateReadingProgress(progress))
          .thenAnswer((_) async => const Left(ServerFailure('Save failed')));

      final params = UpdateReadingProgressParams(progress: progress);

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (progress) => fail('Should not return progress'),
      );
    });

    test('withNetworkError_shouldReturnNetworkFailure', () async {
      // Arrange
      final progress = ReadingProgressFixtures.validProgress();
      when(mockBookRepository.updateReadingProgress(progress))
          .thenAnswer((_) async => const Left(NetworkFailure()));

      final params = UpdateReadingProgressParams(progress: progress);

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (progress) => fail('Should not return progress'),
      );
    });

    test('params_shouldStoreProgress', () {
      // Arrange
      final progress = ReadingProgressFixtures.validProgress();

      // Act
      final params = UpdateReadingProgressParams(progress: progress);

      // Assert
      expect(params.progress, progress);
      expect(params.progress.id, 'progress-1');
    });
  });

  // ============================================
  // Edge Cases
  // ============================================
  group('edgeCases', () {
    test('getProgressWithUuidIds_shouldWork', () async {
      // Arrange
      final usecase = GetReadingProgressUseCase(mockBookRepository);
      const userId = '550e8400-e29b-41d4-a716-446655440000';
      const bookId = '550e8400-e29b-41d4-a716-446655440001';
      final progress = ReadingProgressFixtures.validProgress();

      when(mockBookRepository.getReadingProgress(
        userId: userId,
        bookId: bookId,
      )).thenAnswer((_) async => Right(progress));

      const params = GetReadingProgressParams(
        userId: userId,
        bookId: bookId,
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
    });

    test('markCompleteOnAlreadyCompletedChapter_shouldSucceed', () async {
      // Arrange - marking same chapter complete again should be idempotent
      final usecase = MarkChapterCompleteUseCase(mockBookRepository);
      final progress = ReadingProgressFixtures.validProgress();

      when(mockBookRepository.markChapterComplete(
        userId: 'user-123',
        bookId: 'book-123',
        chapterId: 'chapter-1', // already in completedChapterIds
      )).thenAnswer((_) async => Right(progress));

      const params = MarkChapterCompleteParams(
        userId: 'user-123',
        bookId: 'book-123',
        chapterId: 'chapter-1',
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
    });
  });

  // ============================================
  // Multiple Calls Tests
  // ============================================
  group('multipleCalls', () {
    test('getProgress_calledMultipleTimes_shouldCallRepositoryEachTime', () async {
      // Arrange
      final usecase = GetReadingProgressUseCase(mockBookRepository);
      final progress = ReadingProgressFixtures.validProgress();

      when(mockBookRepository.getReadingProgress(
        userId: 'user-123',
        bookId: 'book-123',
      )).thenAnswer((_) async => Right(progress));

      const params = GetReadingProgressParams(
        userId: 'user-123',
        bookId: 'book-123',
      );

      // Act
      await usecase(params);
      await usecase(params);
      await usecase(params);

      // Assert
      verify(mockBookRepository.getReadingProgress(
        userId: 'user-123',
        bookId: 'book-123',
      )).called(3);
    });

    test('readingFlow_getProgressThenMarkComplete_shouldWork', () async {
      // Arrange
      final getProgressUseCase = GetReadingProgressUseCase(mockBookRepository);
      final markCompleteUseCase = MarkChapterCompleteUseCase(mockBookRepository);

      final initialProgress = ReadingProgressFixtures.validProgress();
      final updatedProgress = ReadingProgress(
        id: 'progress-1',
        userId: 'user-123',
        bookId: 'book-123',
        completionPercentage: 66.6,
        completedChapterIds: const ['chapter-1', 'chapter-2'],
        startedAt: DateTime.parse('2024-01-01T00:00:00Z'),
        updatedAt: DateTime.now(),
      );

      when(mockBookRepository.getReadingProgress(
        userId: 'user-123',
        bookId: 'book-123',
      )).thenAnswer((_) async => Right(initialProgress));

      when(mockBookRepository.markChapterComplete(
        userId: 'user-123',
        bookId: 'book-123',
        chapterId: 'chapter-2',
      )).thenAnswer((_) async => Right(updatedProgress));

      // Act - simulate reading flow
      final getResult = await getProgressUseCase(
        const GetReadingProgressParams(userId: 'user-123', bookId: 'book-123'),
      );
      final markResult = await markCompleteUseCase(
        const MarkChapterCompleteParams(
          userId: 'user-123',
          bookId: 'book-123',
          chapterId: 'chapter-2',
        ),
      );

      // Assert
      expect(getResult.isRight(), true);
      expect(markResult.isRight(), true);

      markResult.fold(
        (failure) => fail('Should not fail'),
        (progress) {
          expect(progress.completedChapterIds.length, 2);
          expect(progress.completionPercentage, greaterThan(initialProgress.completionPercentage));
        },
      );
    });
  });
}
