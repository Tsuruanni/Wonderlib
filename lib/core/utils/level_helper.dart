/// Shared level/XP calculation used by ProfileScreen and StudentProfileDialog.
/// Must match server-side `calculate_level()` SQL function.
/// Formula: threshold(level) = (level-1) * level * 100
/// Level 1 = 0, Level 2 = 200, Level 3 = 600, Level 4 = 1200, Level 5 = 2000, ...
abstract class LevelHelper {
  /// Cumulative XP threshold to reach [level].
  static int xpForLevel(int level) {
    if (level <= 1) return 0;
    return (level - 1) * level * 100;
  }

  /// XP earned within current level (numerator for progress bar).
  static int xpInCurrentLevel(int totalXp, int level) {
    return totalXp - xpForLevel(level);
  }

  /// XP needed to go from [level] to [level + 1] (denominator for progress bar).
  static int xpToNextLevel(int level) {
    return xpForLevel(level + 1) - xpForLevel(level);
  }

  /// Progress fraction (0.0 to 1.0) toward next level.
  static double progress(int totalXp, int level) {
    final needed = xpToNextLevel(level);
    if (needed <= 0) return 1.0;
    return (xpInCurrentLevel(totalXp, level) / needed).clamp(0.0, 1.0);
  }
}
