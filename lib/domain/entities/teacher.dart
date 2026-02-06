/// Statistics for teacher dashboard
class TeacherStats {

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
}

/// Class entity for teacher view
class TeacherClass {

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
}

/// Student summary for class view
class StudentSummary {

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
}

/// Student's progress on a specific book
class StudentBookProgress {

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
}
