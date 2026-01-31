import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../../domain/entities/vocabulary.dart';
import '../../../domain/repositories/vocabulary_repository.dart';
import '../../datasources/local/mock_data.dart';

class MockVocabularyRepository implements VocabularyRepository {
  final List<VocabularyProgress> _progressList =
      List.from(MockData.vocabularyProgress);

  @override
  Future<Either<Failure, List<VocabularyWord>>> getAllWords({
    String? level,
    List<String>? categories,
    int page = 1,
    int pageSize = 50,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    var words = List<VocabularyWord>.from(MockData.vocabularyWords);

    if (level != null) {
      words = words.where((w) => w.level == level).toList();
    }
    if (categories != null && categories.isNotEmpty) {
      words = words.where((w) {
        return w.categories.any((c) => categories.contains(c));
      }).toList();
    }

    // Pagination
    final start = (page - 1) * pageSize;
    final end = start + pageSize;
    if (start >= words.length) return const Right([]);

    return Right(words.sublist(start, end.clamp(0, words.length)));
  }

  @override
  Future<Either<Failure, VocabularyWord>> getWordById(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final word = MockData.vocabularyWords.where((w) => w.id == id).firstOrNull;
    if (word == null) {
      return const Left(NotFoundFailure('Word not found'));
    }
    return Right(word);
  }

  @override
  Future<Either<Failure, List<VocabularyWord>>> searchWords(String query) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final lowerQuery = query.toLowerCase();
    final words = MockData.vocabularyWords.where((w) {
      return w.word.toLowerCase().contains(lowerQuery) ||
          w.meaningTR.toLowerCase().contains(lowerQuery) ||
          (w.meaningEN?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();

    return Right(words);
  }

  @override
  Future<Either<Failure, List<VocabularyProgress>>> getUserProgress(
    String userId,
  ) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final progress = _progressList.where((p) => p.userId == userId).toList();
    return Right(progress);
  }

  @override
  Future<Either<Failure, VocabularyProgress>> getWordProgress({
    required String userId,
    required String wordId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final progress = _progressList.where(
      (p) => p.userId == userId && p.wordId == wordId,
    ).firstOrNull;

    if (progress == null) {
      // Create new progress
      final newProgress = VocabularyProgress(
        id: 'vp-${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        wordId: wordId,
        status: VocabularyStatus.newWord,
        createdAt: DateTime.now(),
      );
      _progressList.add(newProgress);
      return Right(newProgress);
    }

    return Right(progress);
  }

  @override
  Future<Either<Failure, VocabularyProgress>> updateWordProgress(
    VocabularyProgress progress,
  ) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final index = _progressList.indexWhere((p) => p.id == progress.id);
    if (index != -1) {
      _progressList[index] = progress;
    } else {
      _progressList.add(progress);
    }

    return Right(progress);
  }

  @override
  Future<Either<Failure, List<VocabularyWord>>> getDueForReview(
    String userId,
  ) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final dueProgress = _progressList.where((p) {
      return p.userId == userId && p.isDueForReview;
    }).toList();

    final words = <VocabularyWord>[];
    for (final progress in dueProgress) {
      final word = MockData.vocabularyWords
          .where((w) => w.id == progress.wordId)
          .firstOrNull;
      if (word != null) words.add(word);
    }

    return Right(words);
  }

  @override
  Future<Either<Failure, List<VocabularyWord>>> getNewWords({
    required String userId,
    int limit = 10,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final learnedWordIds = _progressList
        .where((p) => p.userId == userId)
        .map((p) => p.wordId)
        .toSet();

    final newWords = MockData.vocabularyWords
        .where((w) => !learnedWordIds.contains(w.id))
        .take(limit)
        .toList();

    return Right(newWords);
  }

  @override
  Future<Either<Failure, Map<String, int>>> getVocabularyStats(
    String userId,
  ) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final userProgress = _progressList.where((p) => p.userId == userId).toList();

    return Right({
      'total': MockData.vocabularyWords.length,
      'new': userProgress.where((p) => p.status == VocabularyStatus.newWord).length,
      'learning': userProgress.where((p) => p.status == VocabularyStatus.learning).length,
      'reviewing': userProgress.where((p) => p.status == VocabularyStatus.reviewing).length,
      'mastered': userProgress.where((p) => p.status == VocabularyStatus.mastered).length,
      'dueToday': userProgress.where((p) => p.isDueForReview).length,
    });
  }

  @override
  Future<Either<Failure, VocabularyProgress>> addWordToVocabulary({
    required String userId,
    required String wordId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));

    // Check if already exists
    final existing = _progressList.where(
      (p) => p.userId == userId && p.wordId == wordId,
    ).firstOrNull;

    if (existing != null) {
      return Right(existing);
    }

    // Create new progress
    final now = DateTime.now();
    final progress = VocabularyProgress(
      id: 'mock-progress-${now.millisecondsSinceEpoch}',
      userId: userId,
      wordId: wordId,
      status: VocabularyStatus.learning,
      easeFactor: 2.5,
      intervalDays: 1,
      repetitions: 0,
      nextReviewAt: now.add(const Duration(days: 1)),
      lastReviewedAt: now,
      createdAt: now,
    );

    _progressList.add(progress);
    return Right(progress);
  }
}
