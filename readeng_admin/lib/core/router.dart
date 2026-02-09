import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/screens/login_screen.dart';
import '../features/books/screens/book_edit_screen.dart';
import '../features/books/screens/book_list_screen.dart';
import '../features/books/screens/chapter_edit_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/schools/screens/school_edit_screen.dart';
import '../features/schools/screens/school_list_screen.dart';
import '../features/users/screens/user_edit_screen.dart';
import '../features/users/screens/user_import_screen.dart';
import '../features/users/screens/user_list_screen.dart';
import '../features/classes/screens/class_edit_screen.dart';
import '../features/classes/screens/class_list_screen.dart';
import '../features/badges/screens/badge_edit_screen.dart';
import '../features/badges/screens/badge_list_screen.dart';
import '../features/vocabulary/screens/vocabulary_edit_screen.dart';
import '../features/vocabulary/screens/vocabulary_import_screen.dart';
import '../features/vocabulary/screens/vocabulary_list_screen.dart';
import '../features/wordlists/screens/wordlist_edit_screen.dart';
import '../features/wordlists/screens/wordlist_list_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/curriculum/screens/curriculum_edit_screen.dart';
import '../features/curriculum/screens/curriculum_list_screen.dart';
import '../features/gallery/screens/gallery_screen.dart';
import 'supabase_client.dart';

/// Router configuration for admin panel
final routerProvider = Provider<GoRouter>((ref) {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isOnLogin = state.matchedLocation == '/login';

      if (!isAuthenticated && !isOnLogin) {
        return '/login';
      }

      if (isAuthenticated && isOnLogin) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/books',
        builder: (context, state) => const BookListScreen(),
      ),
      GoRoute(
        path: '/books/new',
        builder: (context, state) => const BookEditScreen(),
      ),
      GoRoute(
        path: '/books/:bookId',
        builder: (context, state) => BookEditScreen(
          bookId: state.pathParameters['bookId'],
        ),
      ),
      GoRoute(
        path: '/books/:bookId/chapters/new',
        builder: (context, state) => ChapterEditScreen(
          bookId: state.pathParameters['bookId']!,
        ),
      ),
      GoRoute(
        path: '/books/:bookId/chapters/:chapterId',
        builder: (context, state) => ChapterEditScreen(
          bookId: state.pathParameters['bookId']!,
          chapterId: state.pathParameters['chapterId'],
        ),
      ),
      // Schools
      GoRoute(
        path: '/schools',
        builder: (context, state) => const SchoolListScreen(),
      ),
      GoRoute(
        path: '/schools/new',
        builder: (context, state) => const SchoolEditScreen(),
      ),
      GoRoute(
        path: '/schools/:schoolId',
        builder: (context, state) => SchoolEditScreen(
          schoolId: state.pathParameters['schoolId'],
        ),
      ),
      // Users (edit only - create via Supabase Dashboard)
      GoRoute(
        path: '/users',
        builder: (context, state) => const UserListScreen(),
      ),
      GoRoute(
        path: '/users/import',
        builder: (context, state) => const UserImportScreen(),
      ),
      GoRoute(
        path: '/users/:userId',
        builder: (context, state) => UserEditScreen(
          userId: state.pathParameters['userId']!,
        ),
      ),
      // Classes
      GoRoute(
        path: '/classes',
        builder: (context, state) => const ClassListScreen(),
      ),
      GoRoute(
        path: '/classes/new',
        builder: (context, state) => const ClassEditScreen(),
      ),
      GoRoute(
        path: '/classes/:classId',
        builder: (context, state) => ClassEditScreen(
          classId: state.pathParameters['classId'],
        ),
      ),
      // Badges
      GoRoute(
        path: '/badges',
        builder: (context, state) => const BadgeListScreen(),
      ),
      GoRoute(
        path: '/badges/new',
        builder: (context, state) => const BadgeEditScreen(),
      ),
      GoRoute(
        path: '/badges/:badgeId',
        builder: (context, state) => BadgeEditScreen(
          badgeId: state.pathParameters['badgeId'],
        ),
      ),
      // Vocabulary
      GoRoute(
        path: '/vocabulary',
        builder: (context, state) => const VocabularyListScreen(),
      ),
      GoRoute(
        path: '/vocabulary/import',
        builder: (context, state) => const VocabularyImportScreen(),
      ),
      GoRoute(
        path: '/vocabulary/new',
        builder: (context, state) => const VocabularyEditScreen(),
      ),
      GoRoute(
        path: '/vocabulary/:wordId',
        builder: (context, state) => VocabularyEditScreen(
          wordId: state.pathParameters['wordId'],
        ),
      ),
      // Word Lists
      GoRoute(
        path: '/wordlists',
        builder: (context, state) => const WordlistListScreen(),
      ),
      GoRoute(
        path: '/wordlists/new',
        builder: (context, state) => const WordlistEditScreen(),
      ),
      GoRoute(
        path: '/wordlists/:listId',
        builder: (context, state) => WordlistEditScreen(
          listId: state.pathParameters['listId'],
        ),
      ),
      // Curriculum Assignments
      GoRoute(
        path: '/curriculum',
        builder: (context, state) => const CurriculumListScreen(),
      ),
      GoRoute(
        path: '/curriculum/new',
        builder: (context, state) => const CurriculumEditScreen(),
      ),
      GoRoute(
        path: '/curriculum/:assignmentId',
        builder: (context, state) => CurriculumEditScreen(
          assignmentId: state.pathParameters['assignmentId'],
        ),
      ),
      // Settings
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      // Gallery (Developer Tool)
      GoRoute(
        path: '/gallery',
        builder: (context, state) => const GalleryScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.matchedLocation}'),
      ),
    ),
  );
});
