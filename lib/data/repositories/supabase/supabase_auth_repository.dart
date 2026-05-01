import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../domain/entities/user.dart' as domain;
import '../../../domain/repositories/auth_repository.dart';
import '../../models/user/user_model.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client {
    // Check for existing session on initialization
    _initializeAuthState();

    // Listen to Supabase auth changes and broadcast domain User
    _supabase.auth.onAuthStateChange.listen(
      (data) async {
        debugPrint('Auth state change: event=${data.event}, hasSession=${data.session != null}');
        if (data.session != null) {
          final userResult = await getCurrentUser();
          userResult.fold(
            (failure) => _authStateController.add(null),
            (user) {
              debugPrint('Auth: user loaded - id=${user?.id}, role=${user?.role}');
              _authStateController.add(user);
            },
          );
        } else {
          _authStateController.add(null);
        }
      },
      onError: _handleAuthStreamError,
    );
  }

  /// Handle errors surfaced by the auth state stream.
  ///
  /// Stale/invalid refresh tokens (refresh_token_not_found, 400) are expected
  /// when a user's session was revoked server-side — emit null so consumers
  /// treat it as a silent logout instead of bubbling the exception to the
  /// zone guard (which would mark it fatal in Sentry).
  void _handleAuthStreamError(Object error, StackTrace stack) {
    if (error is AuthException) {
      debugPrint('Auth stream AuthException (expected): ${error.message}');
      _authStateController.add(null);
      return;
    }
    debugPrint('Auth stream unexpected error: $error');
    _authStateController.addError(error, stack);
  }

  /// Initialize auth state from existing session
  Future<void> _initializeAuthState() async {
    final session = _supabase.auth.currentSession;
    debugPrint('Auth init: hasSession=${session != null}');
    if (session != null) {
      final userResult = await getCurrentUser();
      userResult.fold(
        (failure) => _authStateController.add(null),
        (user) {
          debugPrint('Auth init: user=${user?.id}');
          _authStateController.add(user);
        },
      );
    }
  }

  final SupabaseClient _supabase;
  final _authStateController = StreamController<domain.User?>.broadcast();

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
          .from(DbTables.profiles)
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
  Stream<domain.User?> get authStateChanges => _authStateController.stream;

  @override
  Future<void> refreshCurrentUser() async {
    final authUser = _supabase.auth.currentUser;
    if (authUser == null) {
      _authStateController.add(null);
      return;
    }

    final userResult = await getCurrentUser();
    userResult.fold(
      (failure) => _authStateController.add(null),
      (user) => _authStateController.add(user),
    );
  }

  /// Maps Supabase profile data to domain User entity using Model layer
  domain.User _mapProfileToUser(Map<String, dynamic> data) {
    return UserModel.fromJson(data).toEntity();
  }

  void dispose() {
    _authStateController.close();
  }
}
