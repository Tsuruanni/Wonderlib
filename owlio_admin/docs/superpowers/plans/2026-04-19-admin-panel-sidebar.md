# Admin Panel Sidebar Refactor — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the admin dashboard's 15-card grid with a persistent left-sidebar navigation using `StatefulShellRoute.indexedStack`, and convert the dashboard into a stats-only Overview screen.

**Architecture:** A single `StatefulShellRoute.indexedStack` wraps all authenticated routes into 16 branches (one per sidebar item). The shell widget renders `Row([AdminSidebar, Expanded(navigationShell)])`. Each section keeps its own per-branch Navigator, so editing state survives tab switches. Per-screen `Scaffold` + `AppBar` stays untouched; logout moves from the dashboard AppBar to the sidebar footer. A shared `AdminNavEntry` config is the single source of truth for branch index ↔ route ↔ icon/label mapping.

**Tech Stack:** Flutter, go_router 14.8+, flutter_riverpod 2.6+, Material 3.

**Spec:** `docs/superpowers/specs/2026-04-19-admin-panel-sidebar-design.md`

---

## File Structure

### New files

| File | Responsibility |
|------|----------------|
| `lib/core/widgets/admin_nav_config.dart` | Static `AdminNavEntry` data class + `kAdminNavEntries` list. Single source of truth for branch order, icon, label, root path, group label. Imported by both router and sidebar. |
| `lib/core/widgets/admin_nav_list_item.dart` | Single clickable sidebar item widget — icon + label + active-state styling. Stateless, pure. |
| `lib/core/widgets/admin_sidebar.dart` | Full sidebar: header, scrollable group list (built from `kAdminNavEntries`), user footer with logout. Consumes `currentAdminUserProvider`. |
| `lib/core/widgets/admin_shell.dart` | `Row([AdminSidebar, Expanded(navigationShell)])`. Receives `StatefulNavigationShell` from go_router. |
| `test/core/widgets/admin_sidebar_test.dart` | Widget tests for sidebar active-state + tap callbacks. |

### Modified files

| File | Change |
|------|--------|
| `lib/core/router.dart` | Rewrite: wrap authenticated routes in `StatefulShellRoute.indexedStack` with 16 branches. `/login` stays outside. |
| `lib/features/dashboard/screens/dashboard_screen.dart` | Strip 15 `_DashboardCard` widgets and AppBar `PopupMenuButton` logout. Replace with stats-only grid using existing `dashboardStatsProvider`. |

---

## Task 1: Shared nav config

**Files:**
- Create: `lib/core/widgets/admin_nav_config.dart`

- [ ] **Step 1.1: Create the nav config file**

Write `lib/core/widgets/admin_nav_config.dart`:

