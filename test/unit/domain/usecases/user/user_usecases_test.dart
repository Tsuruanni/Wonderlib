import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:readeng/core/constants/app_constants.dart';
import 'package:readeng/core/errors/failures.dart';
import 'package:readeng/domain/entities/user.dart';
import 'package:readeng/domain/repositories/user_repository.dart';
import 'package:readeng/domain/usecases/user/get_user_by_id_usecase.dart';
import 'package:readeng/domain/usecases/user/update_user_usecase.dart';
import 'package:readeng/domain/usecases/user/add_xp_usecase.dart';
import 'package:readeng/domain/usecases/user/update_streak_usecase.dart';
import 'package:readeng/domain/usecases/user/get_user_stats_usecase.dart';
import 'package:readeng/domain/usecases/user/get_classmates_usecase.dart';
import 'package:readeng/domain/usecases/user/get_leaderboard_usecase.dart';

import '../../../../fixtures/user_fixtures.dart';
import 'user_usecases_test.mocks.dart';

@GenerateMocks([UserRepository])
void main() {
  late MockUserRepository mockUserRepository;

  setUp(() {
    mockUserRepository = MockUserRepository();
  });

  // ============================================
  // GetUserByIdUseCase Tests
  // ============================================
  group('GetUserByIdUseCase', () {
    late GetUserByIdUseCase usecase;

    setUp(() {
      usecase = GetUserByIdUseCase(mockUserRepository);
    });

    test('withValidId_shouldReturnUser', () async {
      // Arrange
      final user = UserFixtures.validStudentUser();
      when(mockUserRepository.getUserById('user-123'))
          .thenAnswer((_) async => Right(user));

      const params = GetUserByIdParams(userId: 'user-123');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedUser) {
          expect(returnedUser.id, 'user-123');
          expect(returnedUser.firstName, 'John');
          expect(returnedUser.lastName, 'Doe');
          expect(returnedUser.role, UserRole.student);
        },
      );
    });

    test('withTeacherId_shouldReturnTeacher', () async {
      // Arrange
      final teacher = UserFixtures.validTeacherUser();
      when(mockUserRepository.getUserById('teacher-123'))
          .thenAnswer((_) async => Right(teacher));

      const params = GetUserByIdParams(userId: 'teacher-123');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedUser) {
          expect(returnedUser.role, UserRole.teacher);
        },
      );
    });

    test('withNotFoundId_shouldReturnNotFoundFailure', () async {
      // Arrange
      when(mockUserRepository.getUserById('non-existent'))
          .thenAnswer((_) async => const Left(NotFoundFailure('User not found')));

      const params = GetUserByIdParams(userId: 'non-existent');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<NotFoundFailure>()),
        (_) => fail('Should return failure'),
      );
    });
  });

  // ============================================
  // UpdateUserUseCase Tests
  // ============================================
  group('UpdateUserUseCase', () {
    late UpdateUserUseCase usecase;

    setUp(() {
      usecase = UpdateUserUseCase(mockUserRepository);
    });

    test('withValidUser_shouldReturnUpdatedUser', () async {
      // Arrange
      final user = UserFixtures.validStudentUser();
      when(mockUserRepository.updateUser(user))
          .thenAnswer((_) async => Right(user));

      final params = UpdateUserParams(user: user);

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedUser) {
          expect(returnedUser.id, user.id);
        },
      );
      verify(mockUserRepository.updateUser(user)).called(1);
    });

    test('withServerError_shouldReturnServerFailure', () async {
      // Arrange
      final user = UserFixtures.validStudentUser();
      when(mockUserRepository.updateUser(user))
          .thenAnswer((_) async => const Left(ServerFailure('Update failed')));

      final params = UpdateUserParams(user: user);

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('Should return failure'),
      );
    });
  });

  // ============================================
  // AddXPUseCase Tests
  // ============================================
  group('AddXPUseCase', () {
    late AddXPUseCase usecase;

    setUp(() {
      usecase = AddXPUseCase(mockUserRepository);
    });

    test('withValidParams_shouldReturnUserWithAddedXP', () async {
      // Arrange
      final updatedUser = UserFixtures.userWithAddedXP(addedXP: 50);
      when(mockUserRepository.addXP('user-123', 50))
          .thenAnswer((_) async => Right(updatedUser));

      const params = AddXPParams(userId: 'user-123', amount: 50);

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedUser) {
          expect(returnedUser.xp, 550); // Original 500 + 50
        },
      );
    });

    test('withLargeXPAmount_shouldWork', () async {
      // Arrange
      final updatedUser = UserFixtures.userWithAddedXP(addedXP: 1000);
      when(mockUserRepository.addXP('user-123', 1000))
          .thenAnswer((_) async => Right(updatedUser));

      const params = AddXPParams(userId: 'user-123', amount: 1000);

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedUser) {
          expect(returnedUser.xp, 1500); // Original 500 + 1000
        },
      );
    });

    test('withZeroXP_shouldNotChangeUser', () async {
      // Arrange
      final user = UserFixtures.validStudentUser();
      when(mockUserRepository.addXP('user-123', 0))
          .thenAnswer((_) async => Right(user));

      const params = AddXPParams(userId: 'user-123', amount: 0);

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedUser) {
          expect(returnedUser.xp, 500); // Unchanged
        },
      );
    });

    test('withInvalidUserId_shouldReturnNotFoundFailure', () async {
      // Arrange
      when(mockUserRepository.addXP('non-existent', 50))
          .thenAnswer((_) async => const Left(NotFoundFailure('User not found')));

      const params = AddXPParams(userId: 'non-existent', amount: 50);

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<NotFoundFailure>()),
        (_) => fail('Should return failure'),
      );
    });
  });

  // ============================================
  // UpdateStreakUseCase Tests
  // ============================================
  group('UpdateStreakUseCase', () {
    late UpdateStreakUseCase usecase;

    setUp(() {
      usecase = UpdateStreakUseCase(mockUserRepository);
    });

    test('withValidUserId_shouldReturnUserWithUpdatedStreak', () async {
      // Arrange
      final updatedUser = UserFixtures.userWithUpdatedStreak();
      when(mockUserRepository.updateStreak('user-123'))
          .thenAnswer((_) async => Right(updatedUser));

      const params = UpdateStreakParams(userId: 'user-123');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedUser) {
          expect(returnedUser.currentStreak, 8); // Incremented from 7
          expect(returnedUser.lastActivityDate, isNotNull);
        },
      );
    });

    test('withNewLongestStreak_shouldUpdateLongestStreak', () async {
      // Arrange - User has streak 14 (longest) and we update to 15
      final updatedUser = User(
        id: 'user-123',
        schoolId: 'school-456',
        role: UserRole.student,
        firstName: 'John',
        lastName: 'Doe',
        xp: 500,
        level: 5,
        currentStreak: 15,
        longestStreak: 15, // Updated to match current
        lastActivityDate: DateTime.now(),
        settings: const {},
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        updatedAt: DateTime.now(),
      );
      when(mockUserRepository.updateStreak('user-123'))
          .thenAnswer((_) async => Right(updatedUser));

      const params = UpdateStreakParams(userId: 'user-123');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedUser) {
          expect(returnedUser.currentStreak, returnedUser.longestStreak);
        },
      );
    });

    test('withInvalidUserId_shouldReturnNotFoundFailure', () async {
      // Arrange
      when(mockUserRepository.updateStreak('non-existent'))
          .thenAnswer((_) async => const Left(NotFoundFailure('User not found')));

      const params = UpdateStreakParams(userId: 'non-existent');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<NotFoundFailure>()),
        (_) => fail('Should return failure'),
      );
    });
  });

  // ============================================
  // GetUserStatsUseCase Tests
  // ============================================
  group('GetUserStatsUseCase', () {
    late GetUserStatsUseCase usecase;

    setUp(() {
      usecase = GetUserStatsUseCase(mockUserRepository);
    });

    test('withValidUserId_shouldReturnStats', () async {
      // Arrange
      final stats = UserFixtures.validUserStats();
      when(mockUserRepository.getUserStats('user-123'))
          .thenAnswer((_) async => Right(stats));

      const params = GetUserStatsParams(userId: 'user-123');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedStats) {
          expect(returnedStats['total_xp'], 500);
          expect(returnedStats['current_level'], 5);
          expect(returnedStats['current_streak'], 7);
          expect(returnedStats['books_completed'], 3);
          expect(returnedStats['vocabulary_learned'], 150);
          expect(returnedStats['badges_earned'], 8);
        },
      );
    });

    test('withNewUser_shouldReturnZeroStats', () async {
      // Arrange
      final stats = <String, dynamic>{
        'total_xp': 0,
        'current_level': 1,
        'current_streak': 0,
        'longest_streak': 0,
        'books_completed': 0,
        'chapters_read': 0,
        'total_reading_time': 0,
        'vocabulary_learned': 0,
        'activities_completed': 0,
        'average_score': 0.0,
        'badges_earned': 0,
      };
      when(mockUserRepository.getUserStats('new-user'))
          .thenAnswer((_) async => Right(stats));

      const params = GetUserStatsParams(userId: 'new-user');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedStats) {
          expect(returnedStats['total_xp'], 0);
          expect(returnedStats['books_completed'], 0);
        },
      );
    });

    test('withServerError_shouldReturnServerFailure', () async {
      // Arrange
      when(mockUserRepository.getUserStats('user-123'))
          .thenAnswer((_) async => const Left(ServerFailure('Stats unavailable')));

      const params = GetUserStatsParams(userId: 'user-123');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('Should return failure'),
      );
    });
  });

  // ============================================
  // GetClassmatesUseCase Tests
  // ============================================
  group('GetClassmatesUseCase', () {
    late GetClassmatesUseCase usecase;

    setUp(() {
      usecase = GetClassmatesUseCase(mockUserRepository);
    });

    test('withValidClassId_shouldReturnClassmates', () async {
      // Arrange
      final classmates = UserFixtures.classmatesList();
      when(mockUserRepository.getClassmates('class-789'))
          .thenAnswer((_) async => Right(classmates));

      const params = GetClassmatesParams(classId: 'class-789');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedClassmates) {
          expect(returnedClassmates.length, 3);
          // All should be from same class
          expect(returnedClassmates.every((u) => u.classId == 'class-789'), true);
        },
      );
    });

    test('withEmptyClass_shouldReturnEmptyList', () async {
      // Arrange
      when(mockUserRepository.getClassmates('empty-class'))
          .thenAnswer((_) async => const Right(<User>[]));

      const params = GetClassmatesParams(classId: 'empty-class');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedClassmates) => expect(returnedClassmates, isEmpty),
      );
    });

    test('withInvalidClassId_shouldReturnNotFoundFailure', () async {
      // Arrange
      when(mockUserRepository.getClassmates('non-existent'))
          .thenAnswer((_) async => const Left(NotFoundFailure('Class not found')));

      const params = GetClassmatesParams(classId: 'non-existent');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<NotFoundFailure>()),
        (_) => fail('Should return failure'),
      );
    });
  });

  // ============================================
  // GetLeaderboardUseCase Tests
  // ============================================
  group('GetLeaderboardUseCase', () {
    late GetLeaderboardUseCase usecase;

    setUp(() {
      usecase = GetLeaderboardUseCase(mockUserRepository);
    });

    test('withDefaultParams_shouldReturnTopUsers', () async {
      // Arrange
      final leaderboard = UserFixtures.leaderboardUsers();
      when(mockUserRepository.getLeaderboard(
        schoolId: null,
        classId: null,
        limit: 10,
      )).thenAnswer((_) async => Right(leaderboard));

      const params = GetLeaderboardParams();

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedUsers) {
          expect(returnedUsers.length, 3);
          // Should be sorted by XP (highest first)
          expect(returnedUsers[0].xp, greaterThanOrEqualTo(returnedUsers[1].xp));
        },
      );
      verify(mockUserRepository.getLeaderboard(
        schoolId: null,
        classId: null,
        limit: 10,
      )).called(1);
    });

    test('withSchoolFilter_shouldReturnSchoolLeaderboard', () async {
      // Arrange
      final leaderboard = UserFixtures.leaderboardUsers();
      when(mockUserRepository.getLeaderboard(
        schoolId: 'school-456',
        classId: null,
        limit: 10,
      )).thenAnswer((_) async => Right(leaderboard));

      const params = GetLeaderboardParams(schoolId: 'school-456');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      verify(mockUserRepository.getLeaderboard(
        schoolId: 'school-456',
        classId: null,
        limit: 10,
      )).called(1);
    });

    test('withClassFilter_shouldReturnClassLeaderboard', () async {
      // Arrange
      final leaderboard = UserFixtures.classmatesList();
      when(mockUserRepository.getLeaderboard(
        schoolId: null,
        classId: 'class-789',
        limit: 10,
      )).thenAnswer((_) async => Right(leaderboard));

      const params = GetLeaderboardParams(classId: 'class-789');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedUsers) {
          // All should be from same class
          expect(returnedUsers.every((u) => u.classId == 'class-789'), true);
        },
      );
    });

    test('withCustomLimit_shouldPassLimitToRepository', () async {
      // Arrange
      final leaderboard = [UserFixtures.highXPUser()];
      when(mockUserRepository.getLeaderboard(
        schoolId: null,
        classId: null,
        limit: 1,
      )).thenAnswer((_) async => Right(leaderboard));

      const params = GetLeaderboardParams(limit: 1);

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedUsers) => expect(returnedUsers.length, 1),
      );
      verify(mockUserRepository.getLeaderboard(
        schoolId: null,
        classId: null,
        limit: 1,
      )).called(1);
    });

    test('withNoUsers_shouldReturnEmptyList', () async {
      // Arrange
      when(mockUserRepository.getLeaderboard(
        schoolId: 'new-school',
        classId: null,
        limit: 10,
      )).thenAnswer((_) async => const Right(<User>[]));

      const params = GetLeaderboardParams(schoolId: 'new-school');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedUsers) => expect(returnedUsers, isEmpty),
      );
    });
  });

  // ============================================
  // Edge Cases
  // ============================================
  group('edgeCases', () {
    test('addXP_withNegativeAmount_shouldWork', () async {
      // Arrange - Some systems allow XP deduction
      final usecase = AddXPUseCase(mockUserRepository);
      final user = UserFixtures.validStudentUser();
      when(mockUserRepository.addXP('user-123', -50))
          .thenAnswer((_) async => Right(user));

      const params = AddXPParams(userId: 'user-123', amount: -50);

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
    });

    test('getLeaderboard_withAllFilters_shouldWork', () async {
      // Arrange
      final usecase = GetLeaderboardUseCase(mockUserRepository);
      final leaderboard = UserFixtures.classmatesList();
      when(mockUserRepository.getLeaderboard(
        schoolId: 'school-456',
        classId: 'class-789',
        limit: 5,
      )).thenAnswer((_) async => Right(leaderboard));

      const params = GetLeaderboardParams(
        schoolId: 'school-456',
        classId: 'class-789',
        limit: 5,
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
    });

    test('getUserStats_shouldIncludeAllMetrics', () async {
      // Arrange
      final usecase = GetUserStatsUseCase(mockUserRepository);
      final stats = UserFixtures.validUserStats();
      when(mockUserRepository.getUserStats('user-123'))
          .thenAnswer((_) async => Right(stats));

      const params = GetUserStatsParams(userId: 'user-123');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedStats) {
          // Verify all expected keys exist
          expect(returnedStats.containsKey('total_xp'), true);
          expect(returnedStats.containsKey('current_level'), true);
          expect(returnedStats.containsKey('current_streak'), true);
          expect(returnedStats.containsKey('longest_streak'), true);
          expect(returnedStats.containsKey('books_completed'), true);
          expect(returnedStats.containsKey('chapters_read'), true);
          expect(returnedStats.containsKey('total_reading_time'), true);
          expect(returnedStats.containsKey('vocabulary_learned'), true);
          expect(returnedStats.containsKey('activities_completed'), true);
          expect(returnedStats.containsKey('average_score'), true);
          expect(returnedStats.containsKey('badges_earned'), true);
        },
      );
    });
  });

  // ============================================
  // Params Tests
  // ============================================
  group('paramsTests', () {
    test('getUserByIdParams_shouldStoreUserId', () {
      // Act
      const params = GetUserByIdParams(userId: 'test-user');

      // Assert
      expect(params.userId, 'test-user');
    });

    test('updateUserParams_shouldStoreUser', () {
      // Arrange
      final user = UserFixtures.validStudentUser();

      // Act
      final params = UpdateUserParams(user: user);

      // Assert
      expect(params.user.id, user.id);
    });

    test('addXPParams_shouldStoreUserIdAndAmount', () {
      // Act
      const params = AddXPParams(userId: 'test-user', amount: 100);

      // Assert
      expect(params.userId, 'test-user');
      expect(params.amount, 100);
    });

    test('updateStreakParams_shouldStoreUserId', () {
      // Act
      const params = UpdateStreakParams(userId: 'test-user');

      // Assert
      expect(params.userId, 'test-user');
    });

    test('getUserStatsParams_shouldStoreUserId', () {
      // Act
      const params = GetUserStatsParams(userId: 'test-user');

      // Assert
      expect(params.userId, 'test-user');
    });

    test('getClassmatesParams_shouldStoreClassId', () {
      // Act
      const params = GetClassmatesParams(classId: 'test-class');

      // Assert
      expect(params.classId, 'test-class');
    });

    test('getLeaderboardParams_shouldHaveCorrectDefaults', () {
      // Act
      const params = GetLeaderboardParams();

      // Assert
      expect(params.schoolId, isNull);
      expect(params.classId, isNull);
      expect(params.limit, 10);
    });

    test('getLeaderboardParams_withCustomValues_shouldStoreAll', () {
      // Act
      const params = GetLeaderboardParams(
        schoolId: 'school-1',
        classId: 'class-1',
        limit: 20,
      );

      // Assert
      expect(params.schoolId, 'school-1');
      expect(params.classId, 'class-1');
      expect(params.limit, 20);
    });
  });
}
