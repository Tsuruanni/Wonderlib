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
  static const wordLists = 'word_lists';
  static const wordListItems = 'word_list_items';
  static const userWordListProgress = 'user_word_list_progress';
  static const userNodeCompletions = 'user_node_completions';
  static const dailyReviewSessions = 'daily_review_sessions';

  // Gamification
  static const badges = 'badges';
  static const userBadges = 'user_badges';
  static const mythCards = 'myth_cards';
  static const userCards = 'user_cards';
  static const userCardStats = 'user_card_stats';

  // Assignments
  static const assignments = 'assignments';
  static const assignmentStudents = 'assignment_students';
  static const unitBookAssignments = 'unit_book_assignments';
  static const unitCurriculumAssignments = 'unit_curriculum_assignments';

  // Settings
  static const systemSettings = 'system_settings';
}