```dart
import 'package:flutter/material.dart';

/// Single source of truth for admin sidebar branches.
///
/// List order = branch index in StatefulShellRoute. Router reads this to
/// build branches; sidebar reads this to render items. Keeping both in sync
/// is a hard requirement — never edit one without the other.
class AdminNavEntry {
  const AdminNavEntry({
    required this.rootPath,
    required this.icon,
    required this.label,
    required this.group,
  });

  final String rootPath;
  final IconData icon;
  final String label;
  final String group;
}

/// Special group label for items that render standalone (no group header).
const String kStandaloneGroup = '';

/// Branch index = position in this list. Order matters.
const List<AdminNavEntry> kAdminNavEntries = [
  // 0 — standalone
  AdminNavEntry(
    rootPath: '/',
    icon: Icons.dashboard_outlined,
    label: 'Genel Bakış',
    group: kStandaloneGroup,
  ),
  // İÇERİK
  AdminNavEntry(
    rootPath: '/books',
    icon: Icons.menu_book,
    label: 'Kitaplar',
    group: 'İÇERİK',
  ),
  AdminNavEntry(
    rootPath: '/vocabulary',
    icon: Icons.abc,
    label: 'Kelime Havuzu',
    group: 'İÇERİK',
  ),
  AdminNavEntry(
    rootPath: '/units',
    icon: Icons.grid_view_rounded,
    label: 'Üniteler',
    group: 'İÇERİK',
  ),
  // KULLANICILAR
  AdminNavEntry(
    rootPath: '/schools',
    icon: Icons.school,
    label: 'Okullar',
    group: 'KULLANICILAR',
  ),
  AdminNavEntry(
    rootPath: '/classes',
    icon: Icons.class_,
    label: 'Sınıflar',
    group: 'KULLANICILAR',
  ),
  AdminNavEntry(
    rootPath: '/users',
    icon: Icons.people,
    label: 'Kullanıcılar',
    group: 'KULLANICILAR',
  ),
  AdminNavEntry(
    rootPath: '/recent-activity',
    icon: Icons.timeline,
    label: 'Son Etkinlikler',
    group: 'KULLANICILAR',
  ),
  // ÖĞRENME
  AdminNavEntry(
    rootPath: '/learning-paths',
    icon: Icons.route,
    label: 'Öğrenme Yolları',
    group: 'ÖĞRENME',
  ),
  // OYUNLAŞTIRMA
  AdminNavEntry(
    rootPath: '/collectibles',
    icon: Icons.emoji_events,
    label: 'Koleksiyon',
    group: 'OYUNLAŞTIRMA',
  ),
  AdminNavEntry(
    rootPath: '/quests',
    icon: Icons.bolt,
    label: 'Daily Quests',
    group: 'OYUNLAŞTIRMA',
  ),
  AdminNavEntry(
    rootPath: '/treasure-wheel',
    icon: Icons.casino,
    label: 'Hazine Çarkı',
    group: 'OYUNLAŞTIRMA',
  ),
  AdminNavEntry(
    rootPath: '/avatars',
    icon: Icons.face,
    label: 'Avatar Yönetimi',
    group: 'OYUNLAŞTIRMA',
  ),
  AdminNavEntry(
    rootPath: '/tiles',
    icon: Icons.map,
    label: 'Tile Temaları',
    group: 'OYUNLAŞTIRMA',
  ),
  // SİSTEM
  AdminNavEntry(
    rootPath: '/notifications',
    icon: Icons.notifications_active,
    label: 'Notifications',
    group: 'SİSTEM',
  ),
  AdminNavEntry(
    rootPath: '/settings',
    icon: Icons.settings,
    label: 'Ayarlar',
    group: 'SİSTEM',
  ),
];
```

- [ ] **Step 1.2: Verify compiles**

Run: `cd /Users/wonderelt/Desktop/Owlio/owlio_admin && dart analyze lib/core/widgets/admin_nav_config.dart`
Expected: `No issues found!`

- [ ] **Step 1.3: Commit**

```bash
cd /Users/wonderelt/Desktop/Owlio/owlio_admin
git add lib/core/widgets/admin_nav_config.dart
git commit -m "feat(admin): add admin nav config as single source of truth"
```

---

## Task 2: Sidebar list item widget

**Files:**
- Create: `lib/core/widgets/admin_nav_list_item.dart`

- [ ] **Step 2.1: Create widget file**

Write `lib/core/widgets/admin_nav_list_item.dart`:

```dart
import 'package:flutter/material.dart';

/// A single clickable sidebar item.
///
/// - Active state: indigo tint background + 3px left accent bar + indigo icon/text.
/// - Hover: light grey background.
/// - Inactive: transparent.
class AdminNavListItem extends StatelessWidget {
  const AdminNavListItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  static const Color _accent = Color(0xFF4F46E5);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: isActive ? _accent.withValues(alpha: 0.1) : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: isActive ? _accent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 17),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isActive ? _accent : Colors.grey.shade700,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: isActive ? _accent : Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2.2: Verify compiles**

Run: `cd /Users/wonderelt/Desktop/Owlio/owlio_admin && dart analyze lib/core/widgets/admin_nav_list_item.dart`
Expected: `No issues found!`

- [ ] **Step 2.3: Commit**

```bash
cd /Users/wonderelt/Desktop/Owlio/owlio_admin
git add lib/core/widgets/admin_nav_list_item.dart
git commit -m "feat(admin): add AdminNavListItem widget"
```

---

## Task 3: Sidebar composition widget

**Files:**
- Create: `lib/core/widgets/admin_sidebar.dart`

- [ ] **Step 3.1: Create sidebar widget**

Write `lib/core/widgets/admin_sidebar.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../supabase_client.dart';
import 'admin_nav_config.dart';
import 'admin_nav_list_item.dart';

