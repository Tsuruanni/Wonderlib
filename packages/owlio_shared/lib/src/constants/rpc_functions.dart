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
  static const getBestBookQuizResult = 'get_best_book_quiz_result';
  static const getStudentQuizResults = 'get_student_quiz_results';

  // Vocabulary
  static const completeVocabularySession = 'complete_vocabulary_session';
  static const completeDailyReview = 'complete_daily_review';
  static const getDueReviewWords = 'get_due_review_words';

  // Cards
  static const buyCardPack = 'buy_card_pack';
  static const openCardPack = 'open_card_pack';
  static const getDailyQuestProgress = 'get_daily_quest_progress';
  static const claimDailyBonus = 'claim_daily_bonus';
  static const getQuestCompletionStats = 'get_quest_completion_stats';
  static const buyStreakFreeze = 'buy_streak_freeze';

  // Leaderboard (total XP)
  static const getClassLeaderboard = 'get_class_leaderboard';
  static const getSchoolLeaderboard = 'get_school_leaderboard';
  static const getUserClassPosition = 'get_user_class_position';
  static const getUserSchoolPosition = 'get_user_school_position';

  // Leaderboard (weekly leagues)
  static const getWeeklyClassLeaderboard = 'get_weekly_class_leaderboard';
  static const getWeeklySchoolLeaderboard = 'get_weekly_school_leaderboard';
  static const getUserWeeklyClassPosition = 'get_user_weekly_class_position';
  static const getUserWeeklySchoolPosition = 'get_user_weekly_school_position';
  static const processWeeklyLeagueReset = 'process_weekly_league_reset';

  // Learning paths
  static const getUserLearningPaths = 'get_user_learning_paths';
  static const applyLearningPathTemplate = 'apply_learning_path_template';

  // Teacher
  static const getTeacherStats = 'get_teacher_stats';
  static const getClassesWithStats = 'get_classes_with_stats';
  static const getStudentsInClass = 'get_students_in_class';
  static const getStudentProgressWithBooks = 'get_student_progress_with_books';
  static const getStudentVocabStats = 'get_student_vocab_stats';
  static const getStudentWordListProgress = 'get_student_word_list_progress';
  static const getAssignmentsWithStats = 'get_assignments_with_stats';
  static const createAssignmentWithStudents = 'create_assignment_with_students';
  static const getSchoolBookReadingStats = 'get_school_book_reading_stats';
  static const updateAssignmentProgress = 'update_assignment_progress';
  static const getAssignmentDetailWithStats = 'get_assignment_detail_with_stats';
  static const getClassLearningPathUnits = 'get_class_learning_path_units';
  static const getUnitAssignmentItems = 'get_unit_assignment_items';
  static const calculateUnitAssignmentProgress = 'calculate_unit_assignment_progress';
  static const syncUnitAssignmentProgress = 'sync_unit_assignment_progress';
  static const getStudentUnitProgress = 'get_student_unit_progress';
  static const startAssignment = 'start_assignment';
  static const completeAssignment = 'complete_assignment';
  static const getRecentSchoolActivity = 'get_recent_school_activity';
  static const getSchoolStudentsForTeacher = 'get_school_students_for_teacher';
  static const updateStudentClass = 'update_student_class';
  static const deleteClass = 'delete_class';
  static const bulkMoveStudents = 'bulk_move_students';
  static const updateClass = 'update_class';

  // Avatars
  static const setAvatarBase = 'set_avatar_base';
  static const buyAvatarItem = 'buy_avatar_item';
  static const equipAvatarItem = 'equip_avatar_item';
  static const unequipAvatarItem = 'unequip_avatar_item';
}
