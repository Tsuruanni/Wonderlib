import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/book_repository.dart';
import '../../repositories/vocabulary_repository.dart';
import '../usecase.dart';

class CompleteInlineActivityParams {
  const CompleteInlineActivityParams({
    required this.userId,
    required this.activityId,
    required this.isCorrect,
    required this.xpEarned,
    required this.wordsLearned,
  });

  final String userId;
  final String activityId;
  final bool isCorrect;
  final int xpEarned;
  final List<String> wordsLearned;
}

class CompleteInlineActivityResult {
  const CompleteInlineActivityResult({
    required this.isNewCompletion,
    required this.wordsAdded,
  });

  final bool isNewCompletion;
  final int wordsAdded;
}

/// Orchestrates inline activity completion:
/// 1. Saves activity result to DB (dedup via UNIQUE constraint)
/// 2. Adds learned words to vocabulary if any
///
/// Presentation layer handles: local dedup, XP award, provider invalidation,
/// session counters, and onComplete callback.
class CompleteInlineActivityUseCase
    implements UseCase<CompleteInlineActivityResult, CompleteInlineActivityParams> {
  const CompleteInlineActivityUseCase(
    this._bookRepository,
    this._vocabularyRepository,
  );

  final BookRepository _bookRepository;
  final VocabularyRepository _vocabularyRepository;

  @override
  Future<Either<Failure, CompleteInlineActivityResult>> call(
    CompleteInlineActivityParams params,
  ) async {
    // 1. Save activity result to DB
    final saveResult = await _bookRepository.saveInlineActivityResult(
      userId: params.userId,
      activityId: params.activityId,
      isCorrect: params.isCorrect,
      xpEarned: params.xpEarned,
    );

    return saveResult.fold(
      (failure) => Left(failure),
      (isNewCompletion) async {
        int wordsAdded = 0;

        // 2. Add words to vocabulary if any
        if (params.wordsLearned.isNotEmpty) {
          final vocabResult = await _vocabularyRepository.addWordsToVocabularyBatch(
            userId: params.userId,
            wordIds: params.wordsLearned,
            immediate: !params.isCorrect,
          );

          wordsAdded = vocabResult.fold(
            (_) => 0,
            (progressList) => progressList.length,
          );
        }

        return Right(CompleteInlineActivityResult(
          isNewCompletion: isNewCompletion,
          wordsAdded: wordsAdded,
        ));
      },
    );
  }
}
