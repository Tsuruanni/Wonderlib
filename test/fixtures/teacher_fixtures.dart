import 'package:readeng/domain/repositories/teacher_repository.dart';

/// Test fixtures for Teacher-related tests
class TeacherStatsFixtures {
  TeacherStatsFixtures._();

  static TeacherStats validStats() => const TeacherStats(
        totalStudents: 150,
        totalClasses: 5,
        activeAssignments: 12,
        avgProgress: 65.5,
      );

  static TeacherStats emptyStats() => const TeacherStats(
        totalStudents: 0,
        totalClasses: 0,
        activeAssignments: 0,
        avgProgress: 0.0,
      );

  static TeacherStats highPerformanceStats() => const TeacherStats(
        totalStudents: 200,
        totalClasses: 8,
        activeAssignments: 25,
        avgProgress: 85.0,
      );
}

class TeacherClassFixtures {
  TeacherClassFixtures._();

  static TeacherClass validClass() => TeacherClass(
        id: 'class-789',
        name: '7-A',
        grade: 7,
        academicYear: '2024-2025',
        studentCount: 30,
        avgProgress: 68.5,
        createdAt: DateTime.parse('2024-09-01T00:00:00Z'),
      );

  static TeacherClass minimalClass() => const TeacherClass(
        id: 'class-minimal',
        name: '5-B',
        studentCount: 25,
        avgProgress: 55.0,
      );

  static TeacherClass emptyClass() => const TeacherClass(
        id: 'class-empty',
        name: '9-C',
        grade: 9,
        studentCount: 0,
        avgProgress: 0.0,
      );

  static List<TeacherClass> classList() => [
        validClass(),
        minimalClass(),
        TeacherClass(
          id: 'class-3',
          name: '8-A',
          grade: 8,
          academicYear: '2024-2025',
          studentCount: 28,
          avgProgress: 72.0,
          createdAt: DateTime.parse('2024-09-01T00:00:00Z'),
        ),
      ];
}

class StudentSummaryFixtures {
  StudentSummaryFixtures._();

  static StudentSummary validStudent() => const StudentSummary(
        id: 'student-123',
        firstName: 'John',
        lastName: 'Doe',
        studentNumber: '2024001',
        email: 'john@example.com',
        avatarUrl: 'https://example.com/avatar.png',
        xp: 500,
        level: 5,
        currentStreak: 7,
        booksRead: 3,
        avgProgress: 75.0,
      );

  static StudentSummary minimalStudent() => const StudentSummary(
        id: 'student-minimal',
        firstName: 'Jane',
        lastName: 'Smith',
        xp: 100,
        level: 2,
        currentStreak: 0,
        booksRead: 0,
        avgProgress: 0.0,
      );

  static StudentSummary highPerformanceStudent() => const StudentSummary(
        id: 'student-top',
        firstName: 'Alice',
        lastName: 'Johnson',
        studentNumber: '2024002',
        email: 'alice@example.com',
        avatarUrl: 'https://example.com/alice.png',
        xp: 2500,
        level: 15,
        currentStreak: 30,
        booksRead: 12,
        avgProgress: 95.0,
      );

  static List<StudentSummary> studentList() => [
        validStudent(),
        minimalStudent(),
        highPerformanceStudent(),
      ];
}

class StudentBookProgressFixtures {
  StudentBookProgressFixtures._();

  static StudentBookProgress validProgress() => StudentBookProgress(
        bookId: 'book-123',
        bookTitle: 'The Great Adventure',
        bookCoverUrl: 'https://example.com/cover.jpg',
        completionPercentage: 65.0,
        totalReadingTime: 3600,
        completedChapters: 6,
        totalChapters: 10,
        lastReadAt: DateTime.parse('2024-01-15T10:30:00Z'),
      );

  static StudentBookProgress completedProgress() => StudentBookProgress(
        bookId: 'book-456',
        bookTitle: 'Short Stories',
        bookCoverUrl: 'https://example.com/short.jpg',
        completionPercentage: 100.0,
        totalReadingTime: 7200,
        completedChapters: 5,
        totalChapters: 5,
        lastReadAt: DateTime.parse('2024-01-10T15:00:00Z'),
      );

  static StudentBookProgress freshProgress() => const StudentBookProgress(
        bookId: 'book-789',
        bookTitle: 'New Book',
        completionPercentage: 0.0,
        totalReadingTime: 0,
        completedChapters: 0,
        totalChapters: 8,
      );

  static List<StudentBookProgress> progressList() => [
        validProgress(),
        completedProgress(),
        freshProgress(),
      ];
}

class AssignmentFixtures {
  AssignmentFixtures._();

