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
import '../../domain/usecases/assignment/delete_assignment_usecase.dart';
import '../../domain/usecases/assignment/get_assignment_detail_usecase.dart';
import '../../domain/usecases/assignment/get_assignment_students_usecase.dart';
import '../../domain/usecases/assignment/get_assignments_usecase.dart';
import '../../domain/usecases/auth/get_current_user_usecase.dart';
import '../../domain/usecases/student_assignment/complete_assignment_usecase.dart';
import '../../domain/usecases/student_assignment/get_active_assignments_usecase.dart';
import '../../domain/usecases/student_assignment/get_student_assignment_detail_usecase.dart';
import '../../domain/usecases/student_assignment/get_student_assignments_usecase.dart';
import '../../domain/usecases/student_assignment/start_assignment_usecase.dart';
import '../../domain/usecases/student_assignment/update_assignment_progress_usecase.dart';
import '../../domain/usecases/auth/refresh_current_user_usecase.dart';
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
import '../../domain/usecases/badge/award_badge_usecase.dart';
import '../../domain/usecases/badge/check_earnable_badges_usecase.dart';
import '../../domain/usecases/badge/get_all_badges_usecase.dart';
import '../../domain/usecases/badge/get_badge_by_id_usecase.dart';
import '../../domain/usecases/badge/get_recently_earned_usecase.dart';
import '../../domain/usecases/badge/get_user_badges_usecase.dart';
import '../../domain/usecases/teacher/change_student_class_usecase.dart';
import '../../domain/usecases/teacher/create_class_usecase.dart';
import '../../domain/usecases/teacher/get_class_students_usecase.dart';
import '../../domain/usecases/teacher/get_classes_usecase.dart';
import '../../domain/usecases/teacher/get_student_detail_usecase.dart';
import '../../domain/usecases/teacher/get_student_progress_usecase.dart';
import '../../domain/usecases/teacher/get_teacher_stats_usecase.dart';
import '../../domain/usecases/teacher/reset_student_password_usecase.dart';
import '../../domain/usecases/teacher/send_password_reset_email_usecase.dart';
import '../../domain/usecases/user/add_xp_usecase.dart';
import '../../domain/usecases/user/get_classmates_usecase.dart';
import '../../domain/usecases/user/get_leaderboard_usecase.dart';
import '../../domain/usecases/user/get_user_by_id_usecase.dart';
import '../../domain/usecases/user/get_user_stats_usecase.dart';
import '../../domain/usecases/user/update_streak_usecase.dart';
import '../../domain/usecases/user/update_user_usecase.dart';
import '../../domain/usecases/vocabulary/add_word_to_vocabulary_usecase.dart';
import '../../domain/usecases/vocabulary/get_all_words_usecase.dart';
import '../../domain/usecases/vocabulary/get_due_for_review_usecase.dart';
import '../../domain/usecases/vocabulary/get_new_words_usecase.dart';
import '../../domain/usecases/vocabulary/get_user_vocabulary_progress_usecase.dart';
import '../../domain/usecases/vocabulary/get_vocabulary_stats_usecase.dart';
import '../../domain/usecases/vocabulary/get_word_by_id_usecase.dart';
import '../../domain/usecases/vocabulary/get_word_progress_usecase.dart';
import '../../domain/usecases/vocabulary/search_words_usecase.dart';
import '../../domain/usecases/vocabulary/update_word_progress_usecase.dart';
import '../../domain/usecases/wordlist/complete_phase_usecase.dart';
import '../../domain/usecases/wordlist/get_all_word_lists_usecase.dart';
import '../../domain/usecases/wordlist/get_progress_for_list_usecase.dart';
import '../../domain/usecases/wordlist/get_user_word_list_progress_usecase.dart';
import '../../domain/usecases/wordlist/get_word_list_by_id_usecase.dart';
import '../../domain/usecases/wordlist/get_words_for_list_usecase.dart';
import '../../domain/usecases/wordlist/reset_progress_usecase.dart';
import '../../domain/usecases/wordlist/update_word_list_progress_usecase.dart';
import '../../domain/usecases/content/get_content_blocks_usecase.dart';
import '../../domain/usecases/content/check_chapter_uses_content_blocks_usecase.dart';
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

