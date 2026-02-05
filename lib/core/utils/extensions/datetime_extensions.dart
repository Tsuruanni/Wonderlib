import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

extension DateTimeExtensions on DateTime {
  /// Format as "Jan 15, 2025"
  String get formatted => DateFormat.yMMMd().format(this);

  /// Format as "15/01/2025"
  String get shortDate => DateFormat('dd/MM/yyyy').format(this);

  /// Format as "15 Ocak 2025"
  String formattedTR() => DateFormat('d MMMM yyyy', 'tr').format(this);

  /// Format as "14:30"
  String get time => DateFormat.Hm().format(this);

  /// Format as "Jan 15, 14:30"
  String get dateTime => DateFormat('MMM d, HH:mm').format(this);

  /// Format as relative time (e.g., "2 hours ago")
  String get timeAgo => timeago.format(this);

  /// Format as relative time in Turkish
  String get timeAgoTR => timeago.format(this, locale: 'tr');

  /// Check if date is today
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Check if date is yesterday
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }

  /// Check if date is in the past
  bool get isPast => isBefore(DateTime.now());

  /// Check if date is in the future
  bool get isFuture => isAfter(DateTime.now());

  /// Get start of day
  DateTime get startOfDay => DateTime(year, month, day);

  /// Get end of day
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59, 999);

  /// Get days since date
  int get daysSince => DateTime.now().difference(this).inDays;

  /// Get days until date
  int get daysUntil => difference(DateTime.now()).inDays;

  /// Check if same day as another date
  bool isSameDay(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }

  /// Add business days
  DateTime addBusinessDays(int days) {
    var result = this;
    var remaining = days;

    while (remaining > 0) {
      result = result.add(const Duration(days: 1));
      if (result.weekday != DateTime.saturday &&
          result.weekday != DateTime.sunday) {
        remaining--;
      }
    }

    return result;
  }
}

extension NullableDateTimeExtensions on DateTime? {
  /// Format or return placeholder
  String formatOr([String placeholder = '-']) {
    if (this == null) return placeholder;
    return this!.formatted;
  }

  /// Time ago or placeholder
  String timeAgoOr([String placeholder = '-']) {
    if (this == null) return placeholder;
    return this!.timeAgo;
  }
}
