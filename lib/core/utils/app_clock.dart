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

  /// Returns a date in Istanbul (server-aligned) as 'YYYY-MM-DD'.
  /// Mirrors server-side `app_current_date()`. Use this for ANY Supabase
  /// DATE column (read_date, login_date, session_date, claim_date, etc.).
  ///
  /// Pass no argument for today, or pass any [DateTime] to get its Istanbul
  /// date string (e.g. `AppClock.istanbulDate(AppClock.now().subtract(...))`).
  ///
  /// Why: DATE columns are timezone-agnostic; the server stores/compares
  /// them as Istanbul (Europe/Istanbul, permanent UTC+3 since 2016 — no DST).
  /// Calling `.toUtc()` then substring shifts backwards 3h and silently
  /// writes/queries the previous day for 3h every night.
  static String istanbulDate([DateTime? dt]) {
    final istanbul = (dt ?? now()).toUtc().add(const Duration(hours: 3));
    return istanbul.toIso8601String().substring(0, 10);
  }
}
