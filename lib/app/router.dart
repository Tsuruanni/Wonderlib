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
import '../presentation/screens/vocabulary/vocabulary_screen.dart';
import '../presentation/screens/vocabulary/word_list_detail_screen.dart';
import '../presentation/screens/vocabulary/category_browse_screen.dart';
import '../presentation/screens/vocabulary/vocabulary_session_screen.dart';
import '../presentation/screens/vocabulary/session_summary_screen.dart';
import '../presentation/screens/vocabulary/daily_review_screen.dart';
import '../presentation/screens/cards/card_collection_screen.dart';
import '../presentation/screens/cards/pack_opening_screen.dart';
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
  static const vocabularyDailyReview = '/vocabulary/daily-review';

  static const profile = '/profile';

  static const wordBank = '/word-bank';
  static const studentAssignments = '/assignments';
  static const studentAssignmentDetail = '/assignments/:assignmentId';
  // Teacher routes — dashboard now at /teacher/dashboard
  // Card collection routes
  static const cards = '/cards';
  static const packOpening = '/cards/open-pack';

  // Teacher routes — dashboard now at /teacher/dashboard
  static const teacherDashboard = '/teacher/dashboard';
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

  // Parameterized route helpers
  static String readerPath(String bookId, String chapterId) =>
      '/reader/$bookId/$chapterId';
  static String bookDetailPath(String bookId) => '/library/book/$bookId';
  static String studentAssignmentDetailPath(String assignmentId) =>
      '/assignments/$assignmentId';
  static String vocabularyListPath(String listId) =>
      '/vocabulary/list/$listId';
  static String vocabularySessionPath(String listId) =>
      '/vocabulary/list/$listId/session';
  static String vocabularySessionSummaryPath(String listId) =>
      '/vocabulary/list/$listId/session/summary';
  static String vocabularyCategoryPath(String categoryName) =>
      '/vocabulary/category/$categoryName';
  static String vocabularyUnitReviewPath(String unitId) =>
      '/vocabulary/unit-review/$unitId';

  static String teacherClassDetailPath(String classId) =>
      '/teacher/classes/$classId';
  static String teacherStudentDetailPath(String classId, String studentId) =>
      '/teacher/classes/$classId/student/$studentId';
  static String teacherAssignmentDetailPath(String assignmentId) =>
      '/teacher/assignments/$assignmentId';
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

// Navigator keys — one root, unique keys per shell branch
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _studentHomeKey = GlobalKey<NavigatorState>(debugLabel: 'studentHome');
final _studentLibraryKey = GlobalKey<NavigatorState>(debugLabel: 'studentLibrary');
final _studentVocabKey = GlobalKey<NavigatorState>(debugLabel: 'studentVocab');
final _studentCardsKey = GlobalKey<NavigatorState>(debugLabel: 'studentCards');
final _teacherDashboardKey = GlobalKey<NavigatorState>(debugLabel: 'teacherDashboard');
final _teacherClassesKey = GlobalKey<NavigatorState>(debugLabel: 'teacherClasses');
final _teacherAssignmentsKey = GlobalKey<NavigatorState>(debugLabel: 'teacherAssignments');
final _teacherReportsKey = GlobalKey<NavigatorState>(debugLabel: 'teacherReports');

GoRouter _createRouter() {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
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

        // Redirect bare /teacher to /teacher/dashboard
        if (state.matchedLocation == '/teacher') {
          return AppRoutes.teacherDashboard;
        }

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
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.splash,
        builder: (context, state) => const _SplashScreen(),
      ),

      // Auth route
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),

      // Student Shell — only StatefulShellRoute at top level
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state, navigationShell) {
          return MainShellScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _studentHomeKey,
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _studentLibraryKey,
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
            navigatorKey: _studentVocabKey,
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
                        path: 'session',
                        builder: (context, state) {
                          final listId = state.pathParameters['listId']!;
                          final retryWordIds = state.extra as List<String>?;
                          return VocabularySessionScreen(
                            listId: listId,
                            retryWordIds: retryWordIds,
                          );
                        },
                      ),
                      GoRoute(
                        path: 'session/summary',
                        builder: (context, state) {
                          final listId = state.pathParameters['listId']!;
                          return SessionSummaryScreen(listId: listId);
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'daily-review',
                    builder: (context, state) => const DailyReviewScreen(),
                  ),
                  GoRoute(
                    path: 'unit-review/:unitId',
                    builder: (context, state) {
                      final unitId = state.pathParameters['unitId']!;
                      return DailyReviewScreen(unitId: unitId);
                    },
                  ),
                  GoRoute(
                    path: 'word-bank',
                    builder: (context, state) => const VocabularyScreen(),
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
          StatefulShellBranch(
            navigatorKey: _studentCardsKey,
            routes: [
              GoRoute(
                path: AppRoutes.cards,
                builder: (context, state) => const CardCollectionScreen(),
              ),
            ],
          ),
        ],
      ),

      // Pack opening (standalone, full-screen immersive experience)
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.packOpening,
        builder: (context, state) => const PackOpeningScreen(),
      ),

      // Profile (standalone, accessed from home avatar)
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),

      // Teacher Shell — top-level StatefulShellRoute (same pattern as student shell)
      // Each branch uses full paths for proper goBranch() navigation
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state, navigationShell) {
          return TeacherShellScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _teacherDashboardKey,
            routes: [
              GoRoute(
                path: AppRoutes.teacherDashboard,
                builder: (context, state) => const TeacherDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _teacherClassesKey,
            routes: [
              GoRoute(
                path: AppRoutes.teacherClasses,
                builder: (context, state) => const ClassesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _teacherAssignmentsKey,
            routes: [
              GoRoute(
                path: AppRoutes.teacherAssignments,
                builder: (context, state) => const AssignmentsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _teacherReportsKey,
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
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.wordBank,
        builder: (context, state) => const VocabularyScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.studentAssignments,
        builder: (context, state) => const StudentAssignmentsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.studentAssignmentDetail,
        builder: (context, state) {
          final assignmentId = state.pathParameters['assignmentId']!;
          return StudentAssignmentDetailScreen(assignmentId: assignmentId);
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.reader,
        builder: (context, state) {
          final bookId = state.pathParameters['bookId']!;
          final chapterId = state.pathParameters['chapterId']!;
          return ReaderScreen(bookId: bookId, chapterId: chapterId);
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.activity,
        builder: (context, state) {
          final chapterId = state.pathParameters['chapterId']!;
          return ActivityScreen(chapterId: chapterId);
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.teacherClassDetail,
        builder: (context, state) {
          final classId = state.pathParameters['classId']!;
          return ClassDetailScreen(classId: classId);
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.teacherStudentDetail,
        builder: (context, state) {
          final studentId = state.pathParameters['studentId']!;
          return StudentDetailScreen(studentId: studentId);
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.teacherCreateAssignment,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return CreateAssignmentScreen(
            preSelectedBookId: extra?['bookId'] as String?,
            preSelectedBookTitle: extra?['bookTitle'] as String?,
            preSelectedBookChapterCount: extra?['chapterCount'] as int?,
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.teacherAssignmentDetail,
        builder: (context, state) {
          final assignmentId = state.pathParameters['assignmentId']!;
          return AssignmentDetailScreen(assignmentId: assignmentId);
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.teacherReportClassOverview,
        builder: (context, state) => const ClassOverviewReportScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.teacherReportReadingProgress,
        builder: (context, state) => const ReadingProgressReportScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.teacherReportAssignments,
        builder: (context, state) => const AssignmentReportScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
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
