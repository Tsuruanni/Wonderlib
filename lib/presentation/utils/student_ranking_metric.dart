import '../../domain/entities/teacher.dart';

/// Metrics a teacher can sort students by in the Class Students (report) screen.
enum StudentRankingMetric {
  xp,
  booksRead,
  wordbankSize,
  lastActivity,
  name,
}

extension StudentRankingMetricX on StudentRankingMetric {
  String get label {
    switch (this) {
      case StudentRankingMetric.xp:
        return 'XP';
      case StudentRankingMetric.booksRead:
        return 'Books Read';
      case StudentRankingMetric.wordbankSize:
        return 'Wordbank Size';
      case StudentRankingMetric.lastActivity:
        return 'Last Activity';
      case StudentRankingMetric.name:
        return 'Name';
    }
  }

  /// Comparator — best/first students come first.
  int Function(StudentSummary, StudentSummary) get comparator {
    switch (this) {
      case StudentRankingMetric.xp:
        return (a, b) => b.xp.compareTo(a.xp);
      case StudentRankingMetric.booksRead:
        return (a, b) => b.booksRead.compareTo(a.booksRead);
      case StudentRankingMetric.wordbankSize:
        return (a, b) => b.wordbankSize.compareTo(a.wordbankSize);
      case StudentRankingMetric.lastActivity:
        return (a, b) {
          final ad = a.lastActivityDate;
          final bd = b.lastActivityDate;
          if (ad == null && bd == null) return 0;
          if (ad == null) return 1; // nulls last
          if (bd == null) return -1;
          return bd.compareTo(ad); // most recent first
        };
      case StudentRankingMetric.name:
        return (a, b) {
          final first = a.firstName.toLowerCase().compareTo(b.firstName.toLowerCase());
          return first != 0 ? first : a.lastName.toLowerCase().compareTo(b.lastName.toLowerCase());
        };
    }
  }
}
