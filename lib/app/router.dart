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
import '../presentation/screens/vocabulary/vocabulary_hub_screen.dart';
import '../presentation/screens/vocabulary/word_list_detail_screen.dart';
import '../presentation/screens/vocabulary/category_browse_screen.dart';
import '../presentation/screens/vocabulary/phases/phase1_learn_screen.dart';
import '../presentation/screens/vocabulary/phases/phase2_spelling_screen.dart';
import '../presentation/screens/vocabulary/phases/phase3_flashcards_screen.dart';
import '../presentation/screens/vocabulary/phases/phase4_review_screen.dart';
import '../presentation/screens/profile/profile_screen.dart';
import '../presentation/screens/teacher/dashboard_screen.dart';
import '../presentation/providers/auth_provider.dart';
import '../presentation/widgets/shell/main_shell_scaffold.dart';

// Route paths
abstract class AppRoutes {
  static const schoolCode = '/school-code';
  static const login = '/login';
  static const home = '/';
  static const library = '/library';
  static const bookDetail = '/library/book'; // Use with bookId parameter
  static const reader = '/reader/:bookId/:chapterId';
  static const activity = '/activity/:chapterId';
  static const vocabulary = '/vocabulary';
  static const profile = '/profile';
  static const teacherDashboard = '/teacher';
}

// Navigation shell keys for each branch
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _libraryNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'library');
final _vocabularyNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'vocabulary');

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
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
      // Auth routes (outside shell)
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

      // Main app shell with bottom navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShellScaffold(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Home
          StatefulShellBranch(
            navigatorKey: _homeNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.home,
                name: 'home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),

          // Branch 1: Library
          StatefulShellBranch(
            navigatorKey: _libraryNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.library,
                name: 'library',
                builder: (context, state) => const LibraryScreen(),
                routes: [
                  // Book detail is nested under library
                  GoRoute(
                    path: 'book/:bookId',
                    name: 'bookDetail',
                    builder: (context, state) {
                      final bookId = state.pathParameters['bookId']!;
                      return BookDetailScreen(bookId: bookId);
                    },
                  ),
                ],
              ),
            ],
          ),

          // Branch 2: Vocabulary
          StatefulShellBranch(
            navigatorKey: _vocabularyNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.vocabulary,
                name: 'vocabulary',
                builder: (context, state) => const VocabularyHubScreen(),
                routes: [
                  // Word list detail
                  GoRoute(
                    path: 'list/:listId',
                    name: 'wordListDetail',
                    builder: (context, state) {
                      final listId = state.pathParameters['listId']!;
                      return WordListDetailScreen(listId: listId);
                    },
                    routes: [
                      // Phase 1: Learn Vocab
                      GoRoute(
                        path: 'phase/1',
                        name: 'phase1Learn',
                        builder: (context, state) {
                          final listId = state.pathParameters['listId']!;
                          return Phase1LearnScreen(listId: listId);
                        },
                      ),
                      // Phase 2: Spelling
                      GoRoute(
                        path: 'phase/2',
                        name: 'phase2Spelling',
                        builder: (context, state) {
                          final listId = state.pathParameters['listId']!;
                          return Phase2SpellingScreen(listId: listId);
                        },
                      ),
                      // Phase 3: Flashcards
                      GoRoute(
                        path: 'phase/3',
                        name: 'phase3Flashcards',
                        builder: (context, state) {
                          final listId = state.pathParameters['listId']!;
                          return Phase3FlashcardsScreen(listId: listId);
                        },
                      ),
                      // Phase 4: Review Quiz
                      GoRoute(
                        path: 'phase/4',
                        name: 'phase4Review',
                        builder: (context, state) {
                          final listId = state.pathParameters['listId']!;
                          return Phase4ReviewScreen(listId: listId);
                        },
                      ),
                    ],
                  ),
                  // Category browse
                  GoRoute(
                    path: 'category/:categoryName',
                    name: 'categoryBrowse',
                    builder: (context, state) {
                      final categoryName = state.pathParameters['categoryName']!;
                      return CategoryBrowseScreen(categoryName: categoryName);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // Profile route (full-screen, outside shell)
      GoRoute(
        path: AppRoutes.profile,
        name: 'profile',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProfileScreen(),
      ),

      // Full-screen routes (outside shell)
      GoRoute(
        path: AppRoutes.reader,
        name: 'reader',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final bookId = state.pathParameters['bookId']!;
          final chapterId = state.pathParameters['chapterId']!;
          return ReaderScreen(bookId: bookId, chapterId: chapterId);
        },
      ),
      GoRoute(
        path: AppRoutes.activity,
        name: 'activity',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final chapterId = state.pathParameters['chapterId']!;
          return ActivityScreen(chapterId: chapterId);
        },
      ),

      // Teacher routes (outside shell for now)
      GoRoute(
        path: AppRoutes.teacherDashboard,
        name: 'teacherDashboard',
        parentNavigatorKey: _rootNavigatorKey,
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
