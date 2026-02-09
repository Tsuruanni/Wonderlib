import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/vocabulary.dart';
import '../entities/vocabulary_session.dart';
import '../entities/vocabulary_unit.dart';
import '../entities/word_list.dart';

/// Repository interface for word list operations
abstract class WordListRepository {
  /// Get all active vocabulary units ordered by sort_order
  Future<Either<Failure, List<VocabularyUnit>>> getVocabularyUnits();

  /// Get vocabulary units assigned to a user via curriculum assignments.
  /// Returns all active units if no assignments exist for the user's school.
  Future<Either<Failure, List<VocabularyUnit>>> getAssignedVocabularyUnits(
    String userId,
  );

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

  /// Complete a vocabulary session: persists result, awards XP, updates streak (calls RPC)
  Future<Either<Failure, VocabularySessionResult>> completeSession({
    required String userId,
    required String wordListId,
    required int totalQuestions,
    required int correctCount,
    required int incorrectCount,
    required double accuracy,
    required int maxCombo,
    required int xpEarned,
    required int durationSeconds,
    required int wordsStrong,
    required int wordsWeak,
    required int firstTryPerfectCount,
    required List<SessionWordResult> wordResults,
  });

  /// Get session history for a word list
  Future<Either<Failure, List<VocabularySessionResult>>> getSessionHistory({
    required String userId,
    required String wordListId,
  });

  /// Reset progress for a word list
  Future<Either<Failure, void>> resetProgress({
    required String userId,
    required String listId,
  });
}
