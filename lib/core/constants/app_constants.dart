export 'package:readeng_shared/src/enums/user_role.dart';
export 'package:readeng_shared/src/enums/cefr_level.dart';

abstract class AppConstants {
  // App info
  static const appName = 'ReadEng';
  static const appVersion = '1.0.0';

  // Pagination
  static const defaultPageSize = 20;
  static const maxPageSize = 100;

  // Cache durations
  static const cacheValidityHours = 24;
  static const imageCacheDays = 30;

  // Timeouts
  static const apiTimeoutSeconds = 30;
  static const syncTimeoutSeconds = 60;

  // Gamification
  static const xpPerPage = 2;
  static const xpPerChapter = 25;
  static const xpPerBook = 150;
  static const xpPerCorrectAnswer = 5;
  static const xpPerVocabularyWord = 3;
  static const xpDailyLogin = 10;
  static const xpStreak7Days = 50;
  static const xpStreak30Days = 200;
  static const xpPerfectScore = 30;

  // Activity thresholds
  static const minimumPassScore = 60.0;
  static const excellentScore = 90.0;

  // Spaced repetition
  static const initialEaseFactor = 2.5;
  static const minEaseFactor = 1.3;
  static const maxInterval = 365;

  // Streak
  static const streakResetHours = 48;

  // Card System
  static const packCost = 100;
  static const cardsPerPack = 3;
  static const totalCardCount = 96;
  static const cardsPerCategory = 12;
  static const pityThreshold = 15;
}

enum UserLevel {
  bronze(1, 5, 'Bronze Reader', 0, 500),
  silver(6, 10, 'Silver Reader', 500, 2000),
  gold(11, 15, 'Gold Reader', 2000, 5000),
  platinum(16, 20, 'Platinum Reader', 5000, 10000),
  diamond(21, 100, 'Diamond Reader', 10000, 1000000);

  final int minLevel;
  final int maxLevel;
  final String title;
  final int minXP;
  final int maxXP;

  const UserLevel(this.minLevel, this.maxLevel, this.title, this.minXP, this.maxXP);

  static UserLevel fromXP(int xp) {
    if (xp >= diamond.minXP) return diamond;
    if (xp >= platinum.minXP) return platinum;
    if (xp >= gold.minXP) return gold;
    if (xp >= silver.minXP) return silver;
    return bronze;
  }

  static int calculateLevel(int xp) {
    // Formula: threshold(n) = n * (n + 1) * 50
    // Inverse: level = floor((-1 + sqrt(1 + xp/25)) / 2) + 1
    if (xp <= 0) return 1;
    final level = ((-1 + _sqrt(1 + xp / 25)) / 2).floor() + 1;
    return level.clamp(1, 100);
  }

  static double _sqrt(double value) {
    if (value <= 0) return 0;
    // Newton's method for square root
    double guess = value / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + value / guess) / 2;
    }
    return guess;
  }
}
