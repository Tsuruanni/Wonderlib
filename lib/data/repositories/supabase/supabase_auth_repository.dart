import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failures.dart';
import '../../../domain/entities/user.dart' as domain;
import '../../../domain/repositories/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client {
    // Listen to Supabase auth changes and broadcast domain User
    _supabase.auth.onAuthStateChange.listen((data) async {
      if (data.session != null) {
        final userResult = await getCurrentUser();
        userResult.fold(
          (failure) => _authStateController.add(null),
          (user) => _authStateController.add(user),
        );
      } else {
        _authStateController.add(null);
      }
    });
  }

  final SupabaseClient _supabase;
  final _authStateController = StreamController<domain.User?>.broadcast();

  @override
  Future<Either<Failure, domain.User>> signInWithSchoolCode({
    required String schoolCode,
    required String studentNumber,
    required String password,
  }) async {
    try {
      // 1. Validate school code and get school ID
      final schoolResponse = await _supabase
          .from('schools')
          .select('id')
          .eq('code', schoolCode.toUpperCase())
          .maybeSingle();

      if (schoolResponse == null) {
        return Left(AuthFailure.schoolNotFound());
      }

      final schoolId = schoolResponse['id'] as String;

      // 2. Find user by student number in this school
      final profileResponse = await _supabase
          .from('profiles')
          .select('id, email')
          .eq('school_id', schoolId)
          .eq('student_number', studentNumber)
          .maybeSingle();

      if (profileResponse == null) {
        return const Left(
          AuthFailure('Student not found', code: 'STUDENT_NOT_FOUND'),
        );
      }

      final email = profileResponse['email'] as String?;
      if (email == null || email.isEmpty) {
        return const Left(
          AuthFailure('User has no email configured', code: 'NO_EMAIL'),
        );
      }

      // 3. Sign in with email/password
      final authResponse = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        return Left(AuthFailure.invalidCredentials());
      }

      // 4. Return the domain user
      return getCurrentUser().then(
        (result) => result.fold(
          (failure) => Left(failure),
          (user) => user != null
              ? Right(user)
              : Left(AuthFailure.invalidCredentials()),
        ),
      );
    } on AuthException catch (e) {
      if (e.message.contains('Invalid login credentials')) {
        return Left(AuthFailure.invalidCredentials());
      }
      return Left(AuthFailure(e.message));
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, domain.User>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        return Left(AuthFailure.invalidCredentials());
      }

      return getCurrentUser().then(
        (result) => result.fold(
          (failure) => Left(failure),
          (user) => user != null
              ? Right(user)
              : Left(AuthFailure.invalidCredentials()),
        ),
      );
    } on AuthException catch (e) {
      if (e.message.contains('Invalid login credentials')) {
        return Left(AuthFailure.invalidCredentials());
      }
      return Left(AuthFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await _supabase.auth.signOut();
      _authStateController.add(null);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, domain.User?>> getCurrentUser() async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) {
        return const Right(null);
      }

      final profileData = await _supabase
          .from('profiles')
          .select()
          .eq('id', authUser.id)
          .maybeSingle();

      if (profileData == null) {
        return const Right(null);
      }

      return Right(_mapProfileToUser(profileData));
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> validateSchoolCode(String code) async {
    try {
      final response = await _supabase
          .from('schools')
          .select('id')
          .eq('code', code.toUpperCase())
          .maybeSingle();

      return Right(response != null);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Stream<domain.User?> get authStateChanges => _authStateController.stream;

  /// Maps Supabase profile data to domain User entity
  domain.User _mapProfileToUser(Map<String, dynamic> data) {
    return domain.User(
      id: data['id'] as String,
      schoolId: data['school_id'] as String? ?? '',
      classId: data['class_id'] as String?,
      role: _parseRole(data['role'] as String?),
      studentNumber: data['student_number'] as String?,
      firstName: data['first_name'] as String? ?? '',
      lastName: data['last_name'] as String? ?? '',
      email: data['email'] as String?,
      avatarUrl: data['avatar_url'] as String?,
      xp: data['xp'] as int? ?? 0,
      level: data['level'] as int? ?? 1,
      currentStreak: data['current_streak'] as int? ?? 0,
      longestStreak: data['longest_streak'] as int? ?? 0,
      lastActivityDate: data['last_activity_date'] != null
          ? DateTime.parse(data['last_activity_date'] as String)
          : null,
      settings: (data['settings'] as Map<String, dynamic>?) ?? {},
      createdAt: DateTime.parse(data['created_at'] as String),
      updatedAt: DateTime.parse(data['updated_at'] as String),
    );
  }

  UserRole _parseRole(String? role) {
    switch (role) {
      case 'teacher':
        return UserRole.teacher;
      case 'head':
        return UserRole.head;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.student;
    }
  }

  void dispose() {
    _authStateController.close();
  }
}
