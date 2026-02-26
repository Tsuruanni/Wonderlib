/// League tier for the weekly leaderboard system.
///
/// Students compete within their class each week. Top performers
/// get promoted, bottom performers get demoted (Duolingo-style).
enum LeagueTier {
  bronze,
  silver,
  gold,
  platinum,
  diamond;

  /// Database string representation.
  String get dbValue => name;

  /// Parse from database string.
  static LeagueTier fromDbValue(String value) {
    return LeagueTier.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => LeagueTier.bronze,
    );
  }

  /// Display label for UI.
  String get label {
    switch (this) {
      case bronze:
        return 'Bronze';
      case silver:
        return 'Silver';
      case gold:
        return 'Gold';
      case platinum:
        return 'Platinum';
      case diamond:
        return 'Diamond';
    }
  }

  /// Next tier (for promotion). Returns null if already at max.
  LeagueTier? get nextTier {
    final idx = index + 1;
    return idx < LeagueTier.values.length ? LeagueTier.values[idx] : null;
  }

  /// Previous tier (for demotion). Returns null if already at min.
  LeagueTier? get previousTier {
    final idx = index - 1;
    return idx >= 0 ? LeagueTier.values[idx] : null;
  }
}
