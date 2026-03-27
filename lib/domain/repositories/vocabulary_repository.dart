import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/daily_review_session.dart';
import '../entities/vocabulary.dart';

abstract class VocabularyRepository {
  Future<Either<Failure, List<VocabularyWord>>> getAllWords({
    String? level,
    List<String>? categories,
    int page = 1,
    int pageSize = 50,
  });

  Future<Either<Failure, VocabularyWord>> getWordById(String id);

  /// Fetch multiple words by IDs in a single query
  Future<Either<Failure, List<VocabularyWord>>> getWordsByIds(List<String> ids);

  Future<Either<Failure, List<VocabularyWord>>> searchWords(String query);

  Future<Either<Failure, List<VocabularyProgress>>> getUserProgress(
    String userId,
  );

  Future<Either<Failure, VocabularyProgress>> getWordProgress({
    required String userId,
    required String wordId,
  });

  /// Fetch progress for multiple words in a single query
  Future<Either<Failure, List<VocabularyProgress>>> getWordProgressBatch({
    required String userId,
    required List<String> wordIds,
  });

  Future<Either<Failure, VocabularyProgress>> updateWordProgress(
    VocabularyProgress progress,
  );

  Future<Either<Failure, List<VocabularyWord>>> getDueForReview(String userId);

  Future<Either<Failure, List<VocabularyWord>>> getNewWords({
    required String userId,
    int limit = 10,
  });

  Future<Either<Failure, Map<String, int>>> getVocabularyStats(String userId);

  /// Adds a word to user's vocabulary (creates initial progress)
  /// When [immediate] is true, next_review_at = now (appears in today's review)
  Future<Either<Failure, VocabularyProgress>> addWordToVocabulary({
    required String userId,
    required String wordId,
    bool immediate = false,
  });

  /// Get a word by exact word string (case-insensitive)
  /// Returns null if word not found in database
  Future<Either<Failure, VocabularyWord?>> getWordByWord(String word);

  /// Get ALL meanings for a word (multiple rows for words with different meanings)
  /// Returns empty list if word not found
  /// Includes joined book title for each meaning
  Future<Either<Failure, List<VocabularyWord>>> getWordsByWord(String word);

  // ============================================================
  // Daily Review Methods
  // ============================================================

  /// Get today's review session if exists
  Future<Either<Failure, DailyReviewSession?>> getTodayReviewSession(
    String userId,
  );

  /// Complete a daily review session with XP awards
  /// Returns session result with XP earned
  Future<Either<Failure, DailyReviewResult>> completeDailyReview({
    required String userId,
    required int wordsReviewed,
    required int correctCount,
    required int incorrectCount,
  });

  /// Add multiple words to vocabulary in batch (for book/list completion)
  /// Skips words that already exist in vocabulary_progress
  /// When [immediate] is true, next_review_at = now (appears in today's review)
  Future<Either<Failure, List<VocabularyProgress>>> addWordsToVocabularyBatch({
    required String userId,
    required List<String> wordIds,
    bool immediate = false,
  });

  /// Get count of words learned today (vocabulary_progress created today)
  Future<Either<Failure, int>> getWordsLearnedTodayCount(String userId);

  /// Count words learned today that belong to word lists only
  /// (excludes words learned from reader or other sources)
  Future<Either<Failure, int>> getWordsLearnedFromListsTodayCount(String userId);

  // ============================================================
  // Path Node Completion Methods
  // ============================================================

  /// Get all node completions for a user
  Future<Either<Failure, List<NodeCompletion>>> getNodeCompletions(
    String userId,
  );

  /// Mark a path node as completed (idempotent — ignores duplicates)
  Future<Either<Failure, void>> completeNode({
    required String userId,
    required String unitId,
    required String nodeType,
  });

  /// Save the daily review's position in the learning path
  Future<Either<Failure, void>> saveDailyReviewPosition({
    required String sessionId,
    required int pathPosition,
  });
}
