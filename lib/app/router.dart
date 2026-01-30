import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../presentation/screens/auth/school_code_screen.dart';
import '../presentation/screens/auth/login_screen.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/library/library_screen.dart';
import '../presentation/screens/library/book_detail_screen.dart';
import '../presentation/screens/reader/reader_screen.dart';
import '../presentation/screens/reader/activity_screen.dart';
import '../presentation/screens/vocabulary/vocabulary_screen.dart';
import '../presentation/screens/profile/profile_screen.dart';
import '../presentation/screens/teacher/dashboard_screen.dart';
import '../presentation/providers/auth_provider.dart';

// Route paths
abstract class AppRoutes {
  static const schoolCode = '/school-code';
  static const login = '/login';
  static const home = '/';
  static const library = '/library';
  static const bookDetail = '/book/:bookId';
  static const reader = '/reader/:bookId/:chapterId';
  static const activity = '/activity/:chapterId';
  static const vocabulary = '/vocabulary';
  static const profile = '/profile';
  static const teacherDashboard = '/teacher';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    initialLocation: AppRoutes.schoolCode,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuthenticated = authState.valueOrNull != null;
      final isAuthRoute = state.matchedLocation == AppRoutes.schoolCode ||
          state.matchedLocation == AppRoutes.login;

      if (!isAuthenticated && !isAuthRoute) {
        return AppRoutes.schoolCode;
      }

      if (isAuthenticated && isAuthRoute) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      // Auth routes
      GoRoute(
        path: AppRoutes.schoolCode,
        name: 'schoolCode',
        builder: (context, state) => const SchoolCodeScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) {
          final schoolCode = state.extra as String?;
          return LoginScreen(schoolCode: schoolCode ?? '');
        },
      ),

      // Main app routes
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.library,
        name: 'library',
        builder: (context, state) => const LibraryScreen(),
      ),
      GoRoute(
        path: AppRoutes.bookDetail,
        name: 'bookDetail',
        builder: (context, state) {
          final bookId = state.pathParameters['bookId']!;
          return BookDetailScreen(bookId: bookId);
        },
      ),
      GoRoute(
        path: AppRoutes.reader,
        name: 'reader',
        builder: (context, state) {
          final bookId = state.pathParameters['bookId']!;
          final chapterId = state.pathParameters['chapterId']!;
          return ReaderScreen(bookId: bookId, chapterId: chapterId);
        },
      ),
      GoRoute(
        path: AppRoutes.activity,
        name: 'activity',
        builder: (context, state) {
          final chapterId = state.pathParameters['chapterId']!;
          return ActivityScreen(chapterId: chapterId);
        },
      ),
      GoRoute(
        path: AppRoutes.vocabulary,
        name: 'vocabulary',
        builder: (context, state) => const VocabularyScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),

      // Teacher routes
      GoRoute(
        path: AppRoutes.teacherDashboard,
        name: 'teacherDashboard',
        builder: (context, state) => const TeacherDashboardScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.matchedLocation}'),
      ),
    ),
  );
});
