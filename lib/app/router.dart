import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_config.dart';
import '../core/constants/app_constants.dart';
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
import '../presentation/screens/student/student_assignments_screen.dart';
import '../presentation/screens/student/student_assignment_detail_screen.dart';
import '../presentation/screens/teacher/dashboard_screen.dart';
import '../presentation/screens/teacher/classes_screen.dart';
import '../presentation/screens/teacher/class_detail_screen.dart';
import '../presentation/screens/teacher/student_detail_screen.dart';
import '../presentation/screens/teacher/assignments_screen.dart';
import '../presentation/screens/teacher/create_assignment_screen.dart';
import '../presentation/screens/teacher/assignment_detail_screen.dart';
import '../presentation/screens/teacher/reports_screen.dart';
import '../presentation/screens/teacher/reports/class_overview_report_screen.dart';
import '../presentation/screens/teacher/reports/reading_progress_report_screen.dart';
import '../presentation/screens/teacher/reports/assignment_report_screen.dart';
import '../presentation/screens/teacher/reports/leaderboard_report_screen.dart';
import '../presentation/providers/auth_provider.dart';
import '../presentation/widgets/shell/main_shell_scaffold.dart';
import '../presentation/widgets/shell/teacher_shell_scaffold.dart';

// Route paths
abstract class AppRoutes {
  // Auth routes
  static const schoolCode = '/school-code';
  static const login = '/login';

  // Student routes
  static const home = '/';
  static const library = '/library';
  static const bookDetail = '/library/book';
  static const reader = '/reader/:bookId/:chapterId';
  static const activity = '/activity/:chapterId';
  static const vocabulary = '/vocabulary';
  static const profile = '/profile';
  static const studentAssignments = '/assignments';
  static const studentAssignmentDetail = '/assignments/:assignmentId';

  // Teacher routes
  static const teacherDashboard = '/teacher';
  static const teacherClasses = '/teacher/classes';
  static const teacherClassDetail = '/teacher/classes/:classId';
  static const teacherStudentDetail = '/teacher/classes/:classId/student/:studentId';
  static const teacherAssignments = '/teacher/assignments';
  static const teacherCreateAssignment = '/teacher/assignments/create';
  static const teacherAssignmentDetail = '/teacher/assignments/:assignmentId';
  static const teacherReports = '/teacher/reports';
  static const teacherReportClassOverview = '/teacher/reports/class-overview';
  static const teacherReportReadingProgress = '/teacher/reports/reading-progress';
  static const teacherReportAssignments = '/teacher/reports/assignments';
  static const teacherReportLeaderboard = '/teacher/reports/leaderboard';
}

// Navigation shell keys
final _rootNavigatorKey = GlobalKey<NavigatorState>();

// Student shell keys
final _homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _libraryNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'library');
final _vocabularyNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'vocabulary');

