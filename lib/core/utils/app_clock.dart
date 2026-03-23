/// Debug-aware clock utility.
/// All business logic should use AppClock.now() instead of DateTime.now().
/// Offset is set from SystemSettings.debugDateOffset on app load.
class AppClock {
  static int _offsetDays = 0;

  /// Set the debug offset in days. Called once from systemSettingsProvider.
  static void setOffset(int days) => _offsetDays = days;

  /// Current offset in days (for display purposes).
  static int get offsetDays => _offsetDays;

  /// Returns DateTime.now() shifted by offset days.
  static DateTime now() => DateTime.now().add(Duration(days: _offsetDays));

  /// Returns today at midnight, shifted by offset.
  static DateTime today() {
    final n = now();
    return DateTime(n.year, n.month, n.day);
  }
}
