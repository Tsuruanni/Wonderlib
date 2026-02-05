import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:readeng/core/errors/failures.dart';
import 'package:readeng/domain/entities/badge.dart';
import 'package:readeng/domain/repositories/badge_repository.dart';
import 'package:readeng/domain/usecases/badge/get_all_badges_usecase.dart';
import 'package:readeng/domain/usecases/badge/get_badge_by_id_usecase.dart';
import 'package:readeng/domain/usecases/badge/get_user_badges_usecase.dart';
import 'package:readeng/domain/usecases/badge/award_badge_usecase.dart';
import 'package:readeng/domain/usecases/badge/check_earnable_badges_usecase.dart';
import 'package:readeng/domain/usecases/badge/get_recently_earned_usecase.dart';
import 'package:readeng/domain/usecases/usecase.dart';

import '../../../../fixtures/badge_fixtures.dart';
import 'badge_usecases_test.mocks.dart';

@GenerateMocks([BadgeRepository])
void main() {
  late MockBadgeRepository mockBadgeRepository;

  setUp(() {
    mockBadgeRepository = MockBadgeRepository();
  });

  // ============================================
  // GetAllBadgesUseCase Tests
  // ============================================
  group('GetAllBadgesUseCase', () {
    late GetAllBadgesUseCase usecase;

    setUp(() {
      usecase = GetAllBadgesUseCase(mockBadgeRepository);
    });

    test('withNoParams_shouldReturnAllBadges', () async {
      // Arrange
      final badges = BadgeFixtures.badgeList();
      when(mockBadgeRepository.getAllBadges())
          .thenAnswer((_) async => Right(badges));

      // Act
      final result = await usecase(const NoParams());

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedBadges) {
          expect(returnedBadges.length, 4);
          expect(returnedBadges[0].name, 'First Steps');
        },
      );
      verify(mockBadgeRepository.getAllBadges()).called(1);
    });

    test('withNoBadges_shouldReturnEmptyList', () async {
      // Arrange
      when(mockBadgeRepository.getAllBadges())
          .thenAnswer((_) async => const Right(<Badge>[]));

      // Act
      final result = await usecase(const NoParams());

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedBadges) => expect(returnedBadges, isEmpty),
      );
    });

    test('withServerError_shouldReturnServerFailure', () async {
      // Arrange
      when(mockBadgeRepository.getAllBadges())
          .thenAnswer((_) async => const Left(ServerFailure('Server error')));

      // Act
      final result = await usecase(const NoParams());

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('Should return failure'),
      );
    });
  });

  // ============================================
  // GetBadgeByIdUseCase Tests
  // ============================================
  group('GetBadgeByIdUseCase', () {
    late GetBadgeByIdUseCase usecase;

    setUp(() {
      usecase = GetBadgeByIdUseCase(mockBadgeRepository);
    });

    test('withValidId_shouldReturnBadge', () async {
      // Arrange
      final badge = BadgeFixtures.validBadge();
      when(mockBadgeRepository.getBadgeById('badge-123'))
          .thenAnswer((_) async => Right(badge));

      const params = GetBadgeByIdParams(badgeId: 'badge-123');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedBadge) {
          expect(returnedBadge.id, 'badge-123');
          expect(returnedBadge.name, 'First Steps');
          expect(returnedBadge.conditionType, BadgeConditionType.booksCompleted);
        },
      );
    });

    test('withXpBadgeId_shouldReturnXpBadge', () async {
      // Arrange
      final badge = BadgeFixtures.xpBadge();
      when(mockBadgeRepository.getBadgeById('badge-xp-100'))
          .thenAnswer((_) async => Right(badge));

      const params = GetBadgeByIdParams(badgeId: 'badge-xp-100');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedBadge) {
          expect(returnedBadge.conditionType, BadgeConditionType.xpTotal);
          expect(returnedBadge.conditionValue, 100);
        },
      );
    });

    test('withNotFoundId_shouldReturnNotFoundFailure', () async {
      // Arrange
      when(mockBadgeRepository.getBadgeById('non-existent'))
          .thenAnswer((_) async => const Left(NotFoundFailure('Badge not found')));

      const params = GetBadgeByIdParams(badgeId: 'non-existent');

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
          expect(returnedBadges[0].odId, 'user-123');
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
  // AwardBadgeUseCase Tests
  // ============================================
  group('AwardBadgeUseCase', () {
    late AwardBadgeUseCase usecase;

    setUp(() {
      usecase = AwardBadgeUseCase(mockBadgeRepository);
    });

    test('withValidParams_shouldReturnAwardedBadge', () async {
      // Arrange
      final userBadge = UserBadgeFixtures.newUserBadge();
      when(mockBadgeRepository.awardBadge(
        userId: 'user-123',
        badgeId: 'badge-vocab-50',
      )).thenAnswer((_) async => Right(userBadge));

      const params = AwardBadgeParams(
        userId: 'user-123',
        badgeId: 'badge-vocab-50',
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedUserBadge) {
          expect(returnedUserBadge.odId, 'user-123');
          expect(returnedUserBadge.badgeId, 'badge-vocab-50');
          expect(returnedUserBadge.badge, isNotNull);
          expect(returnedUserBadge.earnedAt, isNotNull);
        },
      );
    });

    test('withAlreadyEarnedBadge_shouldReturnConflictFailure', () async {
      // Arrange
      when(mockBadgeRepository.awardBadge(
        userId: 'user-123',
        badgeId: 'badge-123',
      )).thenAnswer((_) async => const Left(ServerFailure('Badge already earned')));

      const params = AwardBadgeParams(
        userId: 'user-123',
        badgeId: 'badge-123',
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('Should return failure'),
      );
    });

    test('withInvalidBadgeId_shouldReturnNotFoundFailure', () async {
      // Arrange
      when(mockBadgeRepository.awardBadge(
        userId: 'user-123',
        badgeId: 'non-existent',
      )).thenAnswer((_) async => const Left(NotFoundFailure('Badge not found')));

      const params = AwardBadgeParams(
        userId: 'user-123',
        badgeId: 'non-existent',
      );

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
  // CheckEarnableBadgesUseCase Tests
  // ============================================
  group('CheckEarnableBadgesUseCase', () {
    late CheckEarnableBadgesUseCase usecase;

    setUp(() {
      usecase = CheckEarnableBadgesUseCase(mockBadgeRepository);
    });

    test('withValidUserId_shouldReturnEarnableBadges', () async {
      // Arrange
      final badges = BadgeFixtures.earnableBadges();
      when(mockBadgeRepository.checkEarnableBadges('user-123'))
          .thenAnswer((_) async => Right(badges));

      const params = CheckEarnableBadgesParams(userId: 'user-123');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedBadges) {
          expect(returnedBadges.length, 2);
          // All returned badges should be earnable
          expect(returnedBadges.every((b) => b.isActive), true);
        },
      );
    });

    test('withNoEarnableBadges_shouldReturnEmptyList', () async {
      // Arrange
      when(mockBadgeRepository.checkEarnableBadges('user-all-badges'))
          .thenAnswer((_) async => const Right(<Badge>[]));

      const params = CheckEarnableBadgesParams(userId: 'user-all-badges');

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
      when(mockBadgeRepository.checkEarnableBadges('user-123'))
          .thenAnswer((_) async => const Left(ServerFailure('Server error')));

      const params = CheckEarnableBadgesParams(userId: 'user-123');

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
    test('getAllBadges_withManyBadges_shouldReturnAll', () async {
      // Arrange
      final usecase = GetAllBadgesUseCase(mockBadgeRepository);
      final badges = List.generate(
        50,
        (i) => Badge(
          id: 'badge-$i',
          name: 'Badge $i',
          slug: 'badge-$i',
          conditionType: BadgeConditionType.xpTotal,
          conditionValue: i * 100,
          createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        ),
      );
      when(mockBadgeRepository.getAllBadges())
          .thenAnswer((_) async => Right(badges));

      // Act
      final result = await usecase(const NoParams());

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedBadges) => expect(returnedBadges.length, 50),
      );
    });

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

    test('awardBadge_shouldReturnBadgeWithCorrectEarnedAt', () async {
      // Arrange
      final usecase = AwardBadgeUseCase(mockBadgeRepository);
      final userBadge = UserBadgeFixtures.newUserBadge();
      when(mockBadgeRepository.awardBadge(
        userId: 'user-123',
        badgeId: 'badge-vocab-50',
      )).thenAnswer((_) async => Right(userBadge));

      const params = AwardBadgeParams(
        userId: 'user-123',
        badgeId: 'badge-vocab-50',
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedUserBadge) {
          // Earned at should be recent (within last minute)
          expect(
            returnedUserBadge.earnedAt.isAfter(
              DateTime.now().subtract(const Duration(minutes: 1)),
            ),
            true,
          );
        },
      );
    });
  });

  // ============================================
  // Params Tests
  // ============================================
  group('paramsTests', () {
    test('getBadgeByIdParams_shouldStoreBadgeId', () {
      // Act
      const params = GetBadgeByIdParams(badgeId: 'test-badge');

      // Assert
      expect(params.badgeId, 'test-badge');
    });

    test('getUserBadgesParams_shouldStoreUserId', () {
      // Act
      const params = GetUserBadgesParams(userId: 'test-user');

      // Assert
      expect(params.userId, 'test-user');
    });

    test('awardBadgeParams_shouldStoreUserIdAndBadgeId', () {
      // Act
      const params = AwardBadgeParams(
        userId: 'test-user',
        badgeId: 'test-badge',
      );

      // Assert
      expect(params.userId, 'test-user');
      expect(params.badgeId, 'test-badge');
    });

    test('checkEarnableBadgesParams_shouldStoreUserId', () {
      // Act
      const params = CheckEarnableBadgesParams(userId: 'test-user');

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