/// Persistent left-hand navigation for the admin panel.
///
/// Width is fixed at 260px (admin is desktop-only). Renders nav entries from
/// [kAdminNavEntries], grouping them by their [AdminNavEntry.group] label.
/// Footer shows current user email + logout.
class AdminSidebar extends ConsumerWidget {
  const AdminSidebar({
    super.key,
    required this.currentIndex,
    required this.onBranchSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onBranchSelected;

  static const double width = 260;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentAdminUserProvider);

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          _Header(),
          Expanded(child: _NavList(currentIndex: currentIndex, onBranchSelected: onBranchSelected)),
          _Footer(
            email: userAsync.valueOrNull?.email,
            onLogout: () async {
              await ref.read(supabaseClientProvider).auth.signOut();
            },
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Text(
              'O',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Owlio Admin',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _NavList extends StatelessWidget {
  const _NavList({required this.currentIndex, required this.onBranchSelected});

  final int currentIndex;
  final ValueChanged<int> onBranchSelected;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[const SizedBox(height: 8)];
    String? lastGroup;
    for (var i = 0; i < kAdminNavEntries.length; i++) {
      final entry = kAdminNavEntries[i];
      if (entry.group != lastGroup && entry.group != kStandaloneGroup) {
        children.add(const SizedBox(height: 16));
        children.add(_GroupHeader(label: entry.group));
        lastGroup = entry.group;
      } else if (entry.group == kStandaloneGroup && lastGroup != null) {
        // Standalone after groups — unusual; add spacing.
        children.add(const SizedBox(height: 8));
        lastGroup = null;
      }
      children.add(AdminNavListItem(
        icon: entry.icon,
        label: entry.label,
        isActive: i == currentIndex,
        onTap: () => onBranchSelected(i),
      ));
    }
    children.add(const SizedBox(height: 16));
    return SingleChildScrollView(child: Column(children: children));
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.email, required this.onLogout});
  final String? email;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFF4F46E5),
            child: Text(
              (email?.substring(0, 1) ?? 'A').toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              email ?? 'Yönetici',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 18),
            tooltip: 'Çıkış Yap',
            onPressed: onLogout,
            color: Colors.grey.shade700,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3.2: Verify compiles**

Run: `cd /Users/wonderelt/Desktop/Owlio/owlio_admin && dart analyze lib/core/widgets/admin_sidebar.dart`
Expected: `No issues found!`

- [ ] **Step 3.3: Commit**

```bash
cd /Users/wonderelt/Desktop/Owlio/owlio_admin
git add lib/core/widgets/admin_sidebar.dart
git commit -m "feat(admin): add AdminSidebar with grouped nav + footer logout"
```

---

## Task 4: Widget test for sidebar

**Files:**
- Create: `test/core/widgets/admin_sidebar_test.dart`

- [ ] **Step 4.1: Write failing test**

Write `test/core/widgets/admin_sidebar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owlio_admin/core/widgets/admin_nav_list_item.dart';

void main() {
  group('AdminNavListItem', () {
    testWidgets('renders icon and label', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AdminNavListItem(
            icon: Icons.menu_book,
            label: 'Kitaplar',
            isActive: false,
            onTap: () {},
          ),
        ),
      ));

      expect(find.byIcon(Icons.menu_book), findsOneWidget);
      expect(find.text('Kitaplar'), findsOneWidget);
    });

    testWidgets('fires onTap callback when tapped', (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AdminNavListItem(
            icon: Icons.menu_book,
            label: 'Kitaplar',
            isActive: false,
            onTap: () => tapCount++,
          ),
        ),
      ));

      await tester.tap(find.text('Kitaplar'));
      await tester.pump();
      expect(tapCount, 1);
    });

    testWidgets('active item uses accent color for text', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AdminNavListItem(
            icon: Icons.menu_book,
            label: 'Kitaplar',
            isActive: true,
            onTap: () {},
          ),
        ),
      ));

      final text = tester.widget<Text>(find.text('Kitaplar'));
      expect(text.style?.color, const Color(0xFF4F46E5));
      expect(text.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('inactive item uses grey color', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AdminNavListItem(
            icon: Icons.menu_book,
            label: 'Kitaplar',
            isActive: false,
            onTap: () {},
          ),
        ),
      ));

      final text = tester.widget<Text>(find.text('Kitaplar'));
      expect(text.style?.color, Colors.grey.shade800);
    });
  });
}
```

- [ ] **Step 4.2: Run test**

Run: `cd /Users/wonderelt/Desktop/Owlio/owlio_admin && flutter test test/core/widgets/admin_sidebar_test.dart`
Expected: all 4 tests PASS (implementation was written in Task 2).

- [ ] **Step 4.3: Commit**

```bash
cd /Users/wonderelt/Desktop/Owlio/owlio_admin
git add test/core/widgets/admin_sidebar_test.dart
git commit -m "test(admin): widget tests for AdminNavListItem"
```

---

## Task 5: AdminShell widget

**Files:**
- Create: `lib/core/widgets/admin_shell.dart`

- [ ] **Step 5.1: Create shell widget**

Write `lib/core/widgets/admin_shell.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'admin_sidebar.dart';

/// Shell wrapper for all authenticated admin routes.
///
/// Receives a [StatefulNavigationShell] from go_router's
/// [StatefulShellRoute.indexedStack]. Renders the sidebar on the left and the
/// active branch's Navigator on the right.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          AdminSidebar(
            currentIndex: navigationShell.currentIndex,
            onBranchSelected: (index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            ),
          ),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5.2: Verify compiles**

Run: `cd /Users/wonderelt/Desktop/Owlio/owlio_admin && dart analyze lib/core/widgets/admin_shell.dart`
Expected: `No issues found!`

- [ ] **Step 5.3: Commit**

```bash
cd /Users/wonderelt/Desktop/Owlio/owlio_admin
git add lib/core/widgets/admin_shell.dart
git commit -m "feat(admin): add AdminShell wrapping StatefulNavigationShell"
```

Note: `initialLocation: index == navigationShell.currentIndex` means: tapping the already-active item pops the branch's nav stack back to its root (e.g., from `/books/abc` back to `/books`). Standard UX for navbar items.

---

## Task 6: Refactor Overview (ex-dashboard) screen

**Files:**
- Modify: `lib/features/dashboard/screens/dashboard_screen.dart`

- [ ] **Step 6.1: Rewrite the file**

Replace the entire contents of `lib/features/dashboard/screens/dashboard_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // CountOption

import '../../../core/supabase_client.dart';

// ============================================
// DASHBOARD STATS PROVIDER
// ============================================

final dashboardStatsProvider =
    FutureProvider<Map<String, int>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);

  final results = await Future.wait([
    supabase.from(DbTables.books).select().count(CountOption.exact),
    supabase.from(DbTables.schools).select().count(CountOption.exact),
    supabase.from(DbTables.classes).select().count(CountOption.exact),
    supabase.from(DbTables.profiles).select().count(CountOption.exact),
    supabase.from(DbTables.badges).select().count(CountOption.exact),
    supabase.from(DbTables.vocabularyWords).select().count(CountOption.exact),
    supabase.from(DbTables.wordLists).select().eq('is_system', true).count(CountOption.exact),
    supabase.from(DbTables.learningPathTemplates).select().count(CountOption.exact),
    supabase.from(DbTables.scopeLearningPaths).select().count(CountOption.exact),
    supabase.from(DbTables.dailyQuests).select().eq('is_active', true).count(CountOption.exact),
  ]);

  return {
    'books': results[0].count,
    'schools': results[1].count,
    'classes': results[2].count,
    'users': results[3].count,
    'badges': results[4].count,
    'words': results[5].count,
    'wordlists': results[6].count,
    'templates': results[7].count,
    'assignments': results[8].count,
    'quests': results[9].count,
  };
});

