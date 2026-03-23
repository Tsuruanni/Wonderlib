export 'package:owlio_shared/src/enums/user_role.dart';
export 'package:owlio_shared/src/enums/cefr_level.dart';

abstract class AppConstants {
  // App info
  static const appName = 'Owlio';
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

  // XP values → managed via system_settings table (admin panel configurable)
  // See: SystemSettings entity + systemSettingsProvider

  // Activity thresholds
  static const minimumPassScore = 60.0;
  static const excellentScore = 90.0;

  // Spaced repetition
  static const initialEaseFactor = 2.5;
  static const minEaseFactor = 1.3;
  static const maxInterval = 365;

  // Card System
  static const packCost = 100;
  static const cardsPerPack = 3;
  static const totalCardCount = 96;
  static const cardsPerCategory = 12;
  static const pityThreshold = 15;
}
