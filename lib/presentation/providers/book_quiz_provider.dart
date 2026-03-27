import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/book_quiz.dart';
import '../../domain/entities/system_settings.dart';
import '../../domain/usecases/book_quiz/book_has_quiz_usecase.dart';
import '../../domain/usecases/book_quiz/get_best_quiz_result_usecase.dart';
import '../../domain/usecases/book_quiz/get_quiz_for_book_usecase.dart';
import '../../domain/usecases/reading/handle_book_completion_usecase.dart';
import '../../domain/usecases/book_quiz/get_student_quiz_results_usecase.dart';
import '../../domain/usecases/book_quiz/submit_quiz_result_usecase.dart';
import 'auth_provider.dart';
import 'book_provider.dart';
import 'system_settings_provider.dart';
import 'usecase_providers.dart';
import 'user_provider.dart';

/// Whether a book has a published quiz
final bookHasQuizProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, bookId) async {
  final useCase = ref.watch(bookHasQuizUseCaseProvider);
  final result = await useCase(BookHasQuizParams(bookId: bookId));
  return result.fold((failure) => throw Exception(failure.message), (hasQuiz) => hasQuiz);
});

/// The quiz for a book (with all questions)
final bookQuizProvider =
    FutureProvider.autoDispose.family<BookQuiz?, String>((ref, bookId) async {
  final useCase = ref.watch(getQuizForBookUseCaseProvider);
  final result = await useCase(GetQuizForBookParams(bookId: bookId));
  return result.fold((failure) => throw Exception(failure.message), (quiz) => quiz);
});

/// User's best quiz result for a book
final bestQuizResultProvider =
    FutureProvider.autoDispose.family<BookQuizResult?, String>((ref, bookId) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  final useCase = ref.watch(getBestQuizResultUseCaseProvider);
  final result = await useCase(
    GetBestQuizResultParams(userId: userId, bookId: bookId),
  );
  return result.fold((failure) => throw Exception(failure.message), (result) => result);
});

/// Whether a book is in "quiz ready" state (all chapters read, quiz exists, not passed)
final isQuizReadyProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, bookId) async {
  final progress = await ref.watch(readingProgressProvider(bookId).future);
  if (progress == null) return false;

  // All chapters read but not completed (quiz is blocking)
  if (progress.completionPercentage < 100) return false;
  if (progress.isCompleted) return false; // Already completed
  if (progress.quizPassed) return false; // Already passed

  final hasQuiz = await ref.watch(bookHasQuizProvider(bookId).future);
  return hasQuiz;
});

/// Student quiz results across all books (for teacher reporting)
final studentQuizResultsProvider =
    FutureProvider.autoDispose.family<List<StudentQuizProgress>, String>(
        (ref, studentId) async {
  final useCase = ref.watch(getStudentQuizResultsUseCaseProvider);
  final result = await useCase(
    GetStudentQuizResultsParams(studentId: studentId),
  );
  return result.fold((failure) => throw Exception(failure.message), (results) => results);
});

/// Quiz submission controller
class BookQuizController extends StateNotifier<AsyncValue<BookQuizResult?>> {
  BookQuizController(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  Future<BookQuizResult?> submitQuiz({
    required String quizId,
    required String bookId,
    required double score,
    required double maxScore,
    required Map<String, dynamic> answers,
    required double passingScore,
    int? timeSpent,
  }) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return null;

    state = const AsyncValue.loading();

    final percentage = maxScore > 0 ? (score / maxScore) * 100 : 0.0;

    final result = BookQuizResult(
      id: '',
      userId: userId,
      quizId: quizId,
      bookId: bookId,
      score: score,
      maxScore: maxScore,
      percentage: percentage,
      isPassing: percentage >= passingScore,
      answers: answers,
      timeSpent: timeSpent,
      attemptNumber: 1, // Calculated by repository
      completedAt: DateTime.now(),
    );

    final useCase = _ref.read(submitQuizResultUseCaseProvider);
    final either = await useCase(SubmitQuizResultParams(result: result));

    final savedResult = either.fold(
      (failure) {
        debugPrint('BookQuizController: submit failed: ${failure.message}');
        if (mounted) {
          state = AsyncValue.error(failure, StackTrace.current);
        }
        return null;
      },
      (savedResult) {
        if (mounted) {
          state = AsyncValue.data(savedResult);
        }

        // Invalidate related providers
        _ref.invalidate(bestQuizResultProvider(bookId));
        _ref.invalidate(readingProgressProvider(bookId));
        _ref.invalidate(completedBookIdsProvider);
        _ref.invalidate(continueReadingProvider);
        _ref.invalidate(isQuizReadyProvider(bookId));

        return savedResult;
      },
    );

    // Award XP for passing quiz (addXP also triggers badge check)
    if (savedResult != null && savedResult.isPassing) {
      final settings = _ref.read(systemSettingsProvider).valueOrNull ?? SystemSettings.defaults();
      await _ref.read(userControllerProvider.notifier).addXP(
        settings.xpQuizPass,
        source: 'quiz_pass',
        sourceId: quizId,
      );

      // Check book completion (quiz just passed)
      final completionUseCase = _ref.read(handleBookCompletionUseCaseProvider);
      await completionUseCase(HandleBookCompletionParams(
        userId: userId,
        bookId: bookId,
        quizJustPassed: true,
      ));
    }

    return savedResult;
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}

final bookQuizControllerProvider = StateNotifierProvider.autoDispose<
    BookQuizController, AsyncValue<BookQuizResult?>>((ref) {
  return BookQuizController(ref);
});
