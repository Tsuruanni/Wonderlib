import 'package:equatable/equatable.dart';
import 'package:owlio_shared/owlio_shared.dart';

/// Statistics for teacher dashboard
class TeacherStats extends Equatable {

  const TeacherStats({
    required this.totalStudents,
    required this.totalClasses,
    required this.activeAssignments,
    required this.avgProgress,
  });
  final int totalStudents;
  final int totalClasses;
  final int activeAssignments;
  final double avgProgress;

  @override
  List<Object?> get props => [totalStudents, totalClasses, activeAssignments, avgProgress];
}

/// Class entity for teacher view
class TeacherClass extends Equatable {

  const TeacherClass({
    required this.id,
    required this.name,
    required this.grade,
    this.academicYear,
    this.description,
    required this.studentCount,
    required this.avgProgress,
    this.avgXp = 0,
    this.avgStreak = 0,
    this.totalReadingTime = 0,
    this.completedBooks = 0,
    this.activeLast30d = 0,
    this.totalVocabWords = 0,
    this.createdAt,
  });
  final String id;
  final String name;
  final int grade;
  final String? academicYear;
  final String? description;
  final int studentCount;
  final double avgProgress;
  final double avgXp;
  final double avgStreak;
  final int totalReadingTime;
  final int completedBooks;
  final int activeLast30d;
  final int totalVocabWords;
  final DateTime? createdAt;

  int get inactiveLast30d => studentCount - activeLast30d;
  double get booksPerStudent => studentCount > 0 ? completedBooks / studentCount : 0;

  @override
  List<Object?> get props => [id, name, grade, academicYear, description, studentCount, avgProgress, avgXp, avgStreak, totalReadingTime, completedBooks, activeLast30d, totalVocabWords, createdAt];
}

/// Student summary for class view
class StudentSummary extends Equatable {

  const StudentSummary({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.studentNumber,
    this.username,
    this.email,
    this.avatarUrl,
    required this.xp,
    required this.level,
    required this.currentStreak,
    required this.booksRead,
    required this.avgProgress,
    required this.leagueTier,
    this.passwordPlain,
  });
  final String id;
  final String firstName;
  final String lastName;
  final String? studentNumber;
  final String? username;
  final String? email;
  final String? avatarUrl;
  final int xp;
  final int level;
  final int currentStreak;
  final int booksRead;
  final double avgProgress;
  final LeagueTier leagueTier;
  final String? passwordPlain;

  String get fullName => '$firstName $lastName';

  @override
  List<Object?> get props => [id, firstName, lastName, studentNumber, username, email, avatarUrl, xp, level, currentStreak, booksRead, avgProgress, leagueTier, passwordPlain];
}

/// Student's progress on a specific book
class StudentBookProgress extends Equatable {

  const StudentBookProgress({
    required this.bookId,
    required this.bookTitle,
    this.bookCoverUrl,
    required this.completionPercentage,
    required this.totalReadingTime,
    required this.completedChapters,
    required this.totalChapters,
    this.lastReadAt,
  });
  final String bookId;
  final String bookTitle;
  final String? bookCoverUrl;
  final double completionPercentage;
  final int totalReadingTime;
  final int completedChapters;
  final int totalChapters;
  final DateTime? lastReadAt;

  @override
  List<Object?> get props => [bookId, bookTitle, bookCoverUrl, completionPercentage, totalReadingTime, completedChapters, totalChapters, lastReadAt];
}

/// Summary of a student's vocabulary learning stats
class StudentVocabStats extends Equatable {

  const StudentVocabStats({
    required this.totalWords,
    required this.newCount,
    required this.learningCount,
    required this.reviewingCount,
    required this.masteredCount,
    required this.listsStarted,
    required this.listsCompleted,
    required this.totalSessions,
  });
  final int totalWords;
  final int newCount;
  final int learningCount;
  final int reviewingCount;
  final int masteredCount;
  final int listsStarted;
  final int listsCompleted;
  final int totalSessions;

  @override
  List<Object?> get props => [totalWords, newCount, learningCount, reviewingCount, masteredCount, listsStarted, listsCompleted, totalSessions];
}

/// Student's progress on a specific word list
class StudentWordListProgress extends Equatable {

  const StudentWordListProgress({
    required this.wordListId,
    required this.wordListName,
    this.wordListLevel,
    required this.wordListCategory,
    required this.wordCount,
    this.bestScore,
    this.bestAccuracy,
    required this.totalSessions,
    this.lastSessionAt,
    this.startedAt,
    this.completedAt,
  });
  final String wordListId;
  final String wordListName;
  final String? wordListLevel;
  final WordListCategory wordListCategory;
  final int wordCount;
  final int? bestScore;
  final double? bestAccuracy;
  final int totalSessions;
  final DateTime? lastSessionAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  bool get isComplete => completedAt != null;

  /// Star rating with configurable thresholds
  int starCountWith({int star3 = 90, int star2 = 70, int star1 = 50}) {
    if (bestAccuracy == null) return 0;
    if (bestAccuracy! >= star3) return 3;
    if (bestAccuracy! >= star2) return 2;
    if (bestAccuracy! >= star1) return 1;
    return 0;
  }

  /// Star rating with default thresholds (convenience getter)
  int get starCount => starCountWith();

  @override
  List<Object?> get props => [wordListId, wordListName, wordListLevel, wordListCategory, wordCount, bestScore, bestAccuracy, totalSessions, lastSessionAt, startedAt, completedAt];
}

/// Per-book reading stats for a school (used in teacher reports)
class BookReadingStats extends Equatable {
  const BookReadingStats({
    required this.bookId,
    required this.title,
    this.coverUrl,
    required this.level,
    required this.totalReaders,
    required this.completedReaders,
    required this.avgProgress,
  });

  final String bookId;
  final String title;
  final String? coverUrl;
  final String level;
  final int totalReaders;
  final int completedReaders;
  final double avgProgress;

  @override
  List<Object?> get props => [bookId, title, coverUrl, level, totalReaders, completedReaders, avgProgress];
}

/// A recent activity event from a student in the school
class RecentActivity extends Equatable {
  const RecentActivity({
    required this.studentId,
    required this.studentFirstName,
    required this.studentLastName,
    this.avatarUrl,
    required this.activityType,
    required this.description,
    required this.xpAmount,
    required this.createdAt,
  });

  final String studentId;
  final String studentFirstName;
  final String studentLastName;
  final String? avatarUrl;
  final String activityType;
  final String description;
  final int xpAmount;
  final DateTime createdAt;

  String get studentFullName => '$studentFirstName $studentLastName';

  @override
  List<Object?> get props => [studentId, studentFirstName, studentLastName, avatarUrl, activityType, description, xpAmount, createdAt];
}
