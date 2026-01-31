import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/failures.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../datasources/local/mock_data.dart';

class MockAuthRepository implements AuthRepository {
  MockAuthRepository() {
    // Auto-login with mock user when dev bypass is enabled
    if (kDevBypassAuth) {
      _currentUser = MockData.users[0];
      // Use Future.microtask to ensure stream listeners are attached first
      Future.microtask(() => _authStateController.add(_currentUser));
    }
  }

  User? _currentUser;
  final _authStateController = StreamController<User?>.broadcast();

  @override
  Future<Either<Failure, User>> signInWithStudentNumber({
    required String studentNumber,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));

    // Find user by student number (globally unique)
    final user = MockData.users.where(
      (u) => u.studentNumber == studentNumber,
    ).firstOrNull;

    if (user == null) {
      return const Left(AuthFailure('Student number not found'));
    }

    // Simple password check (in real app this would be hashed)
    if (password != '123456') {
      return const Left(AuthFailure('Invalid password'));
    }

    _currentUser = user;
    _authStateController.add(_currentUser);
    return Right(user);
  }

  @override
  Future<Either<Failure, User>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final user = MockData.users.where((u) => u.email == email).firstOrNull;
    if (user == null) {
      return const Left(AuthFailure('User not found'));
    }

    if (password != '123456') {
      return const Left(AuthFailure('Invalid password'));
    }

    _currentUser = user;
    _authStateController.add(_currentUser);
    return Right(user);
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _currentUser = null;
    _authStateController.add(null);
    return const Right(null);
  }

  @override
  Future<Either<Failure, User?>> getCurrentUser() async {
    return Right(_currentUser);
  }

  @override
  Stream<User?> get authStateChanges => _authStateController.stream;

  @override
  Future<void> refreshCurrentUser() async {
    // In mock, just re-broadcast current user
    _authStateController.add(_currentUser);
  }

  void dispose() {
    _authStateController.close();
  }
}
