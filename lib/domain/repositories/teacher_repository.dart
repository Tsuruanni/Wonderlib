import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/user.dart';

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

/// Repository for teacher-specific operations
abstract class TeacherRepository {
  /// Get dashboard statistics for a teacher
  Future<Either<Failure, TeacherStats>> getTeacherStats(String teacherId);

  /// Get list of classes for a teacher's school
  Future<Either<Failure, List<TeacherClass>>> getClasses(String schoolId);

  /// Get students in a specific class
  Future<Either<Failure, List<StudentSummary>>> getClassStudents(String classId);

  /// Get detailed student info (for student detail screen)
  Future<Either<Failure, User>> getStudentDetail(String studentId);

  /// Get student's reading progress across all books
  Future<Either<Failure, List<StudentBookProgress>>> getStudentProgress(String studentId);

  // =============================================
  // ASSIGNMENT METHODS
  // =============================================

  /// Get all assignments created by a teacher
  Future<Either<Failure, List<Assignment>>> getAssignments(String teacherId);

  /// Get assignment detail with student progress
  Future<Either<Failure, Assignment>> getAssignmentDetail(String assignmentId);

  /// Get students' progress for an assignment
  Future<Either<Failure, List<AssignmentStudent>>> getAssignmentStudents(
    String assignmentId,
  );

  /// Create a new assignment
  Future<Either<Failure, Assignment>> createAssignment(
    String teacherId,
    CreateAssignmentData data,
  );

  /// Delete an assignment
  Future<Either<Failure, void>> deleteAssignment(String assignmentId);

  // =============================================
  // CLASS MANAGEMENT METHODS
  // =============================================

  /// Create a new class
  Future<Either<Failure, String>> createClass({
    required String schoolId,
    required String name,
    String? description,
  });

  /// Update a student's class assignment
  Future<Either<Failure, void>> updateStudentClass({
    required String studentId,
    required String newClassId,
  });

  // =============================================
  // PASSWORD MANAGEMENT METHODS
  // =============================================

  /// Send password reset email to student
  Future<Either<Failure, void>> sendPasswordResetEmail(String email);

  /// Generate and set new password for student (returns the new password)
  Future<Either<Failure, String>> resetStudentPassword(String studentId);
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

// =============================================
// ASSIGNMENT ENTITIES
// =============================================

/// Assignment type enum
enum AssignmentType {
  book,
  vocabulary,
  mixed;

  String get displayName {
    switch (this) {
      case AssignmentType.book:
        return 'Book Reading';
      case AssignmentType.vocabulary:
        return 'Vocabulary';
      case AssignmentType.mixed:
        return 'Mixed';
    }
  }

  static AssignmentType fromString(String value) {
    switch (value) {
      case 'book':
        return AssignmentType.book;
      case 'vocabulary':
        return AssignmentType.vocabulary;
      case 'mixed':
        return AssignmentType.mixed;
      default:
        return AssignmentType.book;
    }
  }
}

/// Assignment status for students
enum AssignmentStatus {
  pending,
  inProgress,
  completed,
  overdue;

  String get displayName {
    switch (this) {
      case AssignmentStatus.pending:
        return 'Not Started';
      case AssignmentStatus.inProgress:
        return 'In Progress';
      case AssignmentStatus.completed:
        return 'Completed';
      case AssignmentStatus.overdue:
        return 'Overdue';
    }
  }

  static AssignmentStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return AssignmentStatus.pending;
      case 'in_progress':
        return AssignmentStatus.inProgress;
      case 'completed':
        return AssignmentStatus.completed;
      case 'overdue':
        return AssignmentStatus.overdue;
      default:
        return AssignmentStatus.pending;
    }
  }
}

/// Assignment entity for teacher view
class Assignment {

  const Assignment({
    required this.id,
    required this.teacherId,
    this.classId,
    this.className,
    required this.type,
    required this.title,
    this.description,
    required this.contentConfig,
    required this.startDate,
    required this.dueDate,
    required this.createdAt,
    required this.totalStudents,
    required this.completedStudents,
  });
  final String id;
  final String teacherId;
  final String? classId;
  final String? className;
  final AssignmentType type;
  final String title;
  final String? description;
  final Map<String, dynamic> contentConfig;
  final DateTime startDate;
  final DateTime dueDate;
  final DateTime createdAt;
  final int totalStudents;
  final int completedStudents;

  double get completionRate =>
      totalStudents > 0 ? (completedStudents / totalStudents) * 100 : 0;

  bool get isOverdue => DateTime.now().isAfter(dueDate);
  bool get isActive =>
      DateTime.now().isAfter(startDate) && DateTime.now().isBefore(dueDate);
  bool get isUpcoming => DateTime.now().isBefore(startDate);
}

/// Student's progress on a specific assignment
class AssignmentStudent {

  const AssignmentStudent({
    required this.id,
    required this.studentId,
    required this.studentName,
    this.avatarUrl,
    required this.status,
    required this.progress,
    this.score,
    this.startedAt,
    this.completedAt,
  });
  final String id;
  final String studentId;
  final String studentName;
  final String? avatarUrl;
  final AssignmentStatus status;
  final double progress;
  final double? score;
  final DateTime? startedAt;
  final DateTime? completedAt;
}

/// Data for creating a new assignment
class CreateAssignmentData {

  const CreateAssignmentData({
    this.classId,
    this.studentIds,
    required this.type,
    required this.title,
    this.description,
    required this.contentConfig,
    required this.startDate,
    required this.dueDate,
  });
  final String? classId;
  final List<String>? studentIds;
  final AssignmentType type;
  final String title;
  final String? description;
  final Map<String, dynamic> contentConfig;
  final DateTime startDate;
  final DateTime dueDate;
}
