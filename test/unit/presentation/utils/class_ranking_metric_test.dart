import 'package:flutter_test/flutter_test.dart';
import 'package:owlio/domain/entities/teacher.dart';
import 'package:owlio/presentation/utils/class_ranking_metric.dart';

TeacherClass _mkClass({
  String id = 'c1',
  double avgXp = 0,
  double avgProgress = 0,
  double avgStreak = 0,
  int totalReadingTime = 0,
  int studentCount = 10,
  int completedBooks = 0,
}) {
  return TeacherClass(
    id: id,
    name: 'Test',
    grade: 5,
    academicYear: '2025-2026',
    studentCount: studentCount,
    avgProgress: avgProgress,
    avgXp: avgXp,
    avgStreak: avgStreak,
    totalReadingTime: totalReadingTime,
    completedBooks: completedBooks,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  test('avgXp selector returns avgXp field', () {
    final c = _mkClass(avgXp: 123.45);
    expect(ClassRankingMetric.avgXp.selector(c), 123.45);
  });

  test('avgProgress selector returns avgProgress field', () {
    final c = _mkClass(avgProgress: 67.8);
    expect(ClassRankingMetric.avgProgress.selector(c), 67.8);
  });

  test('avgStreak selector returns avgStreak field', () {
    final c = _mkClass(avgStreak: 4.2);
    expect(ClassRankingMetric.avgStreak.selector(c), 4.2);
  });

  test('totalReadingTime selector returns totalReadingTime field', () {
    final c = _mkClass(totalReadingTime: 99999);
    expect(ClassRankingMetric.totalReadingTime.selector(c), 99999);
  });

  test('booksPerStudent selector returns computed booksPerStudent', () {
    final c = _mkClass(studentCount: 10, completedBooks: 25);
    expect(ClassRankingMetric.booksPerStudent.selector(c), 2.5);
  });

  test('every metric has a non-empty label', () {
    for (final m in ClassRankingMetric.values) {
      expect(m.label, isNotEmpty);
    }
  });
}
