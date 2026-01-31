import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/user.dart';
import 'repository_providers.dart';

/// Provides the current user stream
final authStateChangesProvider = StreamProvider<User?>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.authStateChanges;
});

/// Provides the current authenticated user
final currentUserProvider = FutureProvider<User?>((ref) async {
  final authRepo = ref.watch(authRepositoryProvider);
  final result = await authRepo.getCurrentUser();
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
  return authState.valueOrNull?.id;
});

/// Auth controller state
class AuthState {
  final bool isLoading;
  final String? error;
  final User? user;

  const AuthState({
    this.isLoading = false,
    this.error,
    this.user,
  });

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
  final Ref _ref;

  AuthController(this._ref) : super(const AuthState());

  /// Validate school code exists
  Future<bool> validateSchoolCode(String code) async {
    final authRepo = _ref.read(authRepositoryProvider);
    final result = await authRepo.validateSchoolCode(code);
    return result.fold(
      (failure) => false,
      (isValid) => isValid,
    );
  }

  /// Sign in with school code (for students)
  Future<bool> signInWithSchoolCode({
    required String schoolCode,
    required String studentNumber,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final authRepo = _ref.read(authRepositoryProvider);
    final result = await authRepo.signInWithSchoolCode(
      schoolCode: schoolCode,
      studentNumber: studentNumber,
      password: password,
    );

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

  /// Sign in with email (for teachers/admins)
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final authRepo = _ref.read(authRepositoryProvider);
    final result = await authRepo.signInWithEmail(
      email: email,
      password: password,
    );

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
    final authRepo = _ref.read(authRepositoryProvider);
    await authRepo.signOut();
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
  final authRepo = ref.read(authRepositoryProvider);
  await authRepo.refreshCurrentUser();
}
