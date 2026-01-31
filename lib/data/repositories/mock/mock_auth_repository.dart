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
  Future<Either<Failure, User>> signInWithSchoolCode({
    required String schoolCode,
    required String studentNumber,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));

    // Find school by code
    final school = MockData.schools.where((s) => s.code == schoolCode).firstOrNull;
    if (school == null) {
      return const Left(AuthFailure('Okul kodu bulunamadı'));
    }

    // Find user by student number
    final user = MockData.users.where(
      (u) => u.schoolId == school.id && u.studentNumber == studentNumber,
    ).firstOrNull;

    if (user == null) {
      return const Left(AuthFailure('Öğrenci numarası bulunamadı'));
    }

    // Simple password check (in real app this would be hashed)
    if (password != '123456') {
      return const Left(AuthFailure('Hatalı şifre'));
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
      return const Left(AuthFailure('Kullanıcı bulunamadı'));
    }

    if (password != '123456') {
      return const Left(AuthFailure('Hatalı şifre'));
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
  Future<Either<Failure, bool>> validateSchoolCode(String code) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final upperCode = code.toUpperCase();
    final exists = MockData.schools.any((s) => s.code.toUpperCase() == upperCode);
    return Right(exists);
  }

  @override
  Stream<User?> get authStateChanges => _authStateController.stream;

  void dispose() {
    _authStateController.close();
  }
}