  static Assignment validAssignment() => Assignment(
        id: 'assignment-123',
        teacherId: 'teacher-123',
        classId: 'class-789',
        className: '7-A',
        type: AssignmentType.book,
        title: 'Read Chapter 1-3',
        description: 'Complete chapters 1-3 of The Great Adventure',
        contentConfig: const {'bookId': 'book-123', 'chapters': [1, 2, 3]},
        startDate: DateTime.parse('2024-01-01T00:00:00Z'),
        dueDate: DateTime.parse('2024-01-15T23:59:59Z'),
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        totalStudents: 30,
        completedStudents: 15,
      );

  static Assignment vocabularyAssignment() => Assignment(
        id: 'assignment-vocab',
        teacherId: 'teacher-123',
        classId: 'class-789',
        className: '7-A',
        type: AssignmentType.vocabulary,
        title: 'Learn Unit 5 Words',
        description: 'Complete vocabulary list for Unit 5',
        contentConfig: const {'listId': 'list-123'},
        startDate: DateTime.parse('2024-01-10T00:00:00Z'),
        dueDate: DateTime.parse('2024-01-20T23:59:59Z'),
        createdAt: DateTime.parse('2024-01-10T00:00:00Z'),
        totalStudents: 30,
        completedStudents: 20,
      );

  static Assignment overdueAssignment() => Assignment(
        id: 'assignment-overdue',
        teacherId: 'teacher-123',
        classId: 'class-789',
        className: '7-A',
        type: AssignmentType.book,
        title: 'Past Due Assignment',
        contentConfig: const {'bookId': 'book-456'},
        startDate: DateTime.parse('2023-12-01T00:00:00Z'),
        dueDate: DateTime.parse('2023-12-15T23:59:59Z'),
        createdAt: DateTime.parse('2023-12-01T00:00:00Z'),
        totalStudents: 30,
        completedStudents: 25,
      );

  static List<Assignment> assignmentList() => [
        validAssignment(),
        vocabularyAssignment(),
        overdueAssignment(),
      ];
}

class AssignmentStudentFixtures {
  AssignmentStudentFixtures._();

  static AssignmentStudent pendingStudent() => const AssignmentStudent(
        id: 'as-1',
        studentId: 'student-1',
        studentName: 'John Doe',
        avatarUrl: 'https://example.com/john.png',
        status: AssignmentStatus.pending,
        progress: 0.0,
      );

  static AssignmentStudent inProgressStudent() => AssignmentStudent(
        id: 'as-2',
        studentId: 'student-2',
        studentName: 'Jane Smith',
        avatarUrl: 'https://example.com/jane.png',
        status: AssignmentStatus.inProgress,
        progress: 45.0,
        startedAt: DateTime.parse('2024-01-05T10:00:00Z'),
      );

  static AssignmentStudent completedStudent() => AssignmentStudent(
        id: 'as-3',
        studentId: 'student-3',
        studentName: 'Alice Johnson',
        avatarUrl: 'https://example.com/alice.png',
        status: AssignmentStatus.completed,
        progress: 100.0,
        score: 95.0,
        startedAt: DateTime.parse('2024-01-03T08:00:00Z'),
        completedAt: DateTime.parse('2024-01-10T14:30:00Z'),
      );

  static AssignmentStudent overdueStudent() => AssignmentStudent(
        id: 'as-4',
        studentId: 'student-4',
        studentName: 'Bob Williams',
        status: AssignmentStatus.overdue,
        progress: 30.0,
        startedAt: DateTime.parse('2024-01-02T09:00:00Z'),
      );

  static List<AssignmentStudent> studentList() => [
        pendingStudent(),
        inProgressStudent(),
        completedStudent(),
        overdueStudent(),
      ];
}

class CreateAssignmentDataFixtures {
  CreateAssignmentDataFixtures._();

  static CreateAssignmentData validData() => CreateAssignmentData(
        classId: 'class-789',
        type: AssignmentType.book,
        title: 'Read Chapter 1-3',
        description: 'Complete chapters 1-3',
        contentConfig: const {'bookId': 'book-123', 'chapters': [1, 2, 3]},
        startDate: DateTime.now(),
        dueDate: DateTime.now().add(const Duration(days: 14)),
      );

  static CreateAssignmentData vocabularyData() => CreateAssignmentData(
        classId: 'class-789',
        type: AssignmentType.vocabulary,
        title: 'Unit 5 Vocabulary',
        contentConfig: const {'listId': 'list-123'},
        startDate: DateTime.now(),
        dueDate: DateTime.now().add(const Duration(days: 7)),
      );

  static CreateAssignmentData individualData() => CreateAssignmentData(
        studentIds: const ['student-1', 'student-2', 'student-3'],
        type: AssignmentType.mixed,
        title: 'Individual Assignment',
        contentConfig: const {'bookId': 'book-456', 'listId': 'list-456'},
        startDate: DateTime.now(),
        dueDate: DateTime.now().add(const Duration(days: 10)),
      );
}
