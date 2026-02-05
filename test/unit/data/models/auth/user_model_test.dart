import 'package:flutter_test/flutter_test.dart';
import 'package:readeng/core/constants/app_constants.dart';
import 'package:readeng/data/models/auth/user_model.dart';
import 'package:readeng/domain/entities/user.dart';

import '../../../../fixtures/user_fixtures.dart';

void main() {
  group('UserModel', () {
    // ============================================
    // fromJson Tests
    // ============================================
    group('fromJson', () {
      test('withValidData_shouldCreateModel', () {
        // Arrange
        final json = UserFixtures.validUserJson();

        // Act
        final model = UserModel.fromJson(json);

        // Assert
        expect(model.id, 'user-123');
        expect(model.schoolId, 'school-456');
        expect(model.classId, 'class-789');
        expect(model.role, UserRole.student);
        expect(model.studentNumber, '2024001');
        expect(model.firstName, 'John');
        expect(model.lastName, 'Doe');
        expect(model.email, 'john@example.com');
        expect(model.avatarUrl, 'https://example.com/avatar.png');
        expect(model.xp, 500);
        expect(model.level, 5);
        expect(model.currentStreak, 7);
        expect(model.longestStreak, 14);
        expect(model.lastActivityDate, isNotNull);
        expect(model.settings, {'theme': 'dark', 'notifications': true});
      });

      test('withMinimalData_shouldUseDefaults', () {
        // Arrange
        final json = UserFixtures.minimalUserJson();

        // Act
        final model = UserModel.fromJson(json);

        // Assert
        expect(model.id, 'user-123');
        expect(model.schoolId, 'school-456');
        expect(model.classId, isNull);
        expect(model.role, UserRole.student); // default
        expect(model.studentNumber, isNull);
        expect(model.xp, 0); // default
        expect(model.level, 1); // default
        expect(model.currentStreak, 0); // default
        expect(model.longestStreak, 0); // default
        expect(model.settings, isEmpty); // default empty map
      });

      test('withNullOptionalFields_shouldUseDefaults', () {
        // Arrange
        final json = UserFixtures.userJsonWithNulls();

        // Act
        final model = UserModel.fromJson(json);

        // Assert
        expect(model.classId, isNull);
        expect(model.studentNumber, isNull);
        expect(model.email, isNull);
        expect(model.avatarUrl, isNull);
        expect(model.xp, 0);
        expect(model.level, 1);
        expect(model.lastActivityDate, isNull);
        expect(model.settings, isEmpty);
      });

      test('withTeacherRole_shouldParseCorrectly', () {
        // Arrange
        final json = UserFixtures.teacherUserJson();

        // Act
        final model = UserModel.fromJson(json);

        // Assert
        expect(model.role, UserRole.teacher);
      });

      test('withUnknownRole_shouldDefaultToStudent', () {
        // Arrange
        final json = UserFixtures.validUserJson();
        json['role'] = 'unknown_role';

        // Act
        final model = UserModel.fromJson(json);

        // Assert
        expect(model.role, UserRole.student);
      });

      test('withMissingId_shouldThrowTypeError', () {
        // Arrange
        final json = UserFixtures.invalidUserJsonMissingId();

        // Act & Assert
        expect(
          () => UserModel.fromJson(json),
          throwsA(isA<TypeError>()),
        );
      });

      test('withInvalidDateFormat_shouldThrowFormatException', () {
        // Arrange
        final json = UserFixtures.invalidUserJsonBadDate();

        // Act & Assert
        expect(
          () => UserModel.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });

      test('withEmptySchoolId_shouldSetEmptyString', () {
        // Arrange
        final json = UserFixtures.minimalUserJson();
        json['school_id'] = null;

        // Act
        final model = UserModel.fromJson(json);

        // Assert
        expect(model.schoolId, '');
      });
    });

    // ============================================
    // toJson Tests
    // ============================================
    group('toJson', () {
      test('always_shouldIncludeAllFields', () {
        // Arrange
        final model = UserModel(
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
          settings: const {'theme': 'dark'},
          createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
          updatedAt: DateTime.parse('2024-01-15T10:30:00Z'),
        );

        // Act
        final json = model.toJson();

        // Assert
        expect(json['id'], 'user-123');
        expect(json['school_id'], 'school-456');
        expect(json['class_id'], 'class-789');
        expect(json['role'], 'student');
        expect(json['student_number'], '2024001');
        expect(json['first_name'], 'John');
        expect(json['last_name'], 'Doe');
        expect(json['email'], 'john@example.com');
        expect(json['avatar_url'], 'https://example.com/avatar.png');
        expect(json['xp'], 500);
        expect(json['level'], 5);
        expect(json['current_streak'], 7);
        expect(json['longest_streak'], 14);
        expect(json['last_activity_date'], isNotNull);
        expect(json['settings'], {'theme': 'dark'});
        expect(json['created_at'], isNotNull);
        expect(json['updated_at'], isNotNull);
      });

      test('withNullOptionalFields_shouldIncludeNulls', () {
        // Arrange
        final model = UserModel(
          id: 'user-123',
          schoolId: 'school-456',
          role: UserRole.student,
          firstName: 'John',
          lastName: 'Doe',
          createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
          updatedAt: DateTime.parse('2024-01-01T00:00:00Z'),
        );

        // Act
        final json = model.toJson();

        // Assert
        expect(json.containsKey('class_id'), true);
        expect(json['class_id'], isNull);
        expect(json.containsKey('email'), true);
        expect(json['email'], isNull);
      });
    });

    // ============================================
    // toEntity Tests
    // ============================================
    group('toEntity', () {
      test('always_shouldMapAllFieldsCorrectly', () {
        // Arrange
        final model = UserModel.fromJson(UserFixtures.validUserJson());

        // Act
        final entity = model.toEntity();

        // Assert
        expect(entity, isA<User>());
        expect(entity.id, model.id);
        expect(entity.schoolId, model.schoolId);
        expect(entity.classId, model.classId);
        expect(entity.role, model.role);
        expect(entity.studentNumber, model.studentNumber);
        expect(entity.firstName, model.firstName);
        expect(entity.lastName, model.lastName);
        expect(entity.email, model.email);
        expect(entity.avatarUrl, model.avatarUrl);
        expect(entity.xp, model.xp);
        expect(entity.level, model.level);
        expect(entity.currentStreak, model.currentStreak);
        expect(entity.longestStreak, model.longestStreak);
        expect(entity.lastActivityDate, model.lastActivityDate);
        expect(entity.settings, model.settings);
        expect(entity.createdAt, model.createdAt);
        expect(entity.updatedAt, model.updatedAt);
      });

      test('roundTrip_jsonToEntityAndBack_shouldPreserveData', () {
        // Arrange
        final originalJson = UserFixtures.validUserJson();

        // Act
        final model = UserModel.fromJson(originalJson);
        final entity = model.toEntity();
        final modelFromEntity = UserModel.fromEntity(entity);
        final resultJson = modelFromEntity.toJson();

        // Assert
        expect(resultJson['id'], originalJson['id']);
        expect(resultJson['school_id'], originalJson['school_id']);
        expect(resultJson['first_name'], originalJson['first_name']);
        expect(resultJson['last_name'], originalJson['last_name']);
        expect(resultJson['xp'], originalJson['xp']);
        expect(resultJson['level'], originalJson['level']);
      });
    });

    // ============================================
    // fromEntity Tests
    // ============================================
    group('fromEntity', () {
      test('always_shouldMapAllFieldsCorrectly', () {
        // Arrange
        final entity = UserFixtures.validStudentUser();

        // Act
        final model = UserModel.fromEntity(entity);

        // Assert
        expect(model.id, entity.id);
        expect(model.schoolId, entity.schoolId);
        expect(model.classId, entity.classId);
        expect(model.role, entity.role);
        expect(model.studentNumber, entity.studentNumber);
        expect(model.firstName, entity.firstName);
        expect(model.lastName, entity.lastName);
        expect(model.email, entity.email);
        expect(model.avatarUrl, entity.avatarUrl);
        expect(model.xp, entity.xp);
        expect(model.level, entity.level);
        expect(model.currentStreak, entity.currentStreak);
        expect(model.longestStreak, entity.longestStreak);
        expect(model.lastActivityDate, entity.lastActivityDate);
        expect(model.settings, entity.settings);
        expect(model.createdAt, entity.createdAt);
        expect(model.updatedAt, entity.updatedAt);
      });
    });

    // ============================================
    // Edge Cases
    // ============================================
    group('edgeCases', () {
      test('withEmptyFirstName_shouldAccept', () {
        // Arrange
        final json = UserFixtures.minimalUserJson();
        json['first_name'] = '';

        // Act
        final model = UserModel.fromJson(json);

        // Assert
        expect(model.firstName, '');
      });

      test('withVeryHighXP_shouldAccept', () {
        // Arrange
        final json = UserFixtures.validUserJson();
        json['xp'] = 999999999;

        // Act
        final model = UserModel.fromJson(json);

        // Assert
        expect(model.xp, 999999999);
      });

      test('withNegativeXP_shouldAccept', () {
        // Arrange - edge case that shouldn't happen but model should handle
        final json = UserFixtures.validUserJson();
        json['xp'] = -100;

        // Act
        final model = UserModel.fromJson(json);

        // Assert
        expect(model.xp, -100);
      });

      test('withSpecialCharactersInName_shouldAccept', () {
        // Arrange
        final json = UserFixtures.minimalUserJson();
        json['first_name'] = "O'Brien";
        json['last_name'] = 'Müller-Schmidt';

        // Act
        final model = UserModel.fromJson(json);

        // Assert
        expect(model.firstName, "O'Brien");
        expect(model.lastName, 'Müller-Schmidt');
      });

      test('withEmptySettings_shouldReturnEmptyMap', () {
        // Arrange
        final json = UserFixtures.minimalUserJson();
        json['settings'] = <String, dynamic>{};

        // Act
        final model = UserModel.fromJson(json);

        // Assert
        expect(model.settings, isEmpty);
        expect(model.settings, isA<Map<String, dynamic>>());
      });
    });
  });
}
