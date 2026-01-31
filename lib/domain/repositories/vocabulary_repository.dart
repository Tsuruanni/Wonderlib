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
}
