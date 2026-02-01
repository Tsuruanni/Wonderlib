import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../../domain/usecases/book/search_books_usecase.dart';
import '../../domain/usecases/reading/get_reading_progress_usecase.dart';
import '../../domain/usecases/reading/get_user_reading_history_usecase.dart';
import '../../domain/usecases/reading/mark_chapter_complete_usecase.dart';
import '../../domain/usecases/reading/save_reading_progress_usecase.dart';
import '../../domain/usecases/reading/update_current_chapter_usecase.dart';
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
