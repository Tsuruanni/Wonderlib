import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/avatar/get_avatar_bases_usecase.dart';
import '../../domain/usecases/avatar/set_avatar_base_usecase.dart';
import '../../domain/usecases/avatar/get_avatar_items_usecase.dart';
import '../../domain/usecases/avatar/get_user_avatar_items_usecase.dart';
import '../../domain/usecases/avatar/buy_avatar_item_usecase.dart';
import '../../domain/usecases/avatar/equip_avatar_item_usecase.dart';
import '../../domain/usecases/avatar/unequip_avatar_item_usecase.dart';
import '../../domain/usecases/activity/get_activities_by_chapter_usecase.dart';
import '../../domain/usecases/activity/get_activity_by_id_usecase.dart';
import '../../domain/usecases/activity/get_activity_stats_usecase.dart';
import '../../domain/usecases/activity/get_best_result_usecase.dart';
import '../../domain/usecases/activity/complete_inline_activity_usecase.dart';
import '../../domain/usecases/activity/get_completed_inline_activities_usecase.dart';
import '../../domain/usecases/activity/get_inline_activities_usecase.dart';
import '../../domain/usecases/activity/submit_activity_result_usecase.dart';
import '../../domain/usecases/assignment/create_assignment_usecase.dart';
import '../../domain/usecases/assignment/delete_assignment_usecase.dart';
import '../../domain/usecases/assignment/get_assignment_detail_usecase.dart';
import '../../domain/usecases/assignment/get_assignment_students_usecase.dart';
import '../../domain/usecases/assignment/get_assignments_usecase.dart';
import '../../domain/usecases/assignment/get_class_learning_path_units_usecase.dart';
import '../../domain/usecases/assignment/get_student_unit_progress_usecase.dart';
import '../../domain/usecases/student_assignment/get_unit_assignment_items_usecase.dart';
import '../../domain/usecases/student_assignment/calculate_unit_progress_usecase.dart';
import '../../domain/usecases/auth/get_current_user_usecase.dart';
import '../../domain/usecases/auth/refresh_current_user_usecase.dart';
import '../../domain/usecases/teacher/bulk_move_students_usecase.dart';
import '../../domain/usecases/teacher/delete_class_usecase.dart';
import '../../domain/usecases/teacher/update_class_usecase.dart';
import '../../domain/usecases/teacher/update_teacher_profile_usecase.dart';
import '../../domain/usecases/student_assignment/complete_assignment_usecase.dart';
import '../../domain/usecases/student_assignment/get_active_assignments_usecase.dart';
import '../../domain/usecases/student_assignment/get_student_assignment_detail_usecase.dart';
import '../../domain/usecases/student_assignment/get_student_assignments_usecase.dart';
import '../../domain/usecases/student_assignment/start_assignment_usecase.dart';
import '../../domain/usecases/student_assignment/update_assignment_progress_usecase.dart';
import '../../domain/usecases/auth/sign_in_with_email_usecase.dart';
import '../../domain/usecases/auth/sign_out_usecase.dart';
import '../../domain/usecases/book/download_book_usecase.dart';
import '../../domain/usecases/book/get_book_by_id_usecase.dart';
import '../../domain/usecases/book/get_books_by_ids_usecase.dart';
import '../../domain/usecases/book/get_books_usecase.dart';
import '../../domain/usecases/book/get_chapters_usecase.dart';
import '../../domain/usecases/book/get_completed_book_ids_usecase.dart';
import '../../domain/usecases/book/get_continue_reading_usecase.dart';
import '../../domain/usecases/book/get_recommended_books_usecase.dart';
import '../../domain/usecases/book/remove_book_download_usecase.dart';
import '../../domain/usecases/book/search_books_usecase.dart';
import '../../domain/usecases/reading/check_read_today_usecase.dart';
import '../../domain/usecases/reading/get_reading_progress_usecase.dart';
import '../../domain/usecases/reading/get_words_read_today_usecase.dart';
import '../../domain/usecases/activity/get_correct_answers_today_usecase.dart';
import '../../domain/usecases/reading/handle_book_completion_usecase.dart';
import '../../domain/usecases/reading/mark_chapter_complete_usecase.dart';
import '../../domain/usecases/reading/save_reading_progress_usecase.dart';
import '../../domain/usecases/reading/update_current_chapter_usecase.dart';
import '../../domain/usecases/reading/update_reading_progress_usecase.dart';
import '../../domain/usecases/badge/award_badge_usecase.dart';
import '../../domain/usecases/badge/check_and_award_badges_usecase.dart';
import '../../domain/usecases/badge/get_recently_earned_usecase.dart';
import '../../domain/usecases/badge/get_user_badges_usecase.dart';
import '../../domain/usecases/card/get_all_cards_usecase.dart';
import '../../domain/usecases/card/get_user_cards_usecase.dart';
import '../../domain/usecases/card/get_user_card_stats_usecase.dart';
import '../../domain/usecases/card/buy_pack_usecase.dart';
import '../../domain/usecases/card/open_pack_usecase.dart';
import '../../domain/usecases/teacher/create_class_usecase.dart';
import '../../domain/usecases/teacher/get_class_students_usecase.dart';
import '../../domain/usecases/teacher/get_classes_usecase.dart';
import '../../domain/usecases/teacher/get_student_detail_usecase.dart';
import '../../domain/usecases/teacher/get_student_progress_usecase.dart';
import '../../domain/usecases/teacher/get_student_vocab_stats_usecase.dart';
import '../../domain/usecases/teacher/get_student_word_list_progress_usecase.dart';
import '../../domain/usecases/teacher/get_recent_school_activity_usecase.dart';
import '../../domain/usecases/teacher/get_school_book_reading_stats_usecase.dart';
import '../../domain/usecases/teacher/get_teacher_stats_usecase.dart';
import '../../domain/usecases/teacher/reset_student_password_usecase.dart';
import '../../domain/usecases/teacher/send_password_reset_email_usecase.dart';
import '../../domain/usecases/user/add_xp_usecase.dart';
import '../../domain/usecases/user/get_user_weekly_position_usecase.dart';
import '../../domain/usecases/user/get_total_leaderboard_usecase.dart';
import '../../domain/usecases/user/get_user_total_position_usecase.dart';
import '../../domain/usecases/user/get_weekly_leaderboard_usecase.dart';
import '../../domain/usecases/user/get_user_by_id_usecase.dart';
import '../../domain/usecases/user/get_user_stats_usecase.dart';
import '../../domain/usecases/user/get_weekly_activity_usecase.dart';
import '../../domain/usecases/user/update_streak_usecase.dart';
import '../../domain/usecases/user/buy_streak_freeze_usecase.dart';
import '../../domain/usecases/user/get_login_dates_usecase.dart';
import '../../domain/usecases/user/update_user_usecase.dart';
import '../../domain/usecases/book_quiz/grade_book_quiz_usecase.dart';
import '../../domain/usecases/book_quiz/get_user_quiz_results_usecase.dart';
import '../../domain/usecases/wordlist/get_session_history_usecase.dart';
import '../../domain/usecases/wordlist/reset_progress_usecase.dart';
import '../../domain/usecases/vocabulary/complete_node_usecase.dart';
import '../../domain/usecases/vocabulary/get_node_completions_usecase.dart';
import '../../domain/usecases/vocabulary/add_word_to_vocabulary_usecase.dart';
import '../../domain/usecases/vocabulary/get_all_words_usecase.dart';
import '../../domain/usecases/vocabulary/get_due_for_review_usecase.dart';
import '../../domain/usecases/vocabulary/get_new_words_usecase.dart';
import '../../domain/usecases/vocabulary/get_user_vocabulary_progress_usecase.dart';
import '../../domain/usecases/vocabulary/get_vocabulary_stats_usecase.dart';
import '../../domain/usecases/vocabulary/get_word_by_id_usecase.dart';
import '../../domain/usecases/vocabulary/get_words_by_ids_usecase.dart';
import '../../domain/usecases/vocabulary/get_word_progress_batch_usecase.dart';
import '../../domain/usecases/vocabulary/get_word_progress_usecase.dart';
import '../../domain/usecases/vocabulary/get_words_from_lists_learned_today_usecase.dart';
import '../../domain/usecases/vocabulary/get_words_learned_today_usecase.dart';
import '../../domain/usecases/vocabulary/add_words_batch_usecase.dart';
import '../../domain/usecases/vocabulary/complete_daily_review_usecase.dart';
import '../../domain/usecases/vocabulary/save_daily_review_position_usecase.dart';
import '../../domain/usecases/vocabulary/get_today_review_session_usecase.dart';
import '../../domain/usecases/vocabulary/lookup_word_definition_usecase.dart';
import '../../domain/usecases/vocabulary/search_words_usecase.dart';
import '../../domain/usecases/vocabulary/update_word_progress_usecase.dart';
import '../../domain/usecases/wordlist/complete_session_usecase.dart';
import '../../domain/usecases/wordlist/get_all_word_lists_usecase.dart';
import '../../domain/usecases/wordlist/get_user_learning_paths_usecase.dart';
import '../../domain/usecases/wordlist/get_progress_for_list_usecase.dart';
import '../../domain/usecases/wordlist/get_user_word_list_progress_usecase.dart';
import '../../domain/usecases/wordlist/get_word_list_by_id_usecase.dart';
import '../../domain/usecases/wordlist/get_words_for_list_usecase.dart';
import '../../domain/usecases/content/get_content_blocks_usecase.dart';
import '../../domain/usecases/content/check_chapter_uses_content_blocks_usecase.dart';
import '../../domain/usecases/book_quiz/book_has_quiz_usecase.dart';
import '../../domain/usecases/book_quiz/get_best_quiz_result_usecase.dart';
import '../../domain/usecases/book_quiz/get_quiz_for_book_usecase.dart';
import '../../domain/usecases/book_quiz/get_student_quiz_results_usecase.dart';
import '../../domain/usecases/book_quiz/submit_quiz_result_usecase.dart';
import '../../domain/usecases/settings/get_system_settings_usecase.dart';
import '../../domain/usecases/daily_quest/get_daily_quest_progress_usecase.dart';
import '../../domain/usecases/daily_quest/claim_daily_bonus_usecase.dart';
import '../../domain/usecases/daily_quest/has_daily_bonus_claimed_usecase.dart';
import 'repository_providers.dart';

