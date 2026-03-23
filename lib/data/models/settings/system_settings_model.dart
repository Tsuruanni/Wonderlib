import '../../../domain/entities/system_settings.dart';

/// Model for system settings with JSON serialization
class SystemSettingsModel {
  const SystemSettingsModel({
    required this.xpChapterComplete,
    required this.xpBookComplete,
    required this.xpQuizPass,
    required this.streakFreezePrice,
    required this.streakFreezeMax,
    required this.debugDateOffset,
  });

  final int xpChapterComplete;
  final int xpBookComplete;
  final int xpQuizPass;
  final int streakFreezePrice;
  final int streakFreezeMax;
  final int debugDateOffset;

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
      xpBookComplete: _toInt(m['xp_book_complete'], 200),
      xpQuizPass: _toInt(m['xp_quiz_pass'], 20),
      streakFreezePrice: _toInt(m['streak_freeze_price'], 50),
      streakFreezeMax: _toInt(m['streak_freeze_max'], 2),
      debugDateOffset: _toInt(m['debug_date_offset'], 0),
    );
  }

  /// Default model (fallback)
  factory SystemSettingsModel.defaults() => const SystemSettingsModel(
        xpChapterComplete: 50,
        xpBookComplete: 200,
        xpQuizPass: 20,
        streakFreezePrice: 50,
        streakFreezeMax: 2,
        debugDateOffset: 0,
      );

  /// Convert to entity
  SystemSettings toEntity() => SystemSettings(
        xpChapterComplete: xpChapterComplete,
        xpBookComplete: xpBookComplete,
        xpQuizPass: xpQuizPass,
        streakFreezePrice: streakFreezePrice,
        streakFreezeMax: streakFreezeMax,
        debugDateOffset: debugDateOffset,
      );

  /// Create model from entity
  factory SystemSettingsModel.fromEntity(SystemSettings e) =>
      SystemSettingsModel(
        xpChapterComplete: e.xpChapterComplete,
        xpBookComplete: e.xpBookComplete,
        xpQuizPass: e.xpQuizPass,
        streakFreezePrice: e.streakFreezePrice,
        streakFreezeMax: e.streakFreezeMax,
        debugDateOffset: e.debugDateOffset,
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
}
