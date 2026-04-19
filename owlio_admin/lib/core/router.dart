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
import '../features/users/screens/user_create_screen.dart';
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
import '../features/avatars/screens/avatar_management_screen.dart';
import '../features/avatars/screens/avatar_base_edit_screen.dart';
import '../features/avatars/screens/avatar_item_edit_screen.dart';
import '../features/avatars/screens/avatar_category_edit_screen.dart';
import '../features/classes/screens/class_list_screen.dart';
import '../features/classes/screens/class_edit_screen.dart';
import '../features/tiles/screens/tile_theme_list_screen.dart';
import '../features/tiles/screens/tile_theme_edit_screen.dart';
import '../features/treasure_wheel/screens/treasure_wheel_config_screen.dart';
import '../features/units/screens/unit_list_screen.dart';
import '../features/units/screens/unit_edit_screen.dart';
import 'supabase_client.dart';
import 'widgets/admin_shell.dart';

/// Router configuration for admin panel.
///
/// Structure:
/// - `/login` stands alone (no shell).
/// - All other routes are wrapped in a [StatefulShellRoute.indexedStack] with
///   17 branches. Branch order matches [kAdminNavEntries] in
///   `widgets/admin_nav_config.dart` — edit one without the other and the
///   sidebar will point to the wrong branch.
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
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AdminShell(navigationShell: navigationShell),
        branches: [
          // 0 — Overview (Genel Bakış)
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
          ]),
          // 1 — Books (Kitaplar)
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/books',
              builder: (_, __) => const BookListScreen(),
              routes: [
                GoRoute(path: 'import', builder: (_, __) => const BookJsonImportScreen()),
                GoRoute(path: 'new', builder: (_, __) => const BookEditScreen()),
                GoRoute(
                  path: ':bookId',
                  builder: (_, state) => BookEditScreen(bookId: state.pathParameters['bookId']),
                  routes: [
                    GoRoute(
                      path: 'chapters/new',
                      builder: (_, state) => ChapterEditScreen(bookId: state.pathParameters['bookId']!),
                    ),
                    GoRoute(
                      path: 'chapters/:chapterId',
                      builder: (_, state) => ChapterEditScreen(
                        bookId: state.pathParameters['bookId']!,
                        chapterId: state.pathParameters['chapterId'],
                      ),
                    ),
                    GoRoute(
                      path: 'quiz',
                      builder: (_, state) => BookQuizEditScreen(bookId: state.pathParameters['bookId']!),
                      routes: [
                        GoRoute(
                          path: 'questions/new',
                          builder: (_, state) => QuizQuestionEditScreen(
                            quizId: state.uri.queryParameters['quizId'] ?? '',
                          ),
                        ),
                        GoRoute(
                          path: 'questions/:questionId',
                          builder: (_, state) => QuizQuestionEditScreen(
                            quizId: state.uri.queryParameters['quizId'] ?? '',
                            questionId: state.pathParameters['questionId'],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ]),
          // 2 — Kelimeler (Vocabulary tab 0)
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/vocabulary',
              builder: (_, __) => const VocabularyListScreen(initialTab: 0),
              routes: [
                GoRoute(path: 'import', builder: (_, __) => const VocabularyImportScreen()),
                GoRoute(path: 'new', builder: (_, __) => const VocabularyEditScreen()),
                GoRoute(
                  path: ':wordId',
                  builder: (_, state) => VocabularyEditScreen(wordId: state.pathParameters['wordId']),
                ),
              ],
            ),
          ]),
          // 3 — Kelime Listeleri (Vocabulary tab 1)
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/wordlists',
              builder: (_, __) => const VocabularyListScreen(initialTab: 1),
              routes: [
                GoRoute(path: 'new', builder: (_, __) => const WordlistEditScreen()),
                GoRoute(
                  path: ':listId',
                  builder: (_, state) => WordlistEditScreen(listId: state.pathParameters['listId']),
                ),
              ],
            ),
          ]),
          // 4 — Schools (Okullar)
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/schools',
              builder: (_, __) => const SchoolListScreen(),
              routes: [
                GoRoute(path: 'new', builder: (_, __) => const SchoolEditScreen()),
                GoRoute(
                  path: ':schoolId',
                  builder: (_, state) => SchoolEditScreen(schoolId: state.pathParameters['schoolId']),
                ),
              ],
            ),
          ]),
          // 5 — Classes (Sınıflar)
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/classes',
              builder: (_, __) => const ClassListScreen(),
              routes: [
                GoRoute(path: 'new', builder: (_, __) => const ClassEditScreen()),
                GoRoute(
                  path: ':classId',
                  builder: (_, state) => ClassEditScreen(classId: state.pathParameters['classId']),
                ),
              ],
            ),
          ]),
          // 6 — Users (Kullanıcılar)
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/users',
              builder: (_, __) => const UserListScreen(),
              routes: [
                GoRoute(path: 'create', builder: (_, __) => const UserCreateScreen()),
                GoRoute(
                  path: ':userId',
                  builder: (_, state) => UserEditScreen(userId: state.pathParameters['userId']!),
                ),
              ],
            ),
          ]),
          // 7 — Recent Activity (Son Etkinlikler)
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/recent-activity',
              builder: (_, __) => const RecentActivityScreen(),
              routes: [
                GoRoute(
                  path: ':sectionKey',
                  builder: (_, state) => RecentActivityDetailScreen(
                    sectionKey: state.pathParameters['sectionKey']!,
                  ),
                ),
              ],
            ),
          ]),
          // 8 — Learning Paths (Öğrenme Yolları)
          StatefulShellBranch(routes: [
            GoRoute(path: '/learning-paths', builder: (_, __) => const LearningPathsScreen()),
            GoRoute(
              path: '/templates',
              builder: (_, __) => const LearningPathsScreen(),
              routes: [
                GoRoute(path: 'new', builder: (_, __) => const TemplateEditScreen()),
                GoRoute(
                  path: ':templateId',
                  builder: (_, state) => TemplateEditScreen(templateId: state.pathParameters['templateId']),
                ),
              ],
            ),
            GoRoute(
              path: '/learning-path-assignments/new',
              builder: (_, state) => AssignmentScreen(
                initialSchoolId: state.uri.queryParameters['schoolId'],
                initialGrade: int.tryParse(state.uri.queryParameters['grade'] ?? ''),
                initialClassId: state.uri.queryParameters['classId'],
              ),
            ),
            GoRoute(
              path: '/assignments',
              builder: (_, __) => const AssignmentListScreen(),
              routes: [
                GoRoute(
                  path: ':assignmentId',
                  builder: (_, state) => AssignmentDetailScreen(
                    assignmentId: state.pathParameters['assignmentId']!,
                  ),
                ),
              ],
            ),
            GoRoute(
              path: '/units',
              builder: (_, __) => const UnitListScreen(),
              routes: [
                GoRoute(path: 'new', builder: (_, __) => const UnitEditScreen()),
                GoRoute(
                  path: ':unitId',
                  builder: (_, state) => UnitEditScreen(unitId: state.pathParameters['unitId']),
                ),
              ],
            ),
          ]),
          // 9 — Tiles (Tile Temaları) — moved to ÖĞRENME
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/tiles',
              builder: (_, __) => const TileThemeListScreen(),
              routes: [
                GoRoute(path: 'new', builder: (_, __) => const TileThemeEditScreen()),
                GoRoute(
                  path: ':themeId',
                  builder: (_, state) => TileThemeEditScreen(themeId: state.pathParameters['themeId']),
                ),
              ],
            ),
          ]),
          // 10 — Rozetler (Badges) — owns /collectibles default + /badges
          StatefulShellBranch(routes: [
            GoRoute(path: '/collectibles', builder: (_, __) => const CollectiblesScreen()),
            GoRoute(
              path: '/badges',
              builder: (_, __) => const CollectiblesScreen(initialTab: 0),
              routes: [
                GoRoute(path: 'new', builder: (_, __) => const BadgeEditScreen()),
                GoRoute(
                  path: ':badgeId',
                  builder: (_, state) => BadgeEditScreen(badgeId: state.pathParameters['badgeId']),
                ),
              ],
            ),
          ]),
          // 11 — Mitoloji Kartları (Cards)
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/cards',
              builder: (_, __) => const CollectiblesScreen(initialTab: 1),
              routes: [
                GoRoute(path: 'new', builder: (_, __) => const CardEditScreen()),
                GoRoute(
                  path: ':cardId',
                  builder: (_, state) => CardEditScreen(cardId: state.pathParameters['cardId']),
                ),
              ],
            ),
          ]),
          // 12 — Quests (Günlük Görevler)
          StatefulShellBranch(routes: [
            GoRoute(path: '/quests', builder: (_, __) => const QuestListScreen()),
          ]),
          // 13 — Treasure Wheel (Hazine Çarkı)
          StatefulShellBranch(routes: [
            GoRoute(path: '/treasure-wheel', builder: (_, __) => const TreasureWheelConfigScreen()),
          ]),
          // 14 — Avatars (Avatar Yönetimi)
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/avatars',
              builder: (_, __) => const AvatarManagementScreen(),
              routes: [
                GoRoute(path: 'bases/new', builder: (_, __) => const AvatarBaseEditScreen()),
                GoRoute(
                  path: 'bases/:id',
                  builder: (_, state) => AvatarBaseEditScreen(baseId: state.pathParameters['id']),
                ),
                GoRoute(path: 'items/new', builder: (_, __) => const AvatarItemEditScreen()),
                GoRoute(
                  path: 'items/:id',
                  builder: (_, state) => AvatarItemEditScreen(itemId: state.pathParameters['id']),
                ),
                GoRoute(path: 'categories/new', builder: (_, __) => const AvatarCategoryEditScreen()),
                GoRoute(
                  path: 'categories/:id',
                  builder: (_, state) =>
                      AvatarCategoryEditScreen(categoryId: state.pathParameters['id']),
                ),
              ],
            ),
          ]),
          // 15 — Notifications (Bildirimler)
          StatefulShellBranch(routes: [
            GoRoute(path: '/notifications', builder: (_, __) => const NotificationGalleryScreen()),
          ]),
          // 16 — Settings (Ayarlar)
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/settings',
              builder: (_, __) => const SettingsScreen(
                title: 'Ayarlar',
                categories: ['xp_reading', 'xp_vocab', 'progression', 'game', 'app'],
              ),
            ),
          ]),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Sayfa bulunamadı: ${state.matchedLocation}')),
    ),
  );
});