// ============================================
// SCREEN
// ============================================

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final stats = statsAsync.valueOrNull ?? {};

    return Scaffold(
      appBar: AppBar(title: const Text('Genel Bakış')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Owlio Yönetim Paneline Hoş Geldiniz',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Okuma platformunuz için genel istatistikler.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth > 1200
                      ? 5
                      : constraints.maxWidth > 800
                          ? 4
                          : 2;
                  return GridView.count(
                    crossAxisCount: columns,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.8,
                    children: [
                      _StatTile(label: 'Kitap', value: stats['books'], color: const Color(0xFF4F46E5)),
                      _StatTile(label: 'Okul', value: stats['schools'], color: const Color(0xFFE11D48)),
                      _StatTile(label: 'Sınıf', value: stats['classes'], color: const Color(0xFFDB2777)),
                      _StatTile(label: 'Kullanıcı', value: stats['users'], color: const Color(0xFF7C3AED)),
                      _StatTile(label: 'Rozet', value: stats['badges'], color: const Color(0xFFF59E0B)),
                      _StatTile(label: 'Kelime', value: stats['words'], color: const Color(0xFF059669)),
                      _StatTile(label: 'Kelime Listesi', value: stats['wordlists'], color: const Color(0xFF10B981)),
                      _StatTile(label: 'Yol Şablonu', value: stats['templates'], color: const Color(0xFFEA580C)),
                      _StatTile(label: 'Atama', value: stats['assignments'], color: const Color(0xFF0891B2)),
                      _StatTile(label: 'Aktif Quest', value: stats['quests'], color: const Color(0xFFF97316)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// STAT TILE
// ============================================

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.color});

  final String label;
  final int? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value?.toString() ?? '—',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
```

Notes for the engineer:
- `go_router` import is gone from this file — `context.go` is no longer called here.
- `supabase_flutter` stays — it's needed for the `CountOption` enum used in the stats provider.
- `User` type is gone (AppBar PopupMenu removed). `currentAdminUserProvider` is no longer watched here.
- The old `_DashboardCard` class is intentionally deleted; stats use the new `_StatTile` instead.

- [ ] **Step 6.2: Verify compiles**

Run: `cd /Users/wonderelt/Desktop/Owlio/owlio_admin && dart analyze lib/features/dashboard/screens/dashboard_screen.dart`
Expected: `No issues found!` (no unused imports, no undefined references)

- [ ] **Step 6.3: Commit**

```bash
cd /Users/wonderelt/Desktop/Owlio/owlio_admin
git add lib/features/dashboard/screens/dashboard_screen.dart
git commit -m "refactor(admin): strip dashboard cards, replace with stats grid"
```

---

## Task 7: Refactor router with StatefulShellRoute

**Files:**
- Modify: `lib/core/router.dart`

- [ ] **Step 7.1: Rewrite router to use StatefulShellRoute.indexedStack**

Replace the entire contents of `lib/core/router.dart` with:

```dart
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
///   16 branches. Branch order matches [kAdminNavEntries] in
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
          // 2 — Vocabulary (Kelime Havuzu) — also owns /wordlists/*
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/vocabulary',
              builder: (_, __) => const VocabularyListScreen(),
              routes: [
                GoRoute(path: 'import', builder: (_, __) => const VocabularyImportScreen()),
                GoRoute(path: 'new', builder: (_, __) => const VocabularyEditScreen()),
                GoRoute(
                  path: ':wordId',
                  builder: (_, state) => VocabularyEditScreen(wordId: state.pathParameters['wordId']),
                ),
              ],
            ),
            GoRoute(
              path: '/wordlists/new',
              builder: (_, __) => const WordlistEditScreen(),
            ),
            GoRoute(
              path: '/wordlists/:listId',
              builder: (_, state) => WordlistEditScreen(listId: state.pathParameters['listId']),
            ),
          ]),
          // 3 — Units (Üniteler)
          StatefulShellBranch(routes: [
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
          // 8 — Learning Paths (Öğrenme Yolları) — owns /templates, /assignments, /learning-path-assignments
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
          ]),
          // 9 — Collectibles (Koleksiyon) — owns /badges, /cards
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
          // 10 — Quests (Daily Quests)
          StatefulShellBranch(routes: [
            GoRoute(path: '/quests', builder: (_, __) => const QuestListScreen()),
          ]),
          // 11 — Treasure Wheel (Hazine Çarkı)
          StatefulShellBranch(routes: [
            GoRoute(path: '/treasure-wheel', builder: (_, __) => const TreasureWheelConfigScreen()),
          ]),
          // 12 — Avatars (Avatar Yönetimi)
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
          // 13 — Tiles (Tile Temaları)
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
          // 14 — Notifications
          StatefulShellBranch(routes: [
            GoRoute(path: '/notifications', builder: (_, __) => const NotificationGalleryScreen()),
          ]),
          // 15 — Settings (Ayarlar)
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
```

**Key notes for the engineer:**
1. Child routes that use nested `routes:` must drop the parent prefix. `GoRoute(path: '/books/new')` at top level → `GoRoute(path: 'new')` nested under `GoRoute(path: '/books')`. I've already handled this in the rewrite above.
2. Branches 10, 11, 14, 15 have only one route each — that's intentional (simple sections).
3. Branch 8 (Learning Paths) owns `/templates`, `/assignments`, and `/learning-path-assignments/*` since all these are logically part of the "Learning Paths" section.
4. Branch 2 (Vocabulary) also owns `/wordlists/new` and `/wordlists/:listId` because wordlists are edited from inside the vocabulary section.

- [ ] **Step 7.2: Verify compiles**

Run: `cd /Users/wonderelt/Desktop/Owlio/owlio_admin && dart analyze lib/core/router.dart`
Expected: `No issues found!`

If there are errors like "undefined name LearningPathsScreen": that class is defined in one of the existing template screen files (probably `template_list_screen.dart`). Keep the same import as before; if it's a re-exported widget, no change needed.

- [ ] **Step 7.3: Full lib analyze**

Run: `cd /Users/wonderelt/Desktop/Owlio/owlio_admin && dart analyze lib/`
Expected: `No issues found!` (or only pre-existing warnings not introduced by this task)

- [ ] **Step 7.4: Commit**

```bash
cd /Users/wonderelt/Desktop/Owlio/owlio_admin
git add lib/core/router.dart
git commit -m "refactor(admin): wire StatefulShellRoute.indexedStack with 16 branches"
```

---

## Task 8: Run widget tests

- [ ] **Step 8.1: Run sidebar widget tests**

Run: `cd /Users/wonderelt/Desktop/Owlio/owlio_admin && flutter test test/core/widgets/admin_sidebar_test.dart`
Expected: 4 tests PASS.

- [ ] **Step 8.2: If the default `test/widget_test.dart` still fails**

The pre-existing `test/widget_test.dart` references `MyApp` which doesn't exist (the real class is `OwlioAdminApp`). If this test was broken before the refactor, leave it broken. If it blocks CI, delete it:

Run (only if CI is blocked): `rm test/widget_test.dart`

Do NOT rewrite it — out of scope for this refactor.

---

## Task 9: Manual browser verification

- [ ] **Step 9.1: Launch the app**

Run: `cd /Users/wonderelt/Desktop/Owlio/owlio_admin && flutter run -d chrome`

- [ ] **Step 9.2: Login smoke test**

1. Log in with admin credentials (`admin@demo.com` / `Test1234` / school code `DEMO123`).
2. Expected landing: Overview screen at `/` with stats grid visible, sidebar on the left showing "Genel Bakış" active.

- [ ] **Step 9.3: Click every sidebar item**

For each of the 16 items in the sidebar:
- Click the item.
- Expected: URL updates to that item's `rootPath`; content swaps in the expanded area; clicked item highlighted (indigo tint + left accent bar); other items return to neutral.
- Sidebar itself does NOT re-render/flash — it stays put.

- [ ] **Step 9.4: State preservation test**

1. Go to Books (`/books`), click a book to enter edit screen (`/books/:id`).
2. Switch to Users (`/users`) via sidebar.
3. Switch back to Books.
4. Expected: You land back on `/books/:id` (same book-edit screen), not on `/books` list.

- [ ] **Step 9.5: Active-item-tap-pops behavior**

1. Navigate to `/books/:id` (inside Books branch).
2. Click "Kitaplar" in the sidebar (the currently-active branch).
3. Expected: Navigator pops to `/books` list.

- [ ] **Step 9.6: Deep link test**

In the browser address bar, type `/users/:someUserId` (replace with a real user ID from the user list) and press Enter.
Expected: Shell renders, Users sidebar item is active, user edit screen is shown.

- [ ] **Step 9.7: Logout test**

Click the logout icon in the sidebar footer.
Expected: Session ends, redirected to `/login`. Sidebar is NOT visible on the login screen.

- [ ] **Step 9.8: Cross-branch go check**

Find any place where one screen uses `context.go('/otherBranchRoot')` (e.g., a create-assignment button in Classes that jumps to Learning Paths). Verify:
- The active branch changes in the sidebar.
- The Navigator state of the origin branch is preserved if user switches back via sidebar.

- [ ] **Step 9.9: Console error check**

Check browser DevTools console for red errors throughout the smoke test.
Expected: No `StatefulShellRoute`-related errors, no `initialLocation` missing errors.

---

## Task 10: Final cleanup + summary commit

- [ ] **Step 10.1: Final analyze**

Run: `cd /Users/wonderelt/Desktop/Owlio/owlio_admin && dart analyze lib/`
Expected: No new issues vs. baseline.

- [ ] **Step 10.2: If anything was left uncommitted, commit it**

```bash
cd /Users/wonderelt/Desktop/Owlio/owlio_admin
git status
```

If anything non-trivial is modified but unstaged, review and commit with an appropriate message. If nothing, skip.

- [ ] **Step 10.3: Verify all commits present**

Run: `git log --oneline -10`
Expected: 7 new commits from this plan:
1. `feat(admin): add admin nav config as single source of truth`
2. `feat(admin): add AdminNavListItem widget`
3. `feat(admin): add AdminSidebar with grouped nav + footer logout`
4. `test(admin): widget tests for AdminNavListItem`
5. `feat(admin): add AdminShell wrapping StatefulNavigationShell`
6. `refactor(admin): strip dashboard cards, replace with stats grid`
7. `refactor(admin): wire StatefulShellRoute.indexedStack with 16 branches`

---

## Success Criteria Recap

Before declaring done, all of these must hold (from the spec):

1. ✅ Login → Overview inside shell (sidebar left, stats right).
2. ✅ Clicking any sidebar item swaps content; sidebar persists; active item highlighted.
3. ✅ Book-edit state survives tab switches.
4. ✅ Deep-link to `/vocabulary/:wordId` activates Vocabulary branch.
5. ✅ Logout from sidebar footer signs out → `/login`; shell gone.
6. ✅ Overview shows 10 stats; no cards remain.
7. ✅ All 16 sections render correctly with sidebar.
8. ✅ `dart analyze lib/` passes with zero new warnings.

---

## Notes

- **DO NOT migrate 146 existing `context.go()` calls.** `StatefulShellRoute.indexedStack` automatically resolves each call to the correct branch. Only the 16 calls inside the old dashboard grid are removed (they were the card onTaps, which no longer exist).
- **DO NOT add breadcrumbs, unified top bar, or mobile responsiveness.** Out of scope per spec.
- **DO NOT touch per-screen `Scaffold` or `AppBar` widgets.** They stay as-is.
