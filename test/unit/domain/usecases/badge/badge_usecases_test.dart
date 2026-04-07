import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:owlio/core/errors/failures.dart';
import 'package:owlio/domain/entities/badge.dart';
import 'package:owlio/domain/repositories/badge_repository.dart';
import 'package:owlio/domain/usecases/badge/get_user_badges_usecase.dart';
import 'package:owlio/domain/usecases/badge/get_recently_earned_usecase.dart';

import '../../../../fixtures/badge_fixtures.dart';
import 'badge_usecases_test.mocks.dart';

@GenerateMocks([BadgeRepository])
void main() {
  late MockBadgeRepository mockBadgeRepository;

  setUp(() {
    mockBadgeRepository = MockBadgeRepository();
  });

  // ============================================
  // GetUserBadgesUseCase Tests
  // ============================================
  group('GetUserBadgesUseCase', () {
    late GetUserBadgesUseCase usecase;

    setUp(() {
      usecase = GetUserBadgesUseCase(mockBadgeRepository);
    });

    test('withValidUserId_shouldReturnUserBadges', () async {
      // Arrange
      final userBadges = UserBadgeFixtures.userBadgeList();
      when(mockBadgeRepository.getUserBadges('user-123'))
          .thenAnswer((_) async => Right(userBadges));

      const params = GetUserBadgesParams(userId: 'user-123');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedBadges) {
          expect(returnedBadges.length, 3);
          expect(returnedBadges[0].userId, 'user-123');
          expect(returnedBadges[0].badge, isNotNull);
        },
      );
    });

    test('withNewUser_shouldReturnEmptyList', () async {
      // Arrange
      when(mockBadgeRepository.getUserBadges('new-user'))
          .thenAnswer((_) async => const Right(<UserBadge>[]));

      const params = GetUserBadgesParams(userId: 'new-user');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedBadges) => expect(returnedBadges, isEmpty),
      );
    });

    test('withServerError_shouldReturnServerFailure', () async {
      // Arrange
      when(mockBadgeRepository.getUserBadges('user-123'))
          .thenAnswer((_) async => const Left(ServerFailure('Server error')));

      const params = GetUserBadgesParams(userId: 'user-123');

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
  // GetRecentlyEarnedUseCase Tests
  // ============================================
  group('GetRecentlyEarnedUseCase', () {
    late GetRecentlyEarnedUseCase usecase;

    setUp(() {
      usecase = GetRecentlyEarnedUseCase(mockBadgeRepository);
    });

    test('withDefaultLimit_shouldReturnRecentBadges', () async {
      // Arrange
      final badges = [
        BadgeFixtures.streakBadge(),
        BadgeFixtures.validBadge(),
        BadgeFixtures.xpBadge(),
      ];
      when(mockBadgeRepository.getRecentlyEarned(
        userId: 'user-123',
        limit: 5,
      )).thenAnswer((_) async => Right(badges));

      const params = GetRecentlyEarnedParams(userId: 'user-123');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedBadges) {
          expect(returnedBadges.length, 3);
        },
      );
      verify(mockBadgeRepository.getRecentlyEarned(
        userId: 'user-123',
        limit: 5,
      )).called(1);
    });

    test('withCustomLimit_shouldPassLimitToRepository', () async {
      // Arrange
      final badges = [BadgeFixtures.validBadge()];
      when(mockBadgeRepository.getRecentlyEarned(
        userId: 'user-123',
        limit: 1,
      )).thenAnswer((_) async => Right(badges));

      const params = GetRecentlyEarnedParams(userId: 'user-123', limit: 1);

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedBadges) => expect(returnedBadges.length, 1),
      );
      verify(mockBadgeRepository.getRecentlyEarned(
        userId: 'user-123',
        limit: 1,
      )).called(1);
    });

    test('withNoRecentBadges_shouldReturnEmptyList', () async {
      // Arrange
      when(mockBadgeRepository.getRecentlyEarned(
        userId: 'new-user',
        limit: 5,
      )).thenAnswer((_) async => const Right(<Badge>[]));

      const params = GetRecentlyEarnedParams(userId: 'new-user');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedBadges) => expect(returnedBadges, isEmpty),
      );
    });
  });

  // ============================================
  // Edge Cases
  // ============================================
  group('edgeCases', () {
    test('getUserBadges_withAllBadgeTypes_shouldReturnCorrectTypes', () async {
      // Arrange
      final usecase = GetUserBadgesUseCase(mockBadgeRepository);
      final userBadges = UserBadgeFixtures.userBadgeList();
      when(mockBadgeRepository.getUserBadges('user-123'))
          .thenAnswer((_) async => Right(userBadges));

      const params = GetUserBadgesParams(userId: 'user-123');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedBadges) {
          // Check different badge types are included
          final types = returnedBadges.map((ub) => ub.badge.conditionType).toSet();
          expect(types.length, greaterThan(1));
        },
      );
    });

  });

  // ============================================
  // Params Tests
  // ============================================
  group('paramsTests', () {
    test('getUserBadgesParams_shouldStoreUserId', () {
      // Act
      const params = GetUserBadgesParams(userId: 'test-user');

      // Assert
      expect(params.userId, 'test-user');
    });

    test('getRecentlyEarnedParams_shouldHaveCorrectDefaults', () {
      // Act
      const params = GetRecentlyEarnedParams(userId: 'test-user');

      // Assert
      expect(params.userId, 'test-user');
      expect(params.limit, 5);
    });

    test('getRecentlyEarnedParams_withCustomLimit_shouldStoreLimit', () {
      // Act
      const params = GetRecentlyEarnedParams(userId: 'test-user', limit: 10);

      // Assert
      expect(params.limit, 10);
    });
  });
}
