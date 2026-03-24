import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/screens/login_screen.dart';
import '../features/books/screens/book_edit_screen.dart';
import '../features/books/screens/book_json_import_screen.dart';
import '../features/books/screens/book_list_screen.dart';
import '../features/books/screens/chapter_edit_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/schools/screens/school_edit_screen.dart';
import '../features/schools/screens/school_list_screen.dart';
import '../features/users/screens/user_edit_screen.dart';
import '../features/users/screens/user_import_screen.dart';
import '../features/users/screens/user_list_screen.dart';
import '../features/badges/screens/badge_edit_screen.dart';
import '../features/collectibles/screens/collectibles_screen.dart';
import '../features/vocabulary/screens/vocabulary_edit_screen.dart';
import '../features/vocabulary/screens/vocabulary_import_screen.dart';
import '../features/vocabulary/screens/vocabulary_list_screen.dart';
import '../features/wordlists/screens/wordlist_edit_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/templates/screens/template_list_screen.dart';
import '../features/templates/screens/template_edit_screen.dart';
import '../features/learning_path_assignments/screens/assignment_screen.dart';
import '../features/quizzes/screens/book_quiz_edit_screen.dart';
import '../features/quizzes/screens/quiz_question_edit_screen.dart';
import '../features/cards/screens/card_edit_screen.dart';
import '../features/assignments/screens/assignment_list_screen.dart';
import '../features/assignments/screens/assignment_detail_screen.dart';
import '../features/recent_activity/screens/recent_activity_screen.dart';
import '../features/recent_activity/screens/recent_activity_detail_screen.dart';
import '../features/quests/screens/quest_list_screen.dart';
import '../features/notifications/screens/notification_gallery_screen.dart';
import 'supabase_client.dart';

/// Router configuration for admin panel
final routerProvider = Provider<GoRouter>((ref) {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  final isAuthorized = ref.watch(isAuthorizedAdminProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isOnLogin = state.matchedLocation == '/login';

      if (!isAuthenticated && !isOnLogin) {
        return '/login';
      }

      // Authenticated but not admin/head → sign out and redirect
      if (isAuthenticated && !isAuthorized && !isOnLogin) {
        ref.read(supabaseClientProvider).auth.signOut();
        return '/login';
      }

      if (isAuthenticated && isAuthorized && isOnLogin) {
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
        path: '/recent-activity',
        builder: (context, state) => const RecentActivityScreen(),
      ),
      GoRoute(
        path: '/recent-activity/:sectionKey',
        builder: (context, state) => RecentActivityDetailScreen(
          sectionKey: state.pathParameters['sectionKey']!,
        ),
      ),
      GoRoute(
        path: '/quests',
        builder: (context, state) => const QuestListScreen(),
      ),
      GoRoute(
        path: '/books',
        builder: (context, state) => const BookListScreen(),
      ),
      GoRoute(
        path: '/books/import',
        builder: (context, state) => const BookJsonImportScreen(),
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
      // Book Quizzes
      GoRoute(
        path: '/books/:bookId/quiz',
        builder: (context, state) => BookQuizEditScreen(
          bookId: state.pathParameters['bookId']!,
        ),
      ),
      GoRoute(
        path: '/books/:bookId/quiz/questions/new',
        builder: (context, state) => QuizQuestionEditScreen(
          quizId: state.uri.queryParameters['quizId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/books/:bookId/quiz/questions/:questionId',
        builder: (context, state) => QuizQuestionEditScreen(
          quizId: state.uri.queryParameters['quizId'] ?? '',
          questionId: state.pathParameters['questionId'],
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
      // Collectibles (Badges + Myth Cards)
      GoRoute(
        path: '/collectibles',
        builder: (context, state) => const CollectiblesScreen(),
      ),
      GoRoute(
        path: '/badges',
        builder: (context, state) => const CollectiblesScreen(initialTab: 0),
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
      // Word Lists (edit only — list is inside /vocabulary tab)
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
      // Learning Paths (templates + assignments)
      GoRoute(
        path: '/learning-paths',
        builder: (context, state) => const LearningPathsScreen(),
      ),
      GoRoute(
        path: '/templates',
        builder: (context, state) => const LearningPathsScreen(),
      ),
      GoRoute(
        path: '/templates/new',
        builder: (context, state) => const TemplateEditScreen(),
      ),
      GoRoute(
        path: '/templates/:templateId',
        builder: (context, state) => TemplateEditScreen(
          templateId: state.pathParameters['templateId'],
        ),
      ),
      // Learning Path Assignments (create only — list is inside /learning-paths tab)
      GoRoute(
        path: '/learning-path-assignments/new',
        builder: (context, state) => const AssignmentScreen(),
      ),
      // Teacher Assignments (read-only)
      GoRoute(
        path: '/assignments',
        builder: (context, state) => const AssignmentListScreen(),
      ),
      GoRoute(
        path: '/assignments/:assignmentId',
        builder: (context, state) => AssignmentDetailScreen(
          assignmentId: state.pathParameters['assignmentId']!,
        ),
      ),
      GoRoute(
        path: '/cards',
        builder: (context, state) => const CollectiblesScreen(initialTab: 1),
      ),
      GoRoute(
        path: '/cards/new',
        builder: (context, state) => const CardEditScreen(),
      ),
      GoRoute(
        path: '/cards/:cardId',
        builder: (context, state) => CardEditScreen(
          cardId: state.pathParameters['cardId'],
        ),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationGalleryScreen(),
      ),
      // Ayarlar (XP + Uygulama)
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(
          title: 'Ayarlar',
          categories: ['xp_reading', 'xp_vocab', 'progression', 'game', 'app'],
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Sayfa bulunamadı: ${state.matchedLocation}'),
      ),
    ),
  );
});
