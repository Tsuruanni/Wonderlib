/// RPC function name constants for the ReadEng platform.
///
/// Use these instead of raw string literals when calling Supabase RPC:
/// ```dart
/// supabase.rpc(RpcFunctions.awardXpTransaction, params: {...});
/// ```
abstract class RpcFunctions {
  // Gamification
  static const awardXpTransaction = 'award_xp_transaction';
  static const checkAndAwardBadges = 'check_and_award_badges';
  static const updateUserStreak = 'update_user_streak';
  static const getUserStats = 'get_user_stats';

  // Books & Quizzes
  static const bookHasQuiz = 'book_has_quiz';
  static const getUserUnitBooks = 'get_user_unit_books';
  static const getBestBookQuizResult = 'get_best_book_quiz_result';
  static const getStudentQuizResults = 'get_student_quiz_results';

  // Vocabulary
  static const getAssignedVocabularyUnits = 'get_assigned_vocabulary_units';
  static const completeVocabularySession = 'complete_vocabulary_session';
  static const completeDailyReview = 'complete_daily_review';

  // Cards
  static const buyCardPack = 'buy_card_pack';
  static const openCardPack = 'open_card_pack';
  static const claimDailyQuestPack = 'claim_daily_quest_pack';
  static const hasDailyQuestPackClaimed = 'has_daily_quest_pack_claimed';

  // Teacher
  static const getTeacherStats = 'get_teacher_stats';
  static const getClassesWithStats = 'get_classes_with_stats';
  static const getStudentsInClass = 'get_students_in_class';
  static const getStudentProgressWithBooks = 'get_student_progress_with_books';
  static const getStudentVocabStats = 'get_student_vocab_stats';
  static const getStudentWordListProgress = 'get_student_word_list_progress';
  static const getAssignmentsWithStats = 'get_assignments_with_stats';
}
