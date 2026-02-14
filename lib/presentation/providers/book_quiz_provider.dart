import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/book_quiz.dart';
import '../../domain/usecases/book_quiz/book_has_quiz_usecase.dart';
import '../../domain/usecases/book_quiz/get_best_quiz_result_usecase.dart';
import '../../domain/usecases/book_quiz/get_quiz_for_book_usecase.dart';
import '../../domain/usecases/book_quiz/get_student_quiz_results_usecase.dart';
import '../../domain/usecases/book_quiz/submit_quiz_result_usecase.dart';
import 'auth_provider.dart';
import 'book_provider.dart';
import 'usecase_providers.dart';

/// Whether a book has a published quiz
final bookHasQuizProvider =
    FutureProvider.family<bool, String>((ref, bookId) async {
  final useCase = ref.watch(bookHasQuizUseCaseProvider);
  final result = await useCase(BookHasQuizParams(bookId: bookId));
  return result.fold((_) => false, (hasQuiz) => hasQuiz);
});

/// The quiz for a book (with all questions)
final bookQuizProvider =
    FutureProvider.family<BookQuiz?, String>((ref, bookId) async {
  final useCase = ref.watch(getQuizForBookUseCaseProvider);
  final result = await useCase(GetQuizForBookParams(bookId: bookId));
  return result.fold((_) => null, (quiz) => quiz);
});

/// User's best quiz result for a book
final bestQuizResultProvider =
    FutureProvider.family<BookQuizResult?, String>((ref, bookId) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  final useCase = ref.watch(getBestQuizResultUseCaseProvider);
  final result = await useCase(
    GetBestQuizResultParams(userId: userId, bookId: bookId),
  );
  return result.fold((_) => null, (result) => result);
});

/// Whether a book is in "quiz ready" state (all chapters read, quiz exists, not passed)
final isQuizReadyProvider =
    FutureProvider.family<bool, String>((ref, bookId) async {
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
    FutureProvider.family<List<StudentQuizProgress>, String>(
        (ref, studentId) async {
  final useCase = ref.watch(getStudentQuizResultsUseCaseProvider);
  final result = await useCase(
    GetStudentQuizResultsParams(studentId: studentId),
  );
  return result.fold((_) => [], (results) => results);
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

    return either.fold(
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
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}

final bookQuizControllerProvider = StateNotifierProvider.autoDispose<
    BookQuizController, AsyncValue<BookQuizResult?>>((ref) {
  return BookQuizController(ref);
});
