import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/vocabulary.dart';
import '../entities/word_list.dart';

/// Repository interface for word list operations
abstract class WordListRepository {
  /// Get all word lists with optional filtering
  Future<Either<Failure, List<WordList>>> getAllWordLists({
    WordListCategory? category,
    bool? isSystem,
  });

  /// Get a single word list by ID
  Future<Either<Failure, WordList>> getWordListById(String id);

  /// Get words for a specific word list
  Future<Either<Failure, List<VocabularyWord>>> getWordsForList(String listId);

  /// Get user's progress for all word lists
  Future<Either<Failure, List<UserWordListProgress>>> getUserWordListProgress(
    String userId,
  );

  /// Get user's progress for a specific word list
  Future<Either<Failure, UserWordListProgress?>> getProgressForList({
    required String userId,
    required String listId,
  });

  /// Update or create progress for a word list
  Future<Either<Failure, UserWordListProgress>> updateWordListProgress(
    UserWordListProgress progress,
  );

  /// Complete a specific phase for a word list
  Future<Either<Failure, UserWordListProgress>> completePhase({
    required String userId,
    required String listId,
    required int phase,
    int? score,
    int? total,
  });

  /// Reset progress for a word list
  Future<Either<Failure, void>> resetProgress({
    required String userId,
    required String listId,
  });
}