// Teacher shell keys
final _teacherDashboardNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'teacherDashboard');
final _teacherClassesNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'teacherClasses');
final _teacherAssignmentsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'teacherAssignments');
final _teacherReportsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'teacherReports');

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: kDevBypassAuth ? AppRoutes.home : AppRoutes.schoolCode,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      // Skip auth redirect in development mode
      if (kDevBypassAuth) {
        return null;
      }

      final isAuthenticated = authState.valueOrNull != null;
      final isAuthRoute = state.matchedLocation == AppRoutes.schoolCode ||
          state.matchedLocation == AppRoutes.login;

      // Not authenticated - redirect to auth
      if (!isAuthenticated && !isAuthRoute) {
        return AppRoutes.schoolCode;
      }

      // Authenticated on auth route - redirect based on role
      if (isAuthenticated && isAuthRoute) {
        final role = authState.valueOrNull?.role;
        if (role == UserRole.teacher || role == UserRole.head || role == UserRole.admin) {
          return AppRoutes.teacherDashboard;
        }
        return AppRoutes.home;
      }

      // Role-based route protection
      if (isAuthenticated) {
        final role = authState.valueOrNull?.role;
        final isTeacherOrHigher = role == UserRole.teacher ||
                                   role == UserRole.head ||
                                   role == UserRole.admin;
        final isTeacherRoute = state.matchedLocation.startsWith('/teacher');

        // Teacher trying to access student home -> redirect to dashboard
        if (isTeacherOrHigher && state.matchedLocation == AppRoutes.home) {
          return AppRoutes.teacherDashboard;
        }

        // Student trying to access teacher routes -> redirect to home
        if (!isTeacherOrHigher && isTeacherRoute) {
          return AppRoutes.home;
        }
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

      // =============================================
      // STUDENT SHELL
      // =============================================
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

      // =============================================
      // TEACHER SHELL
      // =============================================
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return TeacherShellScaffold(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Dashboard
          StatefulShellBranch(
            navigatorKey: _teacherDashboardNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.teacherDashboard,
                name: 'teacherDashboard',
                builder: (context, state) => const TeacherDashboardScreen(),
              ),
            ],
          ),

          // Branch 1: Classes
          StatefulShellBranch(
            navigatorKey: _teacherClassesNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.teacherClasses,
                name: 'teacherClasses',
                builder: (context, state) => const ClassesScreen(),
              ),
            ],
          ),

          // Branch 2: Assignments
          StatefulShellBranch(
            navigatorKey: _teacherAssignmentsNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.teacherAssignments,
                name: 'teacherAssignments',
                builder: (context, state) => const AssignmentsScreen(),
              ),
            ],
          ),

          // Branch 3: Reports
          StatefulShellBranch(
            navigatorKey: _teacherReportsNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.teacherReports,
                name: 'teacherReports',
                builder: (context, state) => const ReportsScreen(),
              ),
            ],
          ),
        ],
      ),

      // =============================================
      // STANDALONE ROUTES (outside both shells)
      // =============================================

      // Profile route (full-screen)
      GoRoute(
        path: AppRoutes.profile,
        name: 'profile',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProfileScreen(),
      ),

      // Student assignments list (full-screen)
      GoRoute(
        path: AppRoutes.studentAssignments,
        name: 'studentAssignments',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const StudentAssignmentsScreen(),
      ),

      // Student assignment detail (full-screen)
      GoRoute(
        path: AppRoutes.studentAssignmentDetail,
        name: 'studentAssignmentDetail',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final assignmentId = state.pathParameters['assignmentId']!;
          return StudentAssignmentDetailScreen(assignmentId: assignmentId);
        },
      ),

      // Reader route (full-screen)
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

      // Activity route (full-screen)
      GoRoute(
        path: AppRoutes.activity,
        name: 'activity',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final chapterId = state.pathParameters['chapterId']!;
          return ActivityScreen(chapterId: chapterId);
        },
      ),

      // Class detail route (full-screen, teacher only)
      GoRoute(
        path: AppRoutes.teacherClassDetail,
        name: 'classDetail',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final classId = state.pathParameters['classId']!;
          return ClassDetailScreen(classId: classId);
        },
      ),

      // Student detail route (full-screen, teacher only)
      GoRoute(
        path: AppRoutes.teacherStudentDetail,
        name: 'studentDetail',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final studentId = state.pathParameters['studentId']!;
          return StudentDetailScreen(studentId: studentId);
        },
      ),

      // Create assignment route (full-screen, teacher only)
      GoRoute(
        path: AppRoutes.teacherCreateAssignment,
        name: 'createAssignment',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CreateAssignmentScreen(),
      ),

      // Assignment detail route (full-screen, teacher only)
      GoRoute(
        path: AppRoutes.teacherAssignmentDetail,
        name: 'assignmentDetail',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final assignmentId = state.pathParameters['assignmentId']!;
          return AssignmentDetailScreen(assignmentId: assignmentId);
        },
      ),

      // Report routes (full-screen, teacher only)
      GoRoute(
        path: AppRoutes.teacherReportClassOverview,
        name: 'reportClassOverview',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ClassOverviewReportScreen(),
      ),
      GoRoute(
        path: AppRoutes.teacherReportReadingProgress,
        name: 'reportReadingProgress',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ReadingProgressReportScreen(),
      ),
      GoRoute(
        path: AppRoutes.teacherReportAssignments,
        name: 'reportAssignments',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AssignmentReportScreen(),
      ),
      GoRoute(
        path: AppRoutes.teacherReportLeaderboard,
        name: 'reportLeaderboard',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LeaderboardReportScreen(),
      ),

    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.matchedLocation}'),
      ),
    ),
  );
});
