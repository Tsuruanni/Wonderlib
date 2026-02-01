/// Application-wide configuration
/// These values can be overridden via environment variables or remote config
class AppConfig {
  AppConfig._();

  // ============================================
  // API & Backend
  // ============================================

  /// Maximum retry attempts for failed API calls
  static const int maxRetryAttempts = 3;

  /// Timeout duration for API calls
  static const Duration apiTimeout = Duration(seconds: 30);

  /// Timeout duration for file uploads
  static const Duration uploadTimeout = Duration(minutes: 5);

  // ============================================
  // Caching & Storage
  // ============================================

  /// Cache duration for book content
  static const Duration bookCacheDuration = Duration(days: 7);

  /// Cache duration for user data
  static const Duration userCacheDuration = Duration(hours: 1);

  /// Maximum offline storage size (MB)
  static const int maxOfflineStorageMB = 500;

  // ============================================
  // Reading & Content
  // ============================================

  /// Default font size for reader
  static const double defaultReaderFontSize = 18.0;

  /// Minimum font size for reader
  static const double minReaderFontSize = 12.0;

  /// Maximum font size for reader
  static const double maxReaderFontSize = 32.0;

  /// Words per minute for reading time estimation
  static const int averageWPM = 150;

  /// Auto-scroll speed options (words per minute)
  static const List<int> autoScrollSpeeds = [100, 150, 200, 250];

  // ============================================
  // Gamification
  // ============================================

  /// XP required per level (multiplied by level number)
  static const int xpPerLevel = 100;

  /// Maximum streak bonus multiplier
  static const double maxStreakMultiplier = 2.0;

  /// Streak bonus increment per day
  static const double streakBonusIncrement = 0.1;

  /// Daily XP cap (prevents gaming the system)
  static const int dailyXPCap = 1000;

  /// XP rewards for different actions
  static const Map<String, int> xpRewards = {
    'chapter_complete': 50,
    'activity_complete': 20,
    'activity_perfect': 30,
    'word_learned': 5,
    'word_mastered': 15,
    'book_complete': 200,
    'streak_bonus_day': 10,
    'assignment_complete': 100,
  };

  // ============================================
  // Activities & Games
  // ============================================

  /// Default number of options in multiple choice
  static const int defaultOptionCount = 4;

  /// Minimum correct percentage to pass activity
  static const int minPassingPercentage = 70;

  /// Time bonus threshold (percentage of time remaining)
  static const double timeBonusThreshold = 0.5;

  /// Time bonus multiplier
  static const double timeBonusMultiplier = 1.5;

  // ============================================
  // Vocabulary & Spaced Repetition
  // ============================================

  /// Spaced repetition intervals (days)
  static const List<int> spacedRepetitionDays = [1, 3, 7, 14, 30];

  /// Words considered "due" within this many hours
  static const int dueWordHoursBuffer = 4;

  /// Maximum new words per day
  static const int maxNewWordsPerDay = 20;

  /// Review session word count
  static const int reviewSessionWordCount = 10;

  // ============================================
  // UI & UX
  // ============================================

  /// Animation duration for page transitions
  static const Duration pageTransitionDuration = Duration(milliseconds: 300);

  /// Debounce duration for search input
  static const Duration searchDebounce = Duration(milliseconds: 500);

  /// Snackbar display duration
  static const Duration snackbarDuration = Duration(seconds: 3);

  /// Pull-to-refresh threshold
  static const double pullToRefreshThreshold = 100.0;

  // ============================================
  // Sync & Offline
  // ============================================

  /// Sync interval when online
  static const Duration syncInterval = Duration(minutes: 5);

  /// Maximum items in sync queue before force sync
  static const int maxSyncQueueSize = 50;

  /// Retry delay for failed sync operations
  static const Duration syncRetryDelay = Duration(seconds: 30);

  // ============================================
  // Feature Flags (can be overridden by remote config)
  // ============================================

  /// Enable offline mode
  static const bool enableOfflineMode = true;

  /// Enable text-to-speech
  static const bool enableTTS = true;

  /// Enable dark mode
  static const bool enableDarkMode = true;

  /// Enable push notifications
  static const bool enableNotifications = true;

  /// Enable analytics
  static const bool enableAnalytics = true;

  /// Enable crash reporting
  static const bool enableCrashReporting = true;
}
