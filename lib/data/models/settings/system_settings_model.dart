import '../../../domain/entities/system_settings.dart';

/// Model for system settings with JSON serialization
class SystemSettingsModel {
  const SystemSettingsModel({
    required this.xpChapterComplete,
    required this.xpActivityComplete,
    required this.xpActivityPerfect,
    required this.xpWordLearned,
    required this.xpWordMastered,
    required this.xpBookComplete,
    required this.xpStreakBonusDay,
    required this.xpAssignmentComplete,
    required this.maxStreakMultiplier,
    required this.streakBonusIncrement,
    required this.dailyXpCap,
    required this.defaultTimeLimit,
    required this.hintPenaltyPercent,
    required this.skipPenaltyPercent,
    required this.maintenanceMode,
    required this.minAppVersion,
    required this.featureWordLists,
    required this.featureAchievements,
  });

  final int xpChapterComplete;
  final int xpActivityComplete;
  final int xpActivityPerfect;
  final int xpWordLearned;
  final int xpWordMastered;
  final int xpBookComplete;
  final int xpStreakBonusDay;
  final int xpAssignmentComplete;
  final double maxStreakMultiplier;
  final double streakBonusIncrement;
  final int dailyXpCap;
  final int defaultTimeLimit;
  final int hintPenaltyPercent;
  final int skipPenaltyPercent;
  final bool maintenanceMode;
  final String minAppVersion;
  final bool featureWordLists;
  final bool featureAchievements;

  /// Parse from database rows (key-value pairs)
  factory SystemSettingsModel.fromRows(List<Map<String, dynamic>> rows) {
    final map = <String, dynamic>{};
    for (final row in rows) {
      final key = row['key'] as String;
      map[key] = _parseJsonbValue(row['value']);
    }
    return SystemSettingsModel.fromMap(map);
  }

  /// Parse from key-value map
  factory SystemSettingsModel.fromMap(Map<String, dynamic> m) {
    return SystemSettingsModel(
      xpChapterComplete: _toInt(m['xp_chapter_complete'], 50),
      xpActivityComplete: _toInt(m['xp_activity_complete'], 20),
      xpActivityPerfect: _toInt(m['xp_activity_perfect'], 30),
      xpWordLearned: _toInt(m['xp_word_learned'], 5),
      xpWordMastered: _toInt(m['xp_word_mastered'], 15),
      xpBookComplete: _toInt(m['xp_book_complete'], 200),
      xpStreakBonusDay: _toInt(m['xp_streak_bonus_day'], 10),
      xpAssignmentComplete: _toInt(m['xp_assignment_complete'], 100),
      maxStreakMultiplier: _toDouble(m['max_streak_multiplier'], 2.0),
      streakBonusIncrement: _toDouble(m['streak_bonus_increment'], 0.1),
      dailyXpCap: _toInt(m['daily_xp_cap'], 1000),
      defaultTimeLimit: _toInt(m['default_time_limit'], 60),
      hintPenaltyPercent: _toInt(m['hint_penalty_percent'], 10),
      skipPenaltyPercent: _toInt(m['skip_penalty_percent'], 50),
      maintenanceMode: _toBool(m['maintenance_mode'], false),
      minAppVersion: m['min_app_version']?.toString() ?? '1.0.0',
      featureWordLists: _toBool(m['feature_word_lists'], true),
      featureAchievements: _toBool(m['feature_achievements'], true),
    );
  }

  /// Default model (fallback)
  factory SystemSettingsModel.defaults() => const SystemSettingsModel(
        xpChapterComplete: 50,
        xpActivityComplete: 20,
        xpActivityPerfect: 30,
        xpWordLearned: 5,
        xpWordMastered: 15,
        xpBookComplete: 200,
        xpStreakBonusDay: 10,
        xpAssignmentComplete: 100,
        maxStreakMultiplier: 2.0,
        streakBonusIncrement: 0.1,
        dailyXpCap: 1000,
        defaultTimeLimit: 60,
        hintPenaltyPercent: 10,
        skipPenaltyPercent: 50,
        maintenanceMode: false,
        minAppVersion: '1.0.0',
        featureWordLists: true,
        featureAchievements: true,
      );

  /// Convert to entity
  SystemSettings toEntity() => SystemSettings(
        xpChapterComplete: xpChapterComplete,
        xpActivityComplete: xpActivityComplete,
        xpActivityPerfect: xpActivityPerfect,
        xpWordLearned: xpWordLearned,
        xpWordMastered: xpWordMastered,
        xpBookComplete: xpBookComplete,
        xpStreakBonusDay: xpStreakBonusDay,
        xpAssignmentComplete: xpAssignmentComplete,
        maxStreakMultiplier: maxStreakMultiplier,
        streakBonusIncrement: streakBonusIncrement,
        dailyXpCap: dailyXpCap,
        defaultTimeLimit: defaultTimeLimit,
        hintPenaltyPercent: hintPenaltyPercent,
        skipPenaltyPercent: skipPenaltyPercent,
        maintenanceMode: maintenanceMode,
        minAppVersion: minAppVersion,
        featureWordLists: featureWordLists,
        featureAchievements: featureAchievements,
      );

  /// Create model from entity
  factory SystemSettingsModel.fromEntity(SystemSettings e) =>
      SystemSettingsModel(
        xpChapterComplete: e.xpChapterComplete,
        xpActivityComplete: e.xpActivityComplete,
        xpActivityPerfect: e.xpActivityPerfect,
        xpWordLearned: e.xpWordLearned,
        xpWordMastered: e.xpWordMastered,
        xpBookComplete: e.xpBookComplete,
        xpStreakBonusDay: e.xpStreakBonusDay,
        xpAssignmentComplete: e.xpAssignmentComplete,
        maxStreakMultiplier: e.maxStreakMultiplier,
        streakBonusIncrement: e.streakBonusIncrement,
        dailyXpCap: e.dailyXpCap,
        defaultTimeLimit: e.defaultTimeLimit,
        hintPenaltyPercent: e.hintPenaltyPercent,
        skipPenaltyPercent: e.skipPenaltyPercent,
        maintenanceMode: e.maintenanceMode,
        minAppVersion: e.minAppVersion,
        featureWordLists: e.featureWordLists,
        featureAchievements: e.featureAchievements,
      );

  // Helper: Parse JSONB value (removes quotes, converts types)
  static dynamic _parseJsonbValue(dynamic v) {
    if (v is! String) return v;
    final s = v.replaceAll('"', '');
    if (s == 'true') return true;
    if (s == 'false') return false;
    return int.tryParse(s) ?? double.tryParse(s) ?? s;
  }

  static int _toInt(dynamic v, int defaultValue) {
    if (v == null) return defaultValue;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? defaultValue;
    return defaultValue;
  }

  static double _toDouble(dynamic v, double defaultValue) {
    if (v == null) return defaultValue;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? defaultValue;
    return defaultValue;
  }

  static bool _toBool(dynamic v, bool defaultValue) {
    if (v == null) return defaultValue;
    if (v is bool) return v;
    if (v is String) return v.toLowerCase() == 'true';
    return defaultValue;
  }
}
