import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/vocabulary_session.dart';
import '../../repositories/word_list_repository.dart';
import '../usecase.dart';

class CompleteSessionParams {
  const CompleteSessionParams({
    required this.userId,
    required this.wordListId,
    required this.totalQuestions,
    required this.correctCount,
    required this.incorrectCount,
    required this.accuracy,
    required this.maxCombo,
    required this.xpEarned,
    required this.durationSeconds,
    required this.wordsStrong,
    required this.wordsWeak,
    required this.firstTryPerfectCount,
    required this.wordResults,
  });

  final String userId;
  final String wordListId;
  final int totalQuestions;
  final int correctCount;
  final int incorrectCount;
  final double accuracy;
  final int maxCombo;
  final int xpEarned;
  final int durationSeconds;
  final int wordsStrong;
  final int wordsWeak;
  final int firstTryPerfectCount;
  final List<SessionWordResult> wordResults;
}

class CompleteSessionUseCase
    implements UseCase<VocabularySessionResult, CompleteSessionParams> {
  const CompleteSessionUseCase(this._repository);
  final WordListRepository _repository;

  @override
  Future<Either<Failure, VocabularySessionResult>> call(
    CompleteSessionParams params,
  ) {
    return _repository.completeSession(
      userId: params.userId,
      wordListId: params.wordListId,
      totalQuestions: params.totalQuestions,
      correctCount: params.correctCount,
      incorrectCount: params.incorrectCount,
      accuracy: params.accuracy,
      maxCombo: params.maxCombo,
      xpEarned: params.xpEarned,
      durationSeconds: params.durationSeconds,
      wordsStrong: params.wordsStrong,
      wordsWeak: params.wordsWeak,
      firstTryPerfectCount: params.firstTryPerfectCount,
      wordResults: params.wordResults,
    );
  }
}
