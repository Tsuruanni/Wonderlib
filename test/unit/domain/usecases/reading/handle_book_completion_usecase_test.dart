import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:owlio/domain/entities/chapter.dart';
import 'package:owlio/domain/entities/reading_progress.dart';
import 'package:owlio/domain/usecases/reading/handle_book_completion_usecase.dart';

import '../../../../mocks/mock_repositories.mocks.dart';

void main() {
  late MockBookRepository mockBookRepo;
  late MockBookQuizRepository mockQuizRepo;
  late HandleBookCompletionUseCase useCase;

  final now = DateTime(2026, 3, 27);

  ReadingProgress _makeProgress({
    bool isCompleted = false,
    List<String> completedChapterIds = const [],
    bool quizPassed = false,
    DateTime? completedAt,
  }) {
    return ReadingProgress(
      id: 'progress-1',
      userId: 'user-1',
      bookId: 'book-1',
      currentPage: 1,
      isCompleted: isCompleted,
      completionPercentage: 0,
      totalReadingTime: 0,
      completedChapterIds: completedChapterIds,
      quizPassed: quizPassed,
      startedAt: now,
      completedAt: completedAt,
      updatedAt: now,
    );
  }

  List<Chapter> _makeChapters(int count) {
    return List.generate(
      count,
      (i) => Chapter(
        id: 'ch-${i + 1}',
        bookId: 'book-1',
        title: 'Chapter ${i + 1}',
        orderIndex: i,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  setUp(() {
    mockBookRepo = MockBookRepository();
    mockQuizRepo = MockBookQuizRepository();
    useCase = HandleBookCompletionUseCase(mockBookRepo, mockQuizRepo);
  });

  group('HandleBookCompletionUseCase', () {
    test('all chapters done, no quiz -> should complete', () async {
      // Arrange
      final progress = _makeProgress(
        completedChapterIds: ['ch-1', 'ch-2', 'ch-3'],
      );
      when(mockBookRepo.getReadingProgress(userId: 'user-1', bookId: 'book-1'))
          .thenAnswer((_) async => Right(progress));
      when(mockBookRepo.getChapters('book-1'))
          .thenAnswer((_) async => Right(_makeChapters(3)));
      when(mockQuizRepo.bookHasQuiz('book-1'))
          .thenAnswer((_) async => const Right(false));
      when(mockBookRepo.updateReadingProgress(any))
          .thenAnswer((_) async => Right(progress.copyWith(
                isCompleted: true,
                completedAt: now,
              )));

      // Act
      final result = await useCase(const HandleBookCompletionParams(
        userId: 'user-1',
        bookId: 'book-1',
      ));

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should not fail'),
        (r) {
          expect(r.justCompleted, true);
          expect(r.hasQuiz, false);
          expect(r.progress.isCompleted, true);
        },
      );
      verify(mockBookRepo.updateReadingProgress(any)).called(1);
    });

    test('all chapters done, quiz not passed -> should NOT complete', () async {
      // Arrange
      final progress = _makeProgress(
        completedChapterIds: ['ch-1', 'ch-2', 'ch-3'],
        quizPassed: false,
      );
      when(mockBookRepo.getReadingProgress(userId: 'user-1', bookId: 'book-1'))
          .thenAnswer((_) async => Right(progress));
      when(mockBookRepo.getChapters('book-1'))
          .thenAnswer((_) async => Right(_makeChapters(3)));
      when(mockQuizRepo.bookHasQuiz('book-1'))
          .thenAnswer((_) async => const Right(true));

      // Act
      final result = await useCase(const HandleBookCompletionParams(
        userId: 'user-1',
        bookId: 'book-1',
      ));

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should not fail'),
        (r) {
          expect(r.justCompleted, false);
          expect(r.hasQuiz, true);
        },
      );
      verifyNever(mockBookRepo.updateReadingProgress(any));
    });

    test('all chapters done, quizJustPassed=true -> should complete', () async {
      // Arrange
      final progress = _makeProgress(
        completedChapterIds: ['ch-1', 'ch-2', 'ch-3'],
        quizPassed: false,
      );
      when(mockBookRepo.getReadingProgress(userId: 'user-1', bookId: 'book-1'))
          .thenAnswer((_) async => Right(progress));
      when(mockBookRepo.getChapters('book-1'))
          .thenAnswer((_) async => Right(_makeChapters(3)));
      when(mockQuizRepo.bookHasQuiz('book-1'))
          .thenAnswer((_) async => const Right(true));
      when(mockBookRepo.updateReadingProgress(any))
          .thenAnswer((_) async => Right(progress.copyWith(
                isCompleted: true,
                quizPassed: true,
                completedAt: now,
              )));

      // Act
      final result = await useCase(const HandleBookCompletionParams(
        userId: 'user-1',
        bookId: 'book-1',
        quizJustPassed: true,
      ));

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should not fail'),
        (r) {
          expect(r.justCompleted, true);
          expect(r.hasQuiz, true);
          expect(r.progress.isCompleted, true);
          expect(r.progress.quizPassed, true);
        },
      );
      verify(mockBookRepo.updateReadingProgress(any)).called(1);
    });

    test('not all chapters done -> should NOT complete', () async {
      // Arrange: only 2 of 3 chapters done
      final progress = _makeProgress(
        completedChapterIds: ['ch-1', 'ch-2'],
      );
      when(mockBookRepo.getReadingProgress(userId: 'user-1', bookId: 'book-1'))
          .thenAnswer((_) async => Right(progress));
      when(mockBookRepo.getChapters('book-1'))
          .thenAnswer((_) async => Right(_makeChapters(3)));
      when(mockQuizRepo.bookHasQuiz('book-1'))
          .thenAnswer((_) async => const Right(false));

      // Act
      final result = await useCase(const HandleBookCompletionParams(
        userId: 'user-1',
        bookId: 'book-1',
      ));

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should not fail'),
        (r) {
          expect(r.justCompleted, false);
        },
      );
      verifyNever(mockBookRepo.updateReadingProgress(any));
    });

    test('already completed -> should return without action', () async {
      // Arrange
      final progress = _makeProgress(
        isCompleted: true,
        completedChapterIds: ['ch-1', 'ch-2', 'ch-3'],
        completedAt: now,
      );
      when(mockBookRepo.getReadingProgress(userId: 'user-1', bookId: 'book-1'))
          .thenAnswer((_) async => Right(progress));
      when(mockQuizRepo.bookHasQuiz('book-1'))
          .thenAnswer((_) async => const Right(false));

      // Act
      final result = await useCase(const HandleBookCompletionParams(
        userId: 'user-1',
        bookId: 'book-1',
      ));

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should not fail'),
        (r) {
          expect(r.justCompleted, false);
        },
      );
      // Should NOT call getChapters or updateReadingProgress
      verifyNever(mockBookRepo.getChapters(any));
      verifyNever(mockBookRepo.updateReadingProgress(any));
    });
  });
}
