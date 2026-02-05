import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:readeng/core/errors/failures.dart';
import 'package:readeng/domain/entities/user.dart';
import 'package:readeng/domain/usecases/auth/sign_in_with_email_usecase.dart';
import 'package:readeng/domain/usecases/auth/sign_in_with_student_number_usecase.dart';
import 'package:readeng/domain/usecases/auth/sign_out_usecase.dart';
import 'package:readeng/domain/usecases/auth/get_current_user_usecase.dart';
import 'package:readeng/domain/usecases/usecase.dart';

import '../../../../fixtures/user_fixtures.dart';
import '../../../../mocks/mock_repositories.mocks.dart';

void main() {
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
  });

  // ============================================
  // SignInWithEmailUseCase Tests
  // ============================================
  group('SignInWithEmailUseCase', () {
    late SignInWithEmailUseCase usecase;

    setUp(() {
      usecase = SignInWithEmailUseCase(mockAuthRepository);
    });

    test('withValidCredentials_shouldReturnUser', () async {
      // Arrange
      final user = UserFixtures.validStudentUser();
      when(mockAuthRepository.signInWithEmail(
        email: 'test@example.com',
        password: 'password123',
      )).thenAnswer((_) async => Right(user));

      const params = SignInWithEmailParams(
        email: 'test@example.com',
        password: 'password123',
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedUser) {
          expect(returnedUser.id, user.id);
          expect(returnedUser.email, user.email);
        },
      );
      verify(mockAuthRepository.signInWithEmail(
        email: 'test@example.com',
        password: 'password123',
      )).called(1);
    });

    test('withInvalidCredentials_shouldReturnAuthFailure', () async {
      // Arrange
      when(mockAuthRepository.signInWithEmail(
        email: 'wrong@example.com',
        password: 'wrongpassword',
      )).thenAnswer((_) async => Left(AuthFailure.invalidCredentials()));

      const params = SignInWithEmailParams(
        email: 'wrong@example.com',
        password: 'wrongpassword',
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.code, 'INVALID_CREDENTIALS');
        },
        (user) => fail('Should not return user'),
      );
    });

    test('withNetworkError_shouldReturnNetworkFailure', () async {
      // Arrange
      when(mockAuthRepository.signInWithEmail(
        email: 'test@example.com',
        password: 'password123',
      )).thenAnswer((_) async => const Left(NetworkFailure()));

      const params = SignInWithEmailParams(
        email: 'test@example.com',
        password: 'password123',
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (user) => fail('Should not return user'),
      );
    });

    test('withServerError_shouldReturnServerFailure', () async {
      // Arrange
      when(mockAuthRepository.signInWithEmail(
        email: 'test@example.com',
        password: 'password123',
      )).thenAnswer((_) async => const Left(ServerFailure('Internal server error', statusCode: 500)));

      const params = SignInWithEmailParams(
        email: 'test@example.com',
        password: 'password123',
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
          expect((failure as ServerFailure).statusCode, 500);
        },
        (user) => fail('Should not return user'),
      );
    });

    test('params_shouldStoreEmailAndPassword', () {
      // Arrange & Act
      const params = SignInWithEmailParams(
        email: 'test@example.com',
        password: 'mypassword',
      );

      // Assert
      expect(params.email, 'test@example.com');
      expect(params.password, 'mypassword');
    });
  });

  // ============================================
  // SignInWithStudentNumberUseCase Tests
  // ============================================
  group('SignInWithStudentNumberUseCase', () {
    late SignInWithStudentNumberUseCase usecase;

    setUp(() {
      usecase = SignInWithStudentNumberUseCase(mockAuthRepository);
    });

    test('withValidCredentials_shouldReturnUser', () async {
      // Arrange
      final user = UserFixtures.validStudentUser();
      when(mockAuthRepository.signInWithStudentNumber(
        studentNumber: '2024001',
        password: 'password123',
      )).thenAnswer((_) async => Right(user));

      const params = SignInWithStudentNumberParams(
        studentNumber: '2024001',
        password: 'password123',
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedUser) {
          expect(returnedUser.studentNumber, '2024001');
        },
      );
      verify(mockAuthRepository.signInWithStudentNumber(
        studentNumber: '2024001',
        password: 'password123',
      )).called(1);
    });

    test('withInvalidStudentNumber_shouldReturnAuthFailure', () async {
      // Arrange
      when(mockAuthRepository.signInWithStudentNumber(
        studentNumber: '9999999',
        password: 'password',
      )).thenAnswer((_) async => Left(AuthFailure.invalidCredentials()));

      const params = SignInWithStudentNumberParams(
        studentNumber: '9999999',
        password: 'password',
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<AuthFailure>()),
        (user) => fail('Should not return user'),
      );
    });

    test('params_shouldStoreStudentNumberAndPassword', () {
      // Arrange & Act
      const params = SignInWithStudentNumberParams(
        studentNumber: '2024001',
        password: 'mypassword',
      );

      // Assert
      expect(params.studentNumber, '2024001');
      expect(params.password, 'mypassword');
    });
  });

  // ============================================
  // SignOutUseCase Tests
  // ============================================
  group('SignOutUseCase', () {
    late SignOutUseCase usecase;

    setUp(() {
      usecase = SignOutUseCase(mockAuthRepository);
    });

    test('always_shouldCallRepository', () async {
      // Arrange
      when(mockAuthRepository.signOut())
          .thenAnswer((_) async => const Right(null));

      // Act
      final result = await usecase(NoParams());

      // Assert
      expect(result.isRight(), true);
      verify(mockAuthRepository.signOut()).called(1);
    });

    test('withError_shouldReturnFailure', () async {
      // Arrange
      when(mockAuthRepository.signOut())
          .thenAnswer((_) async => const Left(ServerFailure('Sign out failed')));

      // Act
      final result = await usecase(NoParams());

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure.message, 'Sign out failed'),
        (_) => fail('Should not succeed'),
      );
    });
  });

  // ============================================
  // GetCurrentUserUseCase Tests
  // ============================================
  group('GetCurrentUserUseCase', () {
    late GetCurrentUserUseCase usecase;

    setUp(() {
      usecase = GetCurrentUserUseCase(mockAuthRepository);
    });

    test('withLoggedInUser_shouldReturnUser', () async {
      // Arrange
      final user = UserFixtures.validStudentUser();
      when(mockAuthRepository.getCurrentUser())
          .thenAnswer((_) async => Right(user));

      // Act
      final result = await usecase(NoParams());

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedUser) {
          expect(returnedUser, isNotNull);
          expect(returnedUser!.id, user.id);
        },
      );
    });

    test('withNoLoggedInUser_shouldReturnNull', () async {
      // Arrange
      when(mockAuthRepository.getCurrentUser())
          .thenAnswer((_) async => const Right(null));

      // Act
      final result = await usecase(NoParams());

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (user) => expect(user, isNull),
      );
    });

    test('withSessionExpired_shouldReturnAuthFailure', () async {
      // Arrange
      when(mockAuthRepository.getCurrentUser())
          .thenAnswer((_) async => Left(AuthFailure.sessionExpired()));

      // Act
      final result = await usecase(NoParams());

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.code, 'SESSION_EXPIRED');
        },
        (user) => fail('Should not return user'),
      );
    });
  });

  // ============================================
  // Edge Cases
  // ============================================
  group('edgeCases', () {
    test('signInWithEmptyEmail_repositoryShouldBeCalledAnyway', () async {
      // Arrange
      final usecase = SignInWithEmailUseCase(mockAuthRepository);
      when(mockAuthRepository.signInWithEmail(
        email: '',
        password: 'password',
      )).thenAnswer((_) async => const Left(ValidationFailure('Email is required')));

      const params = SignInWithEmailParams(
        email: '',
        password: 'password',
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      verify(mockAuthRepository.signInWithEmail(
        email: '',
        password: 'password',
      )).called(1);
    });

    test('signInWithVeryLongPassword_shouldCallRepository', () async {
      // Arrange
      final usecase = SignInWithEmailUseCase(mockAuthRepository);
      final longPassword = 'a' * 1000;
      when(mockAuthRepository.signInWithEmail(
        email: 'test@example.com',
        password: longPassword,
      )).thenAnswer((_) async => Left(AuthFailure.invalidCredentials()));

      final params = SignInWithEmailParams(
        email: 'test@example.com',
        password: longPassword,
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      verify(mockAuthRepository.signInWithEmail(
        email: 'test@example.com',
        password: longPassword,
      )).called(1);
    });

    test('signInWithSpecialCharactersInEmail_shouldCallRepository', () async {
      // Arrange
      final usecase = SignInWithEmailUseCase(mockAuthRepository);
      const specialEmail = "test+tag@example.com";
      when(mockAuthRepository.signInWithEmail(
        email: specialEmail,
        password: 'password',
      )).thenAnswer((_) async => Right(UserFixtures.validStudentUser()));

      const params = SignInWithEmailParams(
        email: specialEmail,
        password: 'password',
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
    });
  });

  // ============================================
  // Multiple Calls Tests
  // ============================================
  group('multipleCalls', () {
    test('signOutCalledMultipleTimes_shouldCallRepositoryEachTime', () async {
      // Arrange
      final usecase = SignOutUseCase(mockAuthRepository);
      when(mockAuthRepository.signOut())
          .thenAnswer((_) async => const Right(null));

      // Act
      await usecase(NoParams());
      await usecase(NoParams());
      await usecase(NoParams());

      // Assert
      verify(mockAuthRepository.signOut()).called(3);
    });

    test('getCurrentUserCalledAfterSignIn_shouldReturnUser', () async {
      // Arrange
      final signInUseCase = SignInWithEmailUseCase(mockAuthRepository);
      final getCurrentUserUseCase = GetCurrentUserUseCase(mockAuthRepository);
      final user = UserFixtures.validStudentUser();

      when(mockAuthRepository.signInWithEmail(
        email: 'test@example.com',
        password: 'password',
      )).thenAnswer((_) async => Right(user));
      when(mockAuthRepository.getCurrentUser())
          .thenAnswer((_) async => Right(user));

      // Act
      await signInUseCase(const SignInWithEmailParams(
        email: 'test@example.com',
        password: 'password',
      ));
      final result = await getCurrentUserUseCase(NoParams());

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not fail'),
        (returnedUser) => expect(returnedUser?.id, user.id),
      );
    });
  });
}
