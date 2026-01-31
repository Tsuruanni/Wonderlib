import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../../domain/entities/vocabulary.dart';
import '../../../domain/entities/word_list.dart';
import '../../../domain/repositories/word_list_repository.dart';
import '../../datasources/local/mock_data.dart';

class MockWordListRepository implements WordListRepository {
  final Map<String, UserWordListProgress> _progressMap = {};

  MockWordListRepository() {
    // Initialize with mock data
    for (final p in MockData.userWordListProgress) {
      _progressMap[p.wordListId] = p;
    }
  }

  @override
  Future<Either<Failure, List<WordList>>> getAllWordLists({
    WordListCategory? category,
    bool? isSystem,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));

    var lists = List<WordList>.from(MockData.wordLists);

    if (category != null) {
      lists = lists.where((l) => l.category == category).toList();
    }
    if (isSystem != null) {
      lists = lists.where((l) => l.isSystem == isSystem).toList();
    }

    return Right(lists);
  }

  @override
  Future<Either<Failure, WordList>> getWordListById(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));

    final list = MockData.wordLists.where((l) => l.id == id).firstOrNull;
    if (list == null) {
      return const Left(NotFoundFailure('Word list not found'));
    }
    return Right(list);
  }

  @override
  Future<Either<Failure, List<VocabularyWord>>> getWordsForList(
    String listId,
  ) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final words = MockData.getWordsForList(listId);
    return Right(words);
  }

  @override
  Future<Either<Failure, List<UserWordListProgress>>> getUserWordListProgress(
    String userId,
  ) async {
    await Future.delayed(const Duration(milliseconds: 100));

    final progress = _progressMap.values
        .where((p) => p.userId == userId)
        .toList();
    return Right(progress);
  }

  @override
  Future<Either<Failure, UserWordListProgress?>> getProgressForList({
    required String userId,
    required String listId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));

    final progress = _progressMap[listId];
    if (progress != null && progress.userId == userId) {
      return Right(progress);
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, UserWordListProgress>> updateWordListProgress(
    UserWordListProgress progress,
  ) async {
    await Future.delayed(const Duration(milliseconds: 100));

    _progressMap[progress.wordListId] = progress;
    return Right(progress);
  }

  @override
  Future<Either<Failure, UserWordListProgress>> completePhase({
    required String userId,
    required String listId,
    required int phase,
    int? score,
    int? total,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));

    final existing = _progressMap[listId];

    UserWordListProgress updated;
    if (existing != null) {
      updated = UserWordListProgress(
        id: existing.id,
        userId: userId,
        wordListId: listId,
        phase1Complete: phase == 1 ? true : existing.phase1Complete,
        phase2Complete: phase == 2 ? true : existing.phase2Complete,
        phase3Complete: phase == 3 ? true : existing.phase3Complete,
        phase4Complete: phase == 4 ? true : existing.phase4Complete,
        phase4Score: phase == 4 ? score : existing.phase4Score,
        phase4Total: phase == 4 ? total : existing.phase4Total,
        startedAt: existing.startedAt ?? DateTime.now(),
        completedAt: (phase == 4 && existing.phase1Complete && existing.phase2Complete && existing.phase3Complete)
            ? DateTime.now()
            : existing.completedAt,
        updatedAt: DateTime.now(),
      );
    } else {
      updated = UserWordListProgress(
        id: 'progress-$listId',
        userId: userId,
        wordListId: listId,
        phase1Complete: phase == 1,
        phase2Complete: phase == 2,
        phase3Complete: phase == 3,
        phase4Complete: phase == 4,
        phase4Score: phase == 4 ? score : null,
        phase4Total: phase == 4 ? total : null,
        startedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    _progressMap[listId] = updated;
    return Right(updated);
  }

  @override
  Future<Either<Failure, void>> resetProgress({
    required String userId,
    required String listId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));

    _progressMap.remove(listId);
    return const Right(null);
  }
}
