import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:owlio/core/constants/app_constants.dart';
import 'package:owlio/core/errors/failures.dart';
import 'package:owlio/domain/entities/user.dart';
import 'package:owlio/domain/repositories/user_repository.dart';
import 'package:owlio/domain/usecases/user/get_user_by_id_usecase.dart';
import 'package:owlio/domain/usecases/user/update_user_usecase.dart';
import 'package:owlio/domain/usecases/user/add_xp_usecase.dart';
import 'package:owlio/domain/usecases/user/update_streak_usecase.dart';
import 'package:owlio/domain/usecases/user/get_user_stats_usecase.dart';
import 'package:owlio/domain/usecases/user/get_classmates_usecase.dart';
import 'package:owlio/domain/usecases/user/get_weekly_leaderboard_usecase.dart';
import 'package:owlio/domain/usecases/user/get_total_leaderboard_usecase.dart';
import 'package:owlio/domain/entities/leaderboard_entry.dart';
import 'package:owlio_shared/owlio_shared.dart';

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

    test('withSourceId_shouldForwardToRepository', () async {
      // Arrange
      final updatedUser = UserFixtures.userWithAddedXP(addedXP: 50);
      when(mockUserRepository.addXP(
        'user-123', 50,
        source: 'chapter_complete',
        sourceId: 'chapter-uuid-5',
      )).thenAnswer((_) async => Right(updatedUser));

      const params = AddXPParams(
        userId: 'user-123',
        amount: 50,
        source: 'chapter_complete',
        sourceId: 'chapter-uuid-5',
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      verify(mockUserRepository.addXP(
        'user-123', 50,
        source: 'chapter_complete',
        sourceId: 'chapter-uuid-5',
      )).called(1);
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
  // GetWeeklyLeaderboardUseCase Tests
  // ============================================
  group('GetWeeklyLeaderboardUseCase', () {
    late GetWeeklyLeaderboardUseCase usecase;

    setUp(() {
      usecase = GetWeeklyLeaderboardUseCase(mockUserRepository);
    });

    test('withClassScope_shouldReturnClassLeaderboard', () async {
      // Arrange
      final leaderboard = _leaderboardEntries();
      when(mockUserRepository.getWeeklyClassLeaderboard(
        classId: 'class-789',
        limit: 10,
      )).thenAnswer((_) async => Right(leaderboard));

      const params = GetWeeklyLeaderboardParams(
        scope: LeaderboardScope.classScope,
        classId: 'class-789',
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (entries) {
          expect(entries.length, 3);
          expect(entries[0].weeklyXp, greaterThanOrEqualTo(entries[1].weeklyXp));
        },
      );
      verify(mockUserRepository.getWeeklyClassLeaderboard(
        classId: 'class-789',
        limit: 10,
      )).called(1);
    });

    test('withSchoolScope_shouldReturnSchoolLeaderboard', () async {
      // Arrange
      final leaderboard = _leaderboardEntries();
      when(mockUserRepository.getWeeklySchoolLeaderboard(
        schoolId: 'school-456',
        limit: 10,
        leagueTier: null,
      )).thenAnswer((_) async => Right(leaderboard));

      const params = GetWeeklyLeaderboardParams(
        scope: LeaderboardScope.schoolScope,
        schoolId: 'school-456',
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      verify(mockUserRepository.getWeeklySchoolLeaderboard(
        schoolId: 'school-456',
        limit: 10,
        leagueTier: null,
      )).called(1);
    });

    test('withClassScopeAndNoClassId_shouldReturnValidationFailure', () async {
      const params = GetWeeklyLeaderboardParams(
        scope: LeaderboardScope.classScope,
      );

      final result = await usecase(params);

      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('Should return failure'),
      );
    });

    test('withSchoolScopeAndNoSchoolId_shouldReturnValidationFailure', () async {
      const params = GetWeeklyLeaderboardParams(
        scope: LeaderboardScope.schoolScope,
      );

      final result = await usecase(params);

      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('Should return failure'),
      );
    });

    test('withEmptyResult_shouldReturnEmptyList', () async {
      when(mockUserRepository.getWeeklyClassLeaderboard(
        classId: 'empty-class',
        limit: 10,
      )).thenAnswer((_) async => const Right(<LeaderboardEntry>[]));

      const params = GetWeeklyLeaderboardParams(
        scope: LeaderboardScope.classScope,
        classId: 'empty-class',
      );

      final result = await usecase(params);

      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (entries) => expect(entries, isEmpty),
      );
    });
  });

  // ============================================
  // GetTotalLeaderboardUseCase Tests
  // ============================================
  group('GetTotalLeaderboardUseCase', () {
    late GetTotalLeaderboardUseCase usecase;

    setUp(() {
      usecase = GetTotalLeaderboardUseCase(mockUserRepository);
    });

    test('withClassScope_shouldReturnClassLeaderboard', () async {
      final leaderboard = _leaderboardEntries();
      when(mockUserRepository.getTotalClassLeaderboard(
        classId: 'class-789',
        limit: 50,
      )).thenAnswer((_) async => Right(leaderboard));

      const params = GetTotalLeaderboardParams(
        scope: TotalLeaderboardScope.classScope,
        classId: 'class-789',
      );

      final result = await usecase(params);

      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (entries) => expect(entries.length, 3),
      );
    });

    test('withSchoolScope_shouldReturnSchoolLeaderboard', () async {
      final leaderboard = _leaderboardEntries();
      when(mockUserRepository.getTotalSchoolLeaderboard(
        schoolId: 'school-456',
        limit: 50,
      )).thenAnswer((_) async => Right(leaderboard));

      const params = GetTotalLeaderboardParams(
        scope: TotalLeaderboardScope.schoolScope,
        schoolId: 'school-456',
      );

      final result = await usecase(params);

      expect(result.isRight(), true);
      verify(mockUserRepository.getTotalSchoolLeaderboard(
        schoolId: 'school-456',
        limit: 50,
      )).called(1);
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

    test('getWeeklyLeaderboard_withCustomLimit_shouldWork', () async {
      // Arrange
      final usecase = GetWeeklyLeaderboardUseCase(mockUserRepository);
      final leaderboard = _leaderboardEntries();
      when(mockUserRepository.getWeeklyClassLeaderboard(
        classId: 'class-789',
        limit: 5,
      )).thenAnswer((_) async => Right(leaderboard));

      const params = GetWeeklyLeaderboardParams(
        scope: LeaderboardScope.classScope,
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

    test('getWeeklyLeaderboardParams_shouldHaveCorrectDefaults', () {
      // Act
      const params = GetWeeklyLeaderboardParams(
        scope: LeaderboardScope.classScope,
        classId: 'class-1',
      );

      // Assert
      expect(params.scope, LeaderboardScope.classScope);
      expect(params.classId, 'class-1');
      expect(params.schoolId, isNull);
      expect(params.limit, 10);
    });

    test('getTotalLeaderboardParams_shouldHaveCorrectDefaults', () {
      // Act
      const params = GetTotalLeaderboardParams(
        scope: TotalLeaderboardScope.schoolScope,
        schoolId: 'school-1',
      );

      // Assert
      expect(params.scope, TotalLeaderboardScope.schoolScope);
      expect(params.schoolId, 'school-1');
      expect(params.classId, isNull);
      expect(params.limit, 50);
    });
  });
}

/// Helper to create test LeaderboardEntry instances.
List<LeaderboardEntry> _leaderboardEntries() => [
      const LeaderboardEntry(
        userId: 'user-1',
        firstName: 'Pro',
        lastName: 'Gamer',
        totalXp: 5000,
        weeklyXp: 500,
        level: 25,
        rank: 1,
        leagueTier: LeagueTier.gold,
      ),
      const LeaderboardEntry(
        userId: 'user-2',
        firstName: 'John',
        lastName: 'Doe',
        totalXp: 3000,
        weeklyXp: 300,
        level: 15,
        rank: 2,
        leagueTier: LeagueTier.silver,
      ),
      const LeaderboardEntry(
        userId: 'user-3',
        firstName: 'Alice',
        lastName: 'Smith',
        totalXp: 1000,
        weeklyXp: 100,
        level: 5,
        rank: 3,
        leagueTier: LeagueTier.bronze,
      ),
    ];