// ============================================
// AUTH USE CASES
// ============================================

final signInWithEmailUseCaseProvider = Provider((ref) {
  return SignInWithEmailUseCase(ref.watch(authRepositoryProvider));
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

final getBooksByIdsUseCaseProvider = Provider((ref) {
  return GetBooksByIdsUseCase(ref.watch(bookRepositoryProvider));
});

final searchBooksUseCaseProvider = Provider((ref) {
  return SearchBooksUseCase(ref.watch(bookRepositoryProvider));
});

final getChaptersUseCaseProvider = Provider((ref) {
  return GetChaptersUseCase(ref.watch(bookRepositoryProvider));
});

final getContinueReadingUseCaseProvider = Provider((ref) {
  return GetContinueReadingUseCase(ref.watch(bookRepositoryProvider));
});

final getRecommendedBooksUseCaseProvider = Provider((ref) {
  return GetRecommendedBooksUseCase(ref.watch(bookRepositoryProvider));
});

final getCompletedBookIdsUseCaseProvider = Provider((ref) {
  return GetCompletedBookIdsUseCase(ref.watch(bookRepositoryProvider));
});

final downloadBookUseCaseProvider = Provider((ref) {
  return DownloadBookUseCase(ref.watch(bookDownloadRepositoryProvider));
});

final removeBookDownloadUseCaseProvider = Provider((ref) {
  return RemoveBookDownloadUseCase(ref.watch(bookDownloadRepositoryProvider));
});

// ============================================
// TEACHER USE CASES
// ============================================

final resetStudentPasswordUseCaseProvider = Provider((ref) {
  return ResetStudentPasswordUseCase(ref.watch(teacherRepositoryProvider));
});

// ============================================
// ASSIGNMENT USE CASES
// ============================================

final createAssignmentUseCaseProvider = Provider((ref) {
  return CreateAssignmentUseCase(ref.watch(teacherRepositoryProvider));
});

final getClassLearningPathUnitsUseCaseProvider = Provider((ref) {
  return GetClassLearningPathUnitsUseCase(ref.watch(teacherRepositoryProvider));
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

final handleBookCompletionUseCaseProvider = Provider((ref) {
  return HandleBookCompletionUseCase(
    ref.watch(bookRepositoryProvider),
    ref.watch(bookQuizRepositoryProvider),
  );
});

final updateCurrentChapterUseCaseProvider = Provider((ref) {
  return UpdateCurrentChapterUseCase(ref.watch(bookRepositoryProvider));
});

final updateReadingProgressUseCaseProvider = Provider((ref) {
  return UpdateReadingProgressUseCase(ref.watch(bookRepositoryProvider));
});

final checkReadTodayUseCaseProvider = Provider((ref) {
  return CheckReadTodayUseCase(ref.watch(bookRepositoryProvider));
});
final getWeeklyActivityUseCaseProvider = Provider<GetWeeklyActivityUseCase>((ref) {
  return GetWeeklyActivityUseCase(ref.watch(userRepositoryProvider));
});

final getWordsReadTodayUseCaseProvider = Provider((ref) {
  return GetWordsReadTodayUseCase(ref.watch(bookRepositoryProvider));
});

// ============================================
// ACTIVITY USE CASES
// ============================================

final getCorrectAnswersTodayUseCaseProvider = Provider((ref) {
  return GetCorrectAnswersTodayUseCase(ref.watch(bookRepositoryProvider));
});

final getActivitiesByChapterUseCaseProvider = Provider((ref) {
  return GetActivitiesByChapterUseCase(ref.watch(activityRepositoryProvider));
});

final getActivityByIdUseCaseProvider = Provider((ref) {
  return GetActivityByIdUseCase(ref.watch(activityRepositoryProvider));
});

final submitActivityResultUseCaseProvider = Provider((ref) {
  return SubmitActivityResultUseCase(ref.watch(activityRepositoryProvider));
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

final getCompletedInlineActivitiesUseCaseProvider = Provider((ref) {
  return GetCompletedInlineActivitiesUseCase(ref.watch(bookRepositoryProvider));
});

final completeInlineActivityUseCaseProvider = Provider((ref) {
  return CompleteInlineActivityUseCase(
    ref.watch(bookRepositoryProvider),
    ref.watch(vocabularyRepositoryProvider),
  );
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

final getWordsByIdsUseCaseProvider = Provider((ref) {
  return GetWordsByIdsUseCase(ref.watch(vocabularyRepositoryProvider));
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

final getWordProgressBatchUseCaseProvider = Provider((ref) {
  return GetWordProgressBatchUseCase(ref.watch(vocabularyRepositoryProvider));
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

final lookupWordDefinitionUseCaseProvider = Provider((ref) {
  return LookupWordDefinitionUseCase(ref.watch(vocabularyRepositoryProvider));
});

final getTodayReviewSessionUseCaseProvider = Provider((ref) {
  return GetTodayReviewSessionUseCase(ref.watch(vocabularyRepositoryProvider));
});

final completeDailyReviewUseCaseProvider = Provider((ref) {
  return CompleteDailyReviewUseCase(ref.watch(vocabularyRepositoryProvider));
});

final addWordsBatchUseCaseProvider = Provider((ref) {
  return AddWordsBatchToVocabularyUseCase(ref.watch(vocabularyRepositoryProvider));
});

final getWordsLearnedTodayUseCaseProvider = Provider((ref) {
  return GetWordsLearnedTodayUseCase(ref.watch(vocabularyRepositoryProvider));
});

final getWordsFromListsLearnedTodayUseCaseProvider = Provider((ref) {
  return GetWordsFromListsLearnedTodayUseCase(ref.watch(vocabularyRepositoryProvider));
});

final getNodeCompletionsUseCaseProvider = Provider((ref) {
  return GetNodeCompletionsUseCase(ref.watch(vocabularyRepositoryProvider));
});

final completeNodeUseCaseProvider = Provider((ref) {
  return CompleteNodeUseCase(ref.watch(vocabularyRepositoryProvider));
});

final saveDailyReviewPositionUseCaseProvider = Provider((ref) {
  return SaveDailyReviewPositionUseCase(ref.watch(vocabularyRepositoryProvider));
});

// ============================================
// WORD LIST USE CASES
// ============================================

final getUserLearningPathsUseCaseProvider = Provider<GetUserLearningPathsUseCase>((ref) {
  return GetUserLearningPathsUseCase(ref.watch(wordListRepositoryProvider));
});

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

final completeSessionUseCaseProvider = Provider((ref) {
  return CompleteSessionUseCase(ref.watch(wordListRepositoryProvider));
});

// ============================================
// BADGE USE CASES
// ============================================

final getUserBadgesUseCaseProvider = Provider((ref) {
  return GetUserBadgesUseCase(ref.watch(badgeRepositoryProvider));
});

final awardBadgeUseCaseProvider = Provider((ref) {
  return AwardBadgeUseCase(ref.watch(badgeRepositoryProvider));
});

final getRecentlyEarnedUseCaseProvider = Provider((ref) {
  return GetRecentlyEarnedUseCase(ref.watch(badgeRepositoryProvider));
});

final checkAndAwardBadgesUseCaseProvider = Provider((ref) {
  return CheckAndAwardBadgesUseCase(ref.watch(badgeRepositoryProvider));
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

final buyStreakFreezeUseCaseProvider = Provider((ref) {
  return BuyStreakFreezeUseCase(ref.watch(userRepositoryProvider));
});

final getLoginDatesUseCaseProvider = Provider((ref) {
  return GetLoginDatesUseCase(ref.watch(userRepositoryProvider));
});

final getUserStatsUseCaseProvider = Provider((ref) {
  return GetUserStatsUseCase(ref.watch(userRepositoryProvider));
});

final getWeeklyLeaderboardUseCaseProvider = Provider((ref) {
  return GetWeeklyLeaderboardUseCase(ref.watch(userRepositoryProvider));
});

final getUserWeeklyPositionUseCaseProvider = Provider((ref) {
  return GetUserWeeklyPositionUseCase(ref.watch(userRepositoryProvider));
});

final getTotalLeaderboardUseCaseProvider = Provider((ref) {
  return GetTotalLeaderboardUseCase(ref.watch(userRepositoryProvider));
});

final getUserTotalPositionUseCaseProvider = Provider((ref) {
  return GetUserTotalPositionUseCase(ref.watch(userRepositoryProvider));
});

// ============================================
// WORD LIST USE CASES (additional)
// ============================================

final getSessionHistoryUseCaseProvider = Provider((ref) {
  return GetSessionHistoryUseCase(ref.watch(wordListRepositoryProvider));
});

final resetProgressUseCaseProvider = Provider((ref) {
  return ResetProgressUseCase(ref.watch(wordListRepositoryProvider));
});

// ============================================
// BOOK QUIZ USE CASES (additional)
// ============================================

final getUserQuizResultsUseCaseProvider = Provider((ref) {
  return GetUserQuizResultsUseCase(ref.watch(bookQuizRepositoryProvider));
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

final getStudentVocabStatsUseCaseProvider = Provider((ref) {
  return GetStudentVocabStatsUseCase(ref.watch(teacherRepositoryProvider));
});

final getStudentWordListProgressUseCaseProvider = Provider((ref) {
  return GetStudentWordListProgressUseCase(ref.watch(teacherRepositoryProvider));
});

final getSchoolBookReadingStatsUseCaseProvider = Provider((ref) {
  return GetSchoolBookReadingStatsUseCase(ref.watch(teacherRepositoryProvider));
});

final getRecentSchoolActivityUseCaseProvider = Provider((ref) {
  return GetRecentSchoolActivityUseCase(ref.watch(teacherRepositoryProvider));
});

final sendPasswordResetEmailUseCaseProvider = Provider((ref) {
  return SendPasswordResetEmailUseCase(ref.watch(teacherRepositoryProvider));
});

final updateTeacherProfileUseCaseProvider = Provider((ref) {
  return UpdateTeacherProfileUseCase(ref.watch(teacherRepositoryProvider));
});

final updateClassUseCaseProvider = Provider((ref) {
  return UpdateClassUseCase(ref.watch(teacherRepositoryProvider));
});

final deleteClassUseCaseProvider = Provider((ref) {
  return DeleteClassUseCase(ref.watch(teacherRepositoryProvider));
});

final bulkMoveStudentsUseCaseProvider = Provider((ref) {
  return BulkMoveStudentsUseCase(ref.watch(teacherRepositoryProvider));
});

final refreshCurrentUserUseCaseProvider = Provider((ref) {
  return RefreshCurrentUserUseCase(ref.watch(authRepositoryProvider));
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

final getStudentUnitProgressUseCaseProvider = Provider((ref) {
  return GetStudentUnitProgressUseCase(ref.watch(teacherRepositoryProvider));
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

final getUnitAssignmentItemsUseCaseProvider = Provider((ref) {
  return GetUnitAssignmentItemsUseCase(ref.watch(studentAssignmentRepositoryProvider));
});

final calculateUnitProgressUseCaseProvider = Provider((ref) {
  return CalculateUnitProgressUseCase(ref.watch(studentAssignmentRepositoryProvider));
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

// ============================================
// SYSTEM SETTINGS USE CASES
// ============================================

final getSystemSettingsUseCaseProvider = Provider((ref) {
  return GetSystemSettingsUseCase(ref.watch(systemSettingsRepositoryProvider));
});

// ============================================
// CARD USE CASES
// ============================================

final getAllCardsUseCaseProvider = Provider((ref) {
  return GetAllCardsUseCase(ref.watch(cardRepositoryProvider));
});

final getUserCardsUseCaseProvider = Provider((ref) {
  return GetUserCardsUseCase(ref.watch(cardRepositoryProvider));
});

final getUserCardStatsUseCaseProvider = Provider((ref) {
  return GetUserCardStatsUseCase(ref.watch(cardRepositoryProvider));
});

final openPackUseCaseProvider = Provider((ref) {
  return OpenPackUseCase(ref.watch(cardRepositoryProvider));
});

final buyPackUseCaseProvider = Provider((ref) {
  return BuyPackUseCase(ref.watch(cardRepositoryProvider));
});

// ============================================
// BOOK QUIZ USE CASES
// ============================================

final getQuizForBookUseCaseProvider = Provider((ref) {
  return GetQuizForBookUseCase(ref.watch(bookQuizRepositoryProvider));
});

final bookHasQuizUseCaseProvider = Provider((ref) {
  return BookHasQuizUseCase(ref.watch(bookQuizRepositoryProvider));
});

final submitQuizResultUseCaseProvider = Provider((ref) {
  return SubmitQuizResultUseCase(ref.watch(bookQuizRepositoryProvider));
});

final getBestQuizResultUseCaseProvider = Provider((ref) {
  return GetBestQuizResultUseCase(ref.watch(bookQuizRepositoryProvider));
});

final getStudentQuizResultsUseCaseProvider = Provider((ref) {
  return GetStudentQuizResultsUseCase(ref.watch(bookQuizRepositoryProvider));
});

final gradeBookQuizUseCaseProvider = Provider((ref) {
  return GradeBookQuizUseCase();
});

// ============================================
// DAILY QUEST USE CASES
// ============================================

final getDailyQuestProgressUseCaseProvider = Provider((ref) {
  return GetDailyQuestProgressUseCase(ref.watch(dailyQuestRepositoryProvider));
});

final claimDailyBonusUseCaseProvider = Provider((ref) {
  return ClaimDailyBonusUseCase(ref.watch(dailyQuestRepositoryProvider));
});

final hasDailyBonusClaimedUseCaseProvider = Provider((ref) {
  return HasDailyBonusClaimedUseCase(ref.watch(dailyQuestRepositoryProvider));
});

// ============================================
// AVATAR USE CASES
// ============================================

final getAvatarBasesUseCaseProvider = Provider((ref) {
  return GetAvatarBasesUseCase(ref.watch(avatarRepositoryProvider));
});

final setAvatarBaseUseCaseProvider = Provider((ref) {
  return SetAvatarBaseUseCase(ref.watch(avatarRepositoryProvider));
});

final getAvatarItemsUseCaseProvider = Provider((ref) {
  return GetAvatarItemsUseCase(ref.watch(avatarRepositoryProvider));
});

final getUserAvatarItemsUseCaseProvider = Provider((ref) {
  return GetUserAvatarItemsUseCase(ref.watch(avatarRepositoryProvider));
});

final buyAvatarItemUseCaseProvider = Provider((ref) {
  return BuyAvatarItemUseCase(ref.watch(avatarRepositoryProvider));
});

final equipAvatarItemUseCaseProvider = Provider((ref) {
  return EquipAvatarItemUseCase(ref.watch(avatarRepositoryProvider));
});

final unequipAvatarItemUseCaseProvider = Provider((ref) {
  return UnequipAvatarItemUseCase(ref.watch(avatarRepositoryProvider));
});
