import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/assignment.dart';
import '../entities/class_learning_path_unit.dart';
import '../entities/student_unit_progress_item.dart';
import '../entities/teacher.dart';
import '../entities/user.dart';

// Re-export entity types for backwards compatibility
export '../entities/assignment.dart';
export '../entities/teacher.dart';

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

  /// Get student's vocabulary learning stats summary
  Future<Either<Failure, StudentVocabStats>> getStudentVocabStats(String studentId);

  /// Get student's word list progress (per-list breakdown)
  Future<Either<Failure, List<StudentWordListProgress>>> getStudentWordListProgress(String studentId);

  /// Get per-book reading stats for a school (teacher reports)
  Future<Either<Failure, List<BookReadingStats>>> getSchoolBookReadingStats(String schoolId);

  /// Get recent activity feed for a school (teacher dashboard)
  Future<Either<Failure, List<RecentActivity>>> getRecentSchoolActivity(String schoolId);

  /// Get all students in a school sorted by XP (teacher leaderboard report)
  Future<Either<Failure, List<StudentSummary>>> getSchoolStudentsForTeacher(String schoolId);

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

  /// Get learning path units for a class (for unit assignment creation)
  Future<Either<Failure, List<ClassLearningPathUnit>>> getClassLearningPathUnits(
    String classId,
  );

  /// Get per-item progress for a student in a unit assignment
  Future<Either<Failure, List<StudentUnitProgressItem>>> getStudentUnitProgress(
    String assignmentId,
    String studentId,
  );

  // =============================================
  // CLASS MANAGEMENT METHODS
  // =============================================

  /// Create a new class
  Future<Either<Failure, String>> createClass({
    required String schoolId,
    required String name,
    required int grade,
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

  // =============================================
  // PROFILE METHODS
  // =============================================

  /// Update teacher's own profile (first name, last name)
  Future<Either<Failure, void>> updateProfile({
    required String firstName,
    required String lastName,
  });

  /// Update class name, grade, and description
  Future<Either<Failure, void>> updateClass({
    required String classId,
    required String name,
    required int grade,
    String? description,
  });

  /// Delete a class (must have no students)
  Future<Either<Failure, void>> deleteClass(String classId);

  /// Move multiple students to a target class atomically
  Future<Either<Failure, void>> bulkMoveStudents({
    required List<String> studentIds,
    required String targetClassId,
  });
}
