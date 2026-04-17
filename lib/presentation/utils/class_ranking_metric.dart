import '../../domain/entities/teacher.dart';

/// Metrics a teacher can sort classes by in the Class Overview report.
enum ClassRankingMetric {
  avgXp,
  avgProgress,
  avgStreak,
  totalReadingTime,
  booksPerStudent,
}

extension ClassRankingMetricX on ClassRankingMetric {
  String get label {
    switch (this) {
      case ClassRankingMetric.avgXp:
        return 'Avg XP';
      case ClassRankingMetric.avgProgress:
        return 'Avg Progress';
      case ClassRankingMetric.avgStreak:
        return 'Avg Streak';
      case ClassRankingMetric.totalReadingTime:
        return 'Total Reading Time';
      case ClassRankingMetric.booksPerStudent:
        return 'Books / Student';
    }
  }

  num Function(TeacherClass) get selector {
    switch (this) {
      case ClassRankingMetric.avgXp:
        return (c) => c.avgXp;
      case ClassRankingMetric.avgProgress:
        return (c) => c.avgProgress;
      case ClassRankingMetric.avgStreak:
        return (c) => c.avgStreak;
      case ClassRankingMetric.totalReadingTime:
        return (c) => c.totalReadingTime;
      case ClassRankingMetric.booksPerStudent:
        return (c) => c.booksPerStudent;
    }
  }
}
