import 'package:equatable/equatable.dart';

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
    this.grade,
    this.academicYear,
    required this.studentCount,
    required this.avgProgress,
    this.createdAt,
  });
  final String id;
  final String name;
  final int? grade;
  final String? academicYear;
  final int studentCount;
  final double avgProgress;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [id, name, grade, academicYear, studentCount, avgProgress, createdAt];
}

/// Student summary for class view
class StudentSummary extends Equatable {

  const StudentSummary({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.studentNumber,
    this.email,
    this.avatarUrl,
    required this.xp,
    required this.level,
    required this.currentStreak,
    required this.booksRead,
    required this.avgProgress,
  });
  final String id;
  final String firstName;
  final String lastName;
  final String? studentNumber;
  final String? email;
  final String? avatarUrl;
  final int xp;
  final int level;
  final int currentStreak;
  final int booksRead;
  final double avgProgress;

  String get fullName => '$firstName $lastName';

  @override
  List<Object?> get props => [id, firstName, lastName, studentNumber, email, avatarUrl, xp, level, currentStreak, booksRead, avgProgress];
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
  final String wordListCategory;
  final int wordCount;
  final int? bestScore;
  final double? bestAccuracy;
  final int totalSessions;
  final DateTime? lastSessionAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  bool get isComplete => completedAt != null;

  /// Star rating: 3 stars for ≥90%, 2 for ≥70%, 1 for ≥50%, 0 otherwise
  int get starCount {
    if (bestAccuracy == null) return 0;
    if (bestAccuracy! >= 90) return 3;
    if (bestAccuracy! >= 70) return 2;
    if (bestAccuracy! >= 50) return 1;
    return 0;
  }

  @override
  List<Object?> get props => [wordListId, wordListName, wordListLevel, wordListCategory, wordCount, bestScore, bestAccuracy, totalSessions, lastSessionAt, startedAt, completedAt];
}
