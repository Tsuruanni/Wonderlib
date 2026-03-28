/// Database table name constants for the ReadEng platform.
///
/// Use these instead of raw string literals when querying Supabase:
/// ```dart
/// supabase.from(DbTables.books).select();
/// ```
abstract class DbTables {
  // Content
  static const books = 'books';
  static const chapters = 'chapters';
  static const contentBlocks = 'content_blocks';
  static const inlineActivities = 'inline_activities';
  static const inlineActivityResults = 'inline_activity_results';

  // Quiz
  static const bookQuizzes = 'book_quizzes';
  static const bookQuizQuestions = 'book_quiz_questions';
  static const bookQuizResults = 'book_quiz_results';

  // Users & Auth
  static const profiles = 'profiles';
  static const schools = 'schools';
  static const classes = 'classes';

  // Reading
  static const readingProgress = 'reading_progress';
  static const dailyChapterReads = 'daily_chapter_reads';
  static const activities = 'activities';
  static const activityResults = 'activity_results';

  // Vocabulary
  static const vocabularyWords = 'vocabulary_words';
  static const vocabularyProgress = 'vocabulary_progress';
  static const vocabularyUnits = 'vocabulary_units';
  static const vocabularySessions = 'vocabulary_sessions';
  static const vocabularySessionWords = 'vocabulary_session_words';
  static const chapterVocabulary = 'chapter_vocabulary';
  static const wordLists = 'word_lists';
  static const wordListItems = 'word_list_items';
  static const userWordListProgress = 'user_word_list_progress';
  static const userNodeCompletions = 'user_node_completions';
  static const dailyReviewSessions = 'daily_review_sessions';

  // Gamification
  static const badges = 'badges';
  static const userBadges = 'user_badges';
  static const xpLogs = 'xp_logs';
  static const coinLogs = 'coin_logs';
  static const leagueHistory = 'league_history';
  static const mythCards = 'myth_cards';
  static const userCards = 'user_cards';
  static const userCardStats = 'user_card_stats';
  static const packPurchases = 'pack_purchases';
  static const dailyQuests = 'daily_quests';
  static const dailyQuestCompletions = 'daily_quest_completions';
  static const dailyQuestBonusClaims = 'daily_quest_bonus_claims';
  static const dailyLogins = 'daily_logins';

  // Learning path templates
  static const learningPathTemplates = 'learning_path_templates';
  static const learningPathTemplateUnits = 'learning_path_template_units';
  static const learningPathTemplateItems = 'learning_path_template_items';

  // Learning path scope assignments
  static const scopeLearningPaths = 'scope_learning_paths';
  static const scopeLearningPathUnits = 'scope_learning_path_units';
  static const scopeUnitItems = 'scope_unit_items';
  static const pathDailyReviewCompletions = 'path_daily_review_completions';

  // Assignments
  static const assignments = 'assignments';
  static const assignmentStudents = 'assignment_students';
  // Settings
  static const systemSettings = 'system_settings';

  // Avatars
  static const avatarBases = 'avatar_bases';
  static const avatarItemCategories = 'avatar_item_categories';
  static const avatarItems = 'avatar_items';
  static const userAvatarItems = 'user_avatar_items';
}
