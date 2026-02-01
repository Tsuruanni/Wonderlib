import 'package:readeng/core/constants/app_constants.dart';
import 'package:readeng/domain/entities/user.dart';

/// Test fixtures for User-related tests
class UserFixtures {
  UserFixtures._();

  // ============================================
  // JSON Fixtures
  // ============================================

  /// Valid complete user JSON from Supabase
  static Map<String, dynamic> validUserJson() => {
        'id': 'user-123',
        'school_id': 'school-456',
        'class_id': 'class-789',
        'role': 'student',
        'student_number': '2024001',
        'first_name': 'John',
        'last_name': 'Doe',
        'email': 'john@example.com',
        'avatar_url': 'https://example.com/avatar.png',
        'xp': 500,
        'level': 5,
        'current_streak': 7,
        'longest_streak': 14,
        'last_activity_date': '2024-01-15T10:30:00Z',
        'settings': {'theme': 'dark', 'notifications': true},
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-15T10:30:00Z',
      };

  /// Minimal valid user JSON (only required fields)
  static Map<String, dynamic> minimalUserJson() => {
        'id': 'user-123',
        'school_id': 'school-456',
        'first_name': 'John',
        'last_name': 'Doe',
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      };

  /// Teacher user JSON
  static Map<String, dynamic> teacherUserJson() => {
        'id': 'teacher-123',
        'school_id': 'school-456',
        'role': 'teacher',
        'first_name': 'Jane',
        'last_name': 'Smith',
        'email': 'jane@school.com',
        'xp': 0,
        'level': 1,
        'current_streak': 0,
        'longest_streak': 0,
        'settings': <String, dynamic>{},
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      };

  /// User JSON with null optional fields
  static Map<String, dynamic> userJsonWithNulls() => {
        'id': 'user-123',
        'school_id': 'school-456',
        'class_id': null,
        'role': 'student',
        'student_number': null,
        'first_name': 'John',
        'last_name': 'Doe',
        'email': null,
        'avatar_url': null,
        'xp': null,
        'level': null,
        'current_streak': null,
        'longest_streak': null,
        'last_activity_date': null,
        'settings': null,
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      };

  /// Invalid JSON - missing required field
  static Map<String, dynamic> invalidUserJsonMissingId() => {
        'school_id': 'school-456',
        'first_name': 'John',
        'last_name': 'Doe',
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      };

  /// Invalid JSON - wrong date format
  static Map<String, dynamic> invalidUserJsonBadDate() => {
        'id': 'user-123',
        'school_id': 'school-456',
        'first_name': 'John',
        'last_name': 'Doe',
        'created_at': 'not-a-date',
        'updated_at': '2024-01-01T00:00:00Z',
      };

  // ============================================
  // Entity Fixtures
  // ============================================

  /// Valid student user entity
  static User validStudentUser() => User(
        id: 'user-123',
        schoolId: 'school-456',
        classId: 'class-789',
        role: UserRole.student,
        studentNumber: '2024001',
        firstName: 'John',
        lastName: 'Doe',
        email: 'john@example.com',
        avatarUrl: 'https://example.com/avatar.png',
        xp: 500,
        level: 5,
        currentStreak: 7,
        longestStreak: 14,
        lastActivityDate: DateTime.parse('2024-01-15T10:30:00Z'),
        settings: const {'theme': 'dark', 'notifications': true},
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2024-01-15T10:30:00Z'),
      );

  /// Valid teacher user entity
  static User validTeacherUser() => User(
        id: 'teacher-123',
        schoolId: 'school-456',
        role: UserRole.teacher,
        firstName: 'Jane',
        lastName: 'Smith',
        email: 'jane@school.com',
        xp: 0,
        level: 1,
        currentStreak: 0,
        longestStreak: 0,
        settings: const {},
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2024-01-01T00:00:00Z'),
      );

  /// Minimal user entity (defaults for optional fields)
  static User minimalUser() => User(
        id: 'user-123',
        schoolId: 'school-456',
        role: UserRole.student,
        firstName: 'John',
        lastName: 'Doe',
        xp: 0,
        level: 1,
        currentStreak: 0,
        longestStreak: 0,
        settings: const {},
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2024-01-01T00:00:00Z'),
      );

  /// User with high XP (for level testing)
  static User highXPUser() => User(
        id: 'user-high-xp',
        schoolId: 'school-456',
        role: UserRole.student,
        firstName: 'Pro',
        lastName: 'Gamer',
        xp: 5000,
        level: 25,
        currentStreak: 30,
        longestStreak: 60,
        settings: const {},
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2024-01-15T10:30:00Z'),
      );

  /// User with updated XP (after XP addition)
  static User userWithAddedXP({int addedXP = 50}) => User(
        id: 'user-123',
        schoolId: 'school-456',
        classId: 'class-789',
        role: UserRole.student,
        studentNumber: '2024001',
        firstName: 'John',
        lastName: 'Doe',
        email: 'john@example.com',
        avatarUrl: 'https://example.com/avatar.png',
        xp: 500 + addedXP,
        level: 5,
        currentStreak: 7,
        longestStreak: 14,
        lastActivityDate: DateTime.parse('2024-01-15T10:30:00Z'),
        settings: const {'theme': 'dark', 'notifications': true},
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        updatedAt: DateTime.now(),
      );

  /// User with updated streak
  static User userWithUpdatedStreak() => User(
        id: 'user-123',
        schoolId: 'school-456',
        classId: 'class-789',
        role: UserRole.student,
        studentNumber: '2024001',
        firstName: 'John',
        lastName: 'Doe',
        email: 'john@example.com',
        avatarUrl: 'https://example.com/avatar.png',
        xp: 500,
        level: 5,
        currentStreak: 8, // Incremented from 7
        longestStreak: 14,
        lastActivityDate: DateTime.now(),
        settings: const {'theme': 'dark', 'notifications': true},
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        updatedAt: DateTime.now(),
      );

  /// User stats map
  static Map<String, dynamic> validUserStats() => {
        'total_xp': 500,
        'current_level': 5,
        'current_streak': 7,
        'longest_streak': 14,
        'books_completed': 3,
        'chapters_read': 25,
        'total_reading_time': 7200, // 2 hours in seconds
        'vocabulary_learned': 150,
        'activities_completed': 45,
        'average_score': 85.5,
        'badges_earned': 8,
      };

  /// Leaderboard users list
  static List<User> leaderboardUsers() => [
        highXPUser(),
        validStudentUser(),
        minimalUser(),
      ];

  /// Classmates list
  static List<User> classmatesList() => [
        validStudentUser(),
        User(
          id: 'classmate-1',
          schoolId: 'school-456',
          classId: 'class-789',
          role: UserRole.student,
          studentNumber: '2024002',
          firstName: 'Alice',
          lastName: 'Johnson',
          xp: 750,
          level: 7,
          currentStreak: 5,
          longestStreak: 10,
          settings: const {},
          createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
          updatedAt: DateTime.parse('2024-01-15T10:30:00Z'),
        ),
        User(
          id: 'classmate-2',
          schoolId: 'school-456',
          classId: 'class-789',
          role: UserRole.student,
          studentNumber: '2024003',
          firstName: 'Bob',
          lastName: 'Williams',
          xp: 300,
          level: 3,
          currentStreak: 2,
          longestStreak: 5,
          settings: const {},
          createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
          updatedAt: DateTime.parse('2024-01-15T10:30:00Z'),
        ),
      ];
}
