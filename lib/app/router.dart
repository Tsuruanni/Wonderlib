import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
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
import '../presentation/widgets/shell/main_shell_scaffold.dart';
import '../presentation/widgets/shell/teacher_shell_scaffold.dart';

// Route paths
abstract class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const home = '/';
  static const library = '/library';
  static const bookDetail = '/library/book';
  static const reader = '/reader/:bookId/:chapterId';
  static const activity = '/activity/:chapterId';
  static const vocabulary = '/vocabulary';
  static const profile = '/profile';
  static const studentAssignments = '/assignments';
  static const studentAssignmentDetail = '/assignments/:assignmentId';
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

/// Splash screen that waits for auth to settle before navigating
class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Wait a frame to ensure GoRouter is ready
    await Future.delayed(const Duration(milliseconds: 100));

    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      context.go(AppRoutes.login);
    } else {
      // Check role from user metadata
      final metadata = session.user.userMetadata;
      final role = metadata?['role'] as String?;
      if (role == 'teacher' || role == 'head' || role == 'admin') {
        context.go(AppRoutes.teacherDashboard);
      } else {
        context.go(AppRoutes.home);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// Auth state notifier for GoRouter refresh
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      // Only notify for sign in/out, not initial session
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.signedOut) {
        notifyListeners();
      }
    });
  }
}

final _authNotifier = _AuthNotifier();

GoRouter _createRouter() {
  return GoRouter(
    initialLocation: kDevBypassAuth ? AppRoutes.home : AppRoutes.splash,
    debugLogDiagnostics: true,
    refreshListenable: _authNotifier,
    redirect: (context, state) {
      if (kDevBypassAuth) return null;

      // Don't redirect from splash - it handles its own navigation
      if (state.matchedLocation == AppRoutes.splash) {
        return null;
      }

      final session = Supabase.instance.client.auth.currentSession;
      final isAuthenticated = session != null;
      final isAuthRoute = state.matchedLocation == AppRoutes.login;

      // Not authenticated and not on auth route - go to login
      if (!isAuthenticated && !isAuthRoute) {
        return AppRoutes.login;
      }

      // Authenticated on login page - redirect based on role
      if (isAuthenticated && isAuthRoute) {
        final metadata = session.user.userMetadata;
        final role = metadata?['role'] as String?;
        if (role == 'teacher' || role == 'head' || role == 'admin') {
          return AppRoutes.teacherDashboard;
        }
        return AppRoutes.home;
      }

      // Role-based access control
      if (isAuthenticated) {
        final metadata = session.user.userMetadata;
        final role = metadata?['role'] as String?;
        final isTeacherOrHigher = role == 'teacher' || role == 'head' || role == 'admin';
        final isTeacherRoute = state.matchedLocation.startsWith('/teacher');

        if (isTeacherOrHigher && state.matchedLocation == AppRoutes.home) {
          return AppRoutes.teacherDashboard;
        }
        if (!isTeacherOrHigher && isTeacherRoute) {
          return AppRoutes.home;
        }
      }

      return null;
    },
    routes: [
      // Splash route - handles initial auth check
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const _SplashScreen(),
      ),

      // Auth route
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),

      // Student Shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShellScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.library,
                builder: (context, state) => const LibraryScreen(),
                routes: [
                  GoRoute(
                    path: 'book/:bookId',
                    builder: (context, state) {
                      final bookId = state.pathParameters['bookId']!;
                      return BookDetailScreen(bookId: bookId);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.vocabulary,
                builder: (context, state) => const VocabularyHubScreen(),
                routes: [
                  GoRoute(
                    path: 'list/:listId',
                    builder: (context, state) {
                      final listId = state.pathParameters['listId']!;
                      return WordListDetailScreen(listId: listId);
                    },
                    routes: [
                      GoRoute(
                        path: 'phase/1',
                        builder: (context, state) {
                          final listId = state.pathParameters['listId']!;
                          return Phase1LearnScreen(listId: listId);
                        },
                      ),
                      GoRoute(
                        path: 'phase/2',
                        builder: (context, state) {
                          final listId = state.pathParameters['listId']!;
                          return Phase2SpellingScreen(listId: listId);
                        },
                      ),
                      GoRoute(
                        path: 'phase/3',
                        builder: (context, state) {
                          final listId = state.pathParameters['listId']!;
                          return Phase3FlashcardsScreen(listId: listId);
                        },
                      ),
                      GoRoute(
                        path: 'phase/4',
                        builder: (context, state) {
                          final listId = state.pathParameters['listId']!;
                          return Phase4ReviewScreen(listId: listId);
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'category/:categoryName',
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

      // Teacher Shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return TeacherShellScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.teacherDashboard,
                builder: (context, state) => const TeacherDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.teacherClasses,
                builder: (context, state) => const ClassesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.teacherAssignments,
                builder: (context, state) => const AssignmentsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.teacherReports,
                builder: (context, state) => const ReportsScreen(),
              ),
            ],
          ),
        ],
      ),

      // Standalone routes
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.studentAssignments,
        builder: (context, state) => const StudentAssignmentsScreen(),
      ),
      GoRoute(
        path: AppRoutes.studentAssignmentDetail,
        builder: (context, state) {
          final assignmentId = state.pathParameters['assignmentId']!;
          return StudentAssignmentDetailScreen(assignmentId: assignmentId);
        },
      ),
      GoRoute(
        path: AppRoutes.reader,
        builder: (context, state) {
          final bookId = state.pathParameters['bookId']!;
          final chapterId = state.pathParameters['chapterId']!;
          return ReaderScreen(bookId: bookId, chapterId: chapterId);
        },
      ),
      GoRoute(
        path: AppRoutes.activity,
        builder: (context, state) {
          final chapterId = state.pathParameters['chapterId']!;
          return ActivityScreen(chapterId: chapterId);
        },
      ),
      GoRoute(
        path: AppRoutes.teacherClassDetail,
        builder: (context, state) {
          final classId = state.pathParameters['classId']!;
          return ClassDetailScreen(classId: classId);
        },
      ),
      GoRoute(
        path: AppRoutes.teacherStudentDetail,
        builder: (context, state) {
          final studentId = state.pathParameters['studentId']!;
          return StudentDetailScreen(studentId: studentId);
        },
      ),
      GoRoute(
        path: AppRoutes.teacherCreateAssignment,
        builder: (context, state) => const CreateAssignmentScreen(),
      ),
      GoRoute(
        path: AppRoutes.teacherAssignmentDetail,
        builder: (context, state) {
          final assignmentId = state.pathParameters['assignmentId']!;
          return AssignmentDetailScreen(assignmentId: assignmentId);
        },
      ),
      GoRoute(
        path: AppRoutes.teacherReportClassOverview,
        builder: (context, state) => const ClassOverviewReportScreen(),
      ),
      GoRoute(
        path: AppRoutes.teacherReportReadingProgress,
        builder: (context, state) => const ReadingProgressReportScreen(),
      ),
      GoRoute(
        path: AppRoutes.teacherReportAssignments,
        builder: (context, state) => const AssignmentReportScreen(),
      ),
      GoRoute(
        path: AppRoutes.teacherReportLeaderboard,
        builder: (context, state) => const LeaderboardReportScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.matchedLocation}'),
      ),
    ),
  );
}

// Create router once
final GoRouter _appRouter = _createRouter();

// Simple provider
final routerProvider = Provider<GoRouter>((ref) => _appRouter);