final refreshCurrentUserUseCaseProvider = Provider((ref) {
  return RefreshCurrentUserUseCase(ref.watch(authRepositoryProvider));
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

// ============================================
// VOCABULARY USE CASES
// ============================================

final getAllWordsUseCaseProvider = Provider((ref) {
  return GetAllWordsUseCase(ref.watch(vocabularyRepositoryProvider));
});

final getWordByIdUseCaseProvider = Provider((ref) {
  return GetWordByIdUseCase(ref.watch(vocabularyRepositoryProvider));
});

final searchWordsUseCaseProvider = Provider((ref) {
  return SearchWordsUseCase(ref.watch(vocabularyRepositoryProvider));
});

final getUserVocabularyProgressUseCaseProvider = Provider((ref) {
  return GetUserVocabularyProgressUseCase(ref.watch(vocabularyRepositoryProvider));
});

final getWordProgressUseCaseProvider = Provider((ref) {
  return GetWordProgressUseCase(ref.watch(vocabularyRepositoryProvider));
});

final updateWordProgressUseCaseProvider = Provider((ref) {
  return UpdateWordProgressUseCase(ref.watch(vocabularyRepositoryProvider));
});

final getDueForReviewUseCaseProvider = Provider((ref) {
  return GetDueForReviewUseCase(ref.watch(vocabularyRepositoryProvider));
});

final getNewWordsUseCaseProvider = Provider((ref) {
  return GetNewWordsUseCase(ref.watch(vocabularyRepositoryProvider));
});

final getVocabularyStatsUseCaseProvider = Provider((ref) {
  return GetVocabularyStatsUseCase(ref.watch(vocabularyRepositoryProvider));
});

final addWordToVocabularyUseCaseProvider = Provider((ref) {
  return AddWordToVocabularyUseCase(ref.watch(vocabularyRepositoryProvider));
});

// ============================================
// WORD LIST USE CASES
// ============================================

final getAllWordListsUseCaseProvider = Provider((ref) {
  return GetAllWordListsUseCase(ref.watch(wordListRepositoryProvider));
});

final getWordListByIdUseCaseProvider = Provider((ref) {
  return GetWordListByIdUseCase(ref.watch(wordListRepositoryProvider));
});

final getWordsForListUseCaseProvider = Provider((ref) {
  return GetWordsForListUseCase(ref.watch(wordListRepositoryProvider));
});

final getUserWordListProgressUseCaseProvider = Provider((ref) {
  return GetUserWordListProgressUseCase(ref.watch(wordListRepositoryProvider));
});

final getProgressForListUseCaseProvider = Provider((ref) {
  return GetProgressForListUseCase(ref.watch(wordListRepositoryProvider));
});

final updateWordListProgressUseCaseProvider = Provider((ref) {
  return UpdateWordListProgressUseCase(ref.watch(wordListRepositoryProvider));
});

final completePhaseUseCaseProvider = Provider((ref) {
  return CompletePhaseUseCase(ref.watch(wordListRepositoryProvider));
});

final resetProgressUseCaseProvider = Provider((ref) {
  return ResetProgressUseCase(ref.watch(wordListRepositoryProvider));
});

// ============================================
// BADGE USE CASES
// ============================================

final getAllBadgesUseCaseProvider = Provider((ref) {
  return GetAllBadgesUseCase(ref.watch(badgeRepositoryProvider));
});

final getBadgeByIdUseCaseProvider = Provider((ref) {
  return GetBadgeByIdUseCase(ref.watch(badgeRepositoryProvider));
});

final getUserBadgesUseCaseProvider = Provider((ref) {
  return GetUserBadgesUseCase(ref.watch(badgeRepositoryProvider));
});

final awardBadgeUseCaseProvider = Provider((ref) {
  return AwardBadgeUseCase(ref.watch(badgeRepositoryProvider));
});

final checkEarnableBadgesUseCaseProvider = Provider((ref) {
  return CheckEarnableBadgesUseCase(ref.watch(badgeRepositoryProvider));
});

final getRecentlyEarnedUseCaseProvider = Provider((ref) {
  return GetRecentlyEarnedUseCase(ref.watch(badgeRepositoryProvider));
});

// ============================================
// USER USE CASES
// ============================================

final getUserByIdUseCaseProvider = Provider((ref) {
  return GetUserByIdUseCase(ref.watch(userRepositoryProvider));
});

final updateUserUseCaseProvider = Provider((ref) {
  return UpdateUserUseCase(ref.watch(userRepositoryProvider));
});

final addXPUseCaseProvider = Provider((ref) {
  return AddXPUseCase(ref.watch(userRepositoryProvider));
});

final updateStreakUseCaseProvider = Provider((ref) {
  return UpdateStreakUseCase(ref.watch(userRepositoryProvider));
});

final getUserStatsUseCaseProvider = Provider((ref) {
  return GetUserStatsUseCase(ref.watch(userRepositoryProvider));
});

final getClassmatesUseCaseProvider = Provider((ref) {
  return GetClassmatesUseCase(ref.watch(userRepositoryProvider));
});

final getLeaderboardUseCaseProvider = Provider((ref) {
  return GetLeaderboardUseCase(ref.watch(userRepositoryProvider));
});

// ============================================
// TEACHER USE CASES
// ============================================

final getTeacherStatsUseCaseProvider = Provider((ref) {
  return GetTeacherStatsUseCase(ref.watch(teacherRepositoryProvider));
});

final getClassesUseCaseProvider = Provider((ref) {
  return GetClassesUseCase(ref.watch(teacherRepositoryProvider));
});

final getClassStudentsUseCaseProvider = Provider((ref) {
  return GetClassStudentsUseCase(ref.watch(teacherRepositoryProvider));
});

final getStudentDetailUseCaseProvider = Provider((ref) {
  return GetStudentDetailUseCase(ref.watch(teacherRepositoryProvider));
});

final getStudentProgressUseCaseProvider = Provider((ref) {
  return GetStudentProgressUseCase(ref.watch(teacherRepositoryProvider));
});

final createClassUseCaseProvider = Provider((ref) {
  return CreateClassUseCase(ref.watch(teacherRepositoryProvider));
});

final sendPasswordResetEmailUseCaseProvider = Provider((ref) {
  return SendPasswordResetEmailUseCase(ref.watch(teacherRepositoryProvider));
});

// ============================================
// ASSIGNMENT USE CASES (Additional)
// ============================================

final getAssignmentsUseCaseProvider = Provider((ref) {
  return GetAssignmentsUseCase(ref.watch(teacherRepositoryProvider));
});

final getAssignmentDetailUseCaseProvider = Provider((ref) {
  return GetAssignmentDetailUseCase(ref.watch(teacherRepositoryProvider));
});

final getAssignmentStudentsUseCaseProvider = Provider((ref) {
  return GetAssignmentStudentsUseCase(ref.watch(teacherRepositoryProvider));
});

final deleteAssignmentUseCaseProvider = Provider((ref) {
  return DeleteAssignmentUseCase(ref.watch(teacherRepositoryProvider));
});

// ============================================
// STUDENT ASSIGNMENT USE CASES
// ============================================

final getStudentAssignmentsUseCaseProvider = Provider((ref) {
  return GetStudentAssignmentsUseCase(ref.watch(studentAssignmentRepositoryProvider));
});

final getActiveAssignmentsUseCaseProvider = Provider((ref) {
  return GetActiveAssignmentsUseCase(ref.watch(studentAssignmentRepositoryProvider));
});

final getStudentAssignmentDetailUseCaseProvider = Provider((ref) {
  return GetStudentAssignmentDetailUseCase(ref.watch(studentAssignmentRepositoryProvider));
});

final startAssignmentUseCaseProvider = Provider((ref) {
  return StartAssignmentUseCase(ref.watch(studentAssignmentRepositoryProvider));
});

final updateAssignmentProgressUseCaseProvider = Provider((ref) {
  return UpdateAssignmentProgressUseCase(ref.watch(studentAssignmentRepositoryProvider));
});

final completeAssignmentUseCaseProvider = Provider((ref) {
  return CompleteAssignmentUseCase(ref.watch(studentAssignmentRepositoryProvider));
});

// ============================================
// CONTENT BLOCK USE CASES
// ============================================

final getContentBlocksUseCaseProvider = Provider((ref) {
  return GetContentBlocksUseCase(ref.watch(contentBlockRepositoryProvider));
});

final checkChapterUsesContentBlocksUseCaseProvider = Provider((ref) {
  return CheckChapterUsesContentBlocksUseCase(ref.watch(contentBlockRepositoryProvider));
});
