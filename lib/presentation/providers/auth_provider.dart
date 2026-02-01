import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/user.dart';
import '../../domain/usecases/auth/sign_in_with_email_usecase.dart';
import '../../domain/usecases/auth/sign_in_with_student_number_usecase.dart';
import '../../domain/usecases/usecase.dart';
import 'repository_providers.dart';
import 'usecase_providers.dart';

/// Provides the current user stream
final authStateChangesProvider = StreamProvider<User?>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.authStateChanges;
});

/// Provides the current authenticated user
final currentUserProvider = FutureProvider<User?>((ref) async {
  final useCase = ref.watch(getCurrentUserUseCaseProvider);
  final result = await useCase(const NoParams());
  return result.fold(
    (failure) => null,
    (user) => user,
  );
});

/// Provides whether user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  return authState.valueOrNull != null;
});

/// Provides current user ID
final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final userId = authState.valueOrNull?.id;
  debugPrint('🔐 currentUserIdProvider: $userId');
  return userId;
});

/// Auth controller state
class AuthState {

  const AuthState({
    this.isLoading = false,
    this.error,
    this.user,
  });
  final bool isLoading;
  final String? error;
  final User? user;

  AuthState copyWith({
    bool? isLoading,
    String? error,
    User? user,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      user: user ?? this.user,
    );
  }
}

/// Auth controller for login/logout operations
class AuthController extends StateNotifier<AuthState> {

  AuthController(this._ref) : super(const AuthState());
  final Ref _ref;

  /// Sign in with student number (globally unique)
  Future<bool> signInWithStudentNumber({
    required String studentNumber,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final useCase = _ref.read(signInWithStudentNumberUseCaseProvider);
    final result = await useCase(SignInWithStudentNumberParams(
      studentNumber: studentNumber,
      password: password,
    ),);

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (user) {
        state = state.copyWith(isLoading: false, user: user);
        return true;
      },
    );
  }

  /// Sign in with email (for teachers/admins or students who prefer email)
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final useCase = _ref.read(signInWithEmailUseCaseProvider);
    final result = await useCase(SignInWithEmailParams(
      email: email,
      password: password,
    ),);

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (user) {
        state = state.copyWith(isLoading: false, user: user);
        return true;
      },
    );
  }

  /// Sign out
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    final useCase = _ref.read(signOutUseCaseProvider);
    await useCase(const NoParams());
    state = const AuthState();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref);
});

/// Refreshes the current user data from database
/// Call this after XP changes, profile updates, etc.
Future<void> refreshUserData(Ref ref) async {
  final useCase = ref.read(refreshCurrentUserUseCaseProvider);
  await useCase(const NoParams());
}
