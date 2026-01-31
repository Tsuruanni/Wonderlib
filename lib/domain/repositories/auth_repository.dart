import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/user.dart';

abstract class AuthRepository {
  Future<Either<Failure, User>> signInWithSchoolCode({
    required String schoolCode,
    required String studentNumber,
    required String password,
  });

  Future<Either<Failure, User>> signInWithEmail({
    required String email,
    required String password,
  });

  Future<Either<Failure, void>> signOut();

  Future<Either<Failure, User?>> getCurrentUser();

  Future<Either<Failure, bool>> validateSchoolCode(String code);

  Stream<User?> get authStateChanges;

  /// Refreshes the current user data and broadcasts to stream
  /// Call this after XP or profile changes to update UI
  Future<void> refreshCurrentUser();
}
