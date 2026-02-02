import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/vocabulary.dart';

abstract class VocabularyRepository {
  Future<Either<Failure, List<VocabularyWord>>> getAllWords({
    String? level,
    List<String>? categories,
    int page = 1,
    int pageSize = 50,
  });

  Future<Either<Failure, VocabularyWord>> getWordById(String id);

  Future<Either<Failure, List<VocabularyWord>>> searchWords(String query);

  Future<Either<Failure, List<VocabularyProgress>>> getUserProgress(
    String userId,
  );

  Future<Either<Failure, VocabularyProgress>> getWordProgress({
    required String userId,
    required String wordId,
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
  Future<Either<Failure, VocabularyProgress>> addWordToVocabulary({
    required String userId,
    required String wordId,
  });

  /// Get a word by exact word string (case-insensitive)
  /// Returns null if word not found in database
  Future<Either<Failure, VocabularyWord?>> getWordByWord(String word);

  /// Get ALL meanings for a word (multiple rows for words with different meanings)
  /// Returns empty list if word not found
  /// Includes joined book title for each meaning
  Future<Either<Failure, List<VocabularyWord>>> getWordsByWord(String word);
}
