import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../../domain/entities/activity.dart';
import '../../../domain/entities/book.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../../domain/repositories/book_repository.dart';
import '../../datasources/local/mock_data.dart';

class MockBookRepository implements BookRepository {
  final List<ReadingProgress> _progressList = List.from(MockData.readingProgress);

  @override
  Future<Either<Failure, List<Book>>> getBooks({
    String? level,
    String? genre,
    String? ageGroup,
    int page = 1,
    int pageSize = 20,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    var books = MockData.books.where((b) => b.status == BookStatus.published).toList();

    if (level != null) {
      books = books.where((b) => b.level == level).toList();
    }
    if (genre != null) {
      books = books.where((b) => b.genre == genre).toList();
    }
    if (ageGroup != null) {
      books = books.where((b) => b.ageGroup == ageGroup).toList();
    }

    // Pagination
    final start = (page - 1) * pageSize;
    final end = start + pageSize;
    if (start >= books.length) return const Right([]);

    return Right(books.sublist(start, end.clamp(0, books.length)));
  }

  @override
  Future<Either<Failure, Book>> getBookById(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final book = MockData.books.where((b) => b.id == id).firstOrNull;
    if (book == null) {
      return const Left(NotFoundFailure('Book not found'));
    }
    return Right(book);
  }

  @override
  Future<Either<Failure, List<Book>>> searchBooks(String query) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final lowerQuery = query.toLowerCase();
    final books = MockData.books.where((b) {
      return b.title.toLowerCase().contains(lowerQuery) ||
          (b.description?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();

    return Right(books);
  }

  @override
  Future<Either<Failure, List<Book>>> getRecommendedBooks(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300));

    // Simple recommendation: return books user hasn't read
    final readBookIds = _progressList
        .where((p) => p.userId == userId)
        .map((p) => p.bookId)
        .toSet();

    final recommended = MockData.books
        .where((b) => !readBookIds.contains(b.id) && b.status == BookStatus.published)
        .take(5)
        .toList();

    return Right(recommended);
  }

  @override
  Future<Either<Failure, List<Chapter>>> getChapters(String bookId) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final chapters = MockData.chapters
        .where((c) => c.bookId == bookId)
        .toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    return Right(chapters);
  }

  @override
  Future<Either<Failure, Chapter>> getChapterById(String chapterId) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final chapter = MockData.chapters.where((c) => c.id == chapterId).firstOrNull;
    if (chapter == null) {
      return const Left(NotFoundFailure('Chapter not found'));
    }
    return Right(chapter);
  }

  @override
  Future<Either<Failure, ReadingProgress>> getReadingProgress({
    required String userId,
    required String bookId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final progress = _progressList.where(
      (p) => p.userId == userId && p.bookId == bookId,
    ).firstOrNull;

    if (progress == null) {
      // Create new progress
      final newProgress = ReadingProgress(
        id: 'progress-${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        bookId: bookId,
        currentPage: 1,
        startedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _progressList.add(newProgress);
      return Right(newProgress);
    }

    return Right(progress);
  }

  @override
  Future<Either<Failure, ReadingProgress>> updateReadingProgress(
    ReadingProgress progress,
  ) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final index = _progressList.indexWhere((p) => p.id == progress.id);
    if (index != -1) {
      _progressList[index] = progress.copyWith(updatedAt: DateTime.now());
    } else {
      _progressList.add(progress);
    }

    return Right(progress);
  }

  @override
  Future<Either<Failure, List<ReadingProgress>>> getUserReadingHistory(
    String userId,
  ) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final history = _progressList.where((p) => p.userId == userId).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Right(history);
  }

  @override
  Future<Either<Failure, List<Book>>> getContinueReading(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final inProgress = _progressList
        .where((p) => p.userId == userId && !p.isCompleted)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final books = <Book>[];
    for (final progress in inProgress) {
      final book = MockData.books.where((b) => b.id == progress.bookId).firstOrNull;
      if (book != null) books.add(book);
    }

    return Right(books);
  }

  @override
  Future<Either<Failure, ReadingProgress>> markChapterComplete({
    required String userId,
    required String bookId,
    required String chapterId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));

    // Find existing progress or create new
    var progress = _progressList
        .where((p) => p.userId == userId && p.bookId == bookId)
        .firstOrNull;

    if (progress == null) {
      // Create new progress
      progress = ReadingProgress(
        id: 'progress-${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        bookId: bookId,
        chapterId: chapterId,
        completedChapterIds: [chapterId],
        startedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _progressList.add(progress);
    } else {
      // Update existing - add chapter to completed list if not already there
      final completedIds = List<String>.from(progress.completedChapterIds);
      if (!completedIds.contains(chapterId)) {
        completedIds.add(chapterId);
      }

      final index = _progressList.indexWhere((p) => p.id == progress!.id);
      progress = progress.copyWith(
        chapterId: chapterId,
        completedChapterIds: completedIds,
        updatedAt: DateTime.now(),
      );

      if (index != -1) {
        _progressList[index] = progress;
      }
    }

    return Right(progress);
  }

  @override
  Future<Either<Failure, List<InlineActivity>>> getInlineActivities(
    String chapterId,
  ) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return Right(MockData.getInlineActivities(chapterId));
  }

  // Mock storage for inline activity results
  final Map<String, bool> _inlineActivityResults = {};

  @override
  Future<Either<Failure, bool>> saveInlineActivityResult({
    required String userId,
    required String activityId,
    required bool isCorrect,
    required int xpEarned,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final key = '$userId:$activityId';
    if (_inlineActivityResults.containsKey(key)) {
      return const Right(false); // Already exists - no XP
    }
    _inlineActivityResults[key] = isCorrect;
    return const Right(true); // New completion - award XP
  }

  @override
  Future<Either<Failure, List<String>>> getCompletedInlineActivities({
    required String userId,
    required String chapterId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final activities = MockData.getInlineActivities(chapterId);
    final completedIds = activities
        .where((a) => _inlineActivityResults.containsKey('$userId:${a.id}'))
        .map((a) => a.id)
        .toList();
    return Right(completedIds);
  }

  @override
  Future<Either<Failure, void>> updateCurrentChapter({
    required String userId,
    required String bookId,
    required String chapterId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    // Update the progress entry with current chapter
    final index = _progressList.indexWhere(
      (p) => p.userId == userId && p.bookId == bookId,
    );
    if (index != -1) {
      _progressList[index] = _progressList[index].copyWith(chapterId: chapterId);
    }
    return const Right(null);
  }
}
