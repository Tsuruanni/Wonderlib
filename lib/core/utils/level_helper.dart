/// Shared level/XP calculation used by ProfileScreen and StudentProfileDialog.
/// Formula: Level n starts at (n-1) * n * 50 cumulative XP.
/// Level 1 = 0, Level 2 = 100, Level 3 = 300, Level 4 = 600, Level 5 = 1000, ...
abstract class LevelHelper {
  /// Cumulative XP threshold to reach [level].
  static int xpForLevel(int level) {
    if (level <= 1) return 0;
    return (level - 1) * level * 50;
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
