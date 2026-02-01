import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/activity/get_activities_by_chapter_usecase.dart';
import '../../domain/usecases/activity/get_activity_by_id_usecase.dart';
import '../../domain/usecases/activity/get_activity_stats_usecase.dart';
import '../../domain/usecases/activity/get_best_result_usecase.dart';
import '../../domain/usecases/activity/get_completed_inline_activities_usecase.dart';
import '../../domain/usecases/activity/get_inline_activities_usecase.dart';
import '../../domain/usecases/activity/get_user_activity_results_usecase.dart';
import '../../domain/usecases/activity/save_inline_activity_result_usecase.dart';
import '../../domain/usecases/activity/submit_activity_result_usecase.dart';
import '../../domain/usecases/assignment/create_assignment_usecase.dart';
import '../../domain/usecases/auth/get_current_user_usecase.dart';
import '../../domain/usecases/auth/sign_in_with_email_usecase.dart';
import '../../domain/usecases/auth/sign_in_with_student_number_usecase.dart';
import '../../domain/usecases/auth/sign_out_usecase.dart';
import '../../domain/usecases/book/get_book_by_id_usecase.dart';
import '../../domain/usecases/book/get_books_usecase.dart';
import '../../domain/usecases/book/get_chapter_by_id_usecase.dart';
import '../../domain/usecases/book/get_chapters_usecase.dart';
import '../../domain/usecases/book/get_continue_reading_usecase.dart';
import '../../domain/usecases/book/get_recommended_books_usecase.dart';
import '../../domain/usecases/book/search_books_usecase.dart';
import '../../domain/usecases/reading/get_reading_progress_usecase.dart';
import '../../domain/usecases/reading/get_user_reading_history_usecase.dart';
import '../../domain/usecases/reading/mark_chapter_complete_usecase.dart';
import '../../domain/usecases/reading/save_reading_progress_usecase.dart';
import '../../domain/usecases/reading/update_current_chapter_usecase.dart';
import '../../domain/usecases/reading/update_reading_progress_usecase.dart';
import '../../domain/usecases/teacher/change_student_class_usecase.dart';
import '../../domain/usecases/teacher/reset_student_password_usecase.dart';
import 'repository_providers.dart';

// ============================================
// AUTH USE CASES
// ============================================

final signInWithEmailUseCaseProvider = Provider((ref) {
  return SignInWithEmailUseCase(ref.watch(authRepositoryProvider));
});

final signInWithStudentNumberUseCaseProvider = Provider((ref) {
  return SignInWithStudentNumberUseCase(ref.watch(authRepositoryProvider));
});

final signOutUseCaseProvider = Provider((ref) {
  return SignOutUseCase(ref.watch(authRepositoryProvider));
});

final getCurrentUserUseCaseProvider = Provider((ref) {
  return GetCurrentUserUseCase(ref.watch(authRepositoryProvider));
});

// ============================================
// BOOK USE CASES
// ============================================

final getBooksUseCaseProvider = Provider((ref) {
  return GetBooksUseCase(ref.watch(bookRepositoryProvider));
});

final getBookByIdUseCaseProvider = Provider((ref) {
  return GetBookByIdUseCase(ref.watch(bookRepositoryProvider));
});

final searchBooksUseCaseProvider = Provider((ref) {
  return SearchBooksUseCase(ref.watch(bookRepositoryProvider));
});

final getChaptersUseCaseProvider = Provider((ref) {
  return GetChaptersUseCase(ref.watch(bookRepositoryProvider));
});

final getChapterByIdUseCaseProvider = Provider((ref) {
  return GetChapterByIdUseCase(ref.watch(bookRepositoryProvider));
});

final getContinueReadingUseCaseProvider = Provider((ref) {
  return GetContinueReadingUseCase(ref.watch(bookRepositoryProvider));
});

final getRecommendedBooksUseCaseProvider = Provider((ref) {
  return GetRecommendedBooksUseCase(ref.watch(bookRepositoryProvider));
});

// ============================================
// TEACHER USE CASES
// ============================================

final resetStudentPasswordUseCaseProvider = Provider((ref) {
  return ResetStudentPasswordUseCase(ref.watch(teacherRepositoryProvider));
});

final changeStudentClassUseCaseProvider = Provider((ref) {
  return ChangeStudentClassUseCase(ref.watch(teacherRepositoryProvider));
});

// ============================================
// ASSIGNMENT USE CASES
// ============================================

final createAssignmentUseCaseProvider = Provider((ref) {
  return CreateAssignmentUseCase(ref.watch(teacherRepositoryProvider));
});

// ============================================
// READING USE CASES
// ============================================

final saveReadingProgressUseCaseProvider = Provider((ref) {
  return SaveReadingProgressUseCase(ref.watch(bookRepositoryProvider));
});

final getReadingProgressUseCaseProvider = Provider((ref) {
  return GetReadingProgressUseCase(ref.watch(bookRepositoryProvider));
});

final markChapterCompleteUseCaseProvider = Provider((ref) {
  return MarkChapterCompleteUseCase(ref.watch(bookRepositoryProvider));
});

final updateCurrentChapterUseCaseProvider = Provider((ref) {
  return UpdateCurrentChapterUseCase(ref.watch(bookRepositoryProvider));
});

final getUserReadingHistoryUseCaseProvider = Provider((ref) {
  return GetUserReadingHistoryUseCase(ref.watch(bookRepositoryProvider));
});

final updateReadingProgressUseCaseProvider = Provider((ref) {
  return UpdateReadingProgressUseCase(ref.watch(bookRepositoryProvider));
});

// ============================================
// ACTIVITY USE CASES
// ============================================

final getActivitiesByChapterUseCaseProvider = Provider((ref) {
  return GetActivitiesByChapterUseCase(ref.watch(activityRepositoryProvider));
});

final getActivityByIdUseCaseProvider = Provider((ref) {
  return GetActivityByIdUseCase(ref.watch(activityRepositoryProvider));
});

final submitActivityResultUseCaseProvider = Provider((ref) {
  return SubmitActivityResultUseCase(ref.watch(activityRepositoryProvider));
});

final getUserActivityResultsUseCaseProvider = Provider((ref) {
  return GetUserActivityResultsUseCase(ref.watch(activityRepositoryProvider));
});

final getBestResultUseCaseProvider = Provider((ref) {
  return GetBestResultUseCase(ref.watch(activityRepositoryProvider));
});

final getActivityStatsUseCaseProvider = Provider((ref) {
  return GetActivityStatsUseCase(ref.watch(activityRepositoryProvider));
});

// ============================================
// INLINE ACTIVITY USE CASES (via BookRepository)
// ============================================

final getInlineActivitiesUseCaseProvider = Provider((ref) {
  return GetInlineActivitiesUseCase(ref.watch(bookRepositoryProvider));
});

final saveInlineActivityResultUseCaseProvider = Provider((ref) {
  return SaveInlineActivityResultUseCase(ref.watch(bookRepositoryProvider));
});

final getCompletedInlineActivitiesUseCaseProvider = Provider((ref) {
  return GetCompletedInlineActivitiesUseCase(ref.watch(bookRepositoryProvider));
});
