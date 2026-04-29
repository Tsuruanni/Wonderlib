import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
// RECENT ITEMS PROVIDER
// ============================================

class RecentItem {
  const RecentItem({
    required this.id,
    required this.label,
    required this.route,
    required this.updatedAt,
  });

  final String id;
  final String label;
  final String route;
  final DateTime updatedAt;
}

class DashboardRecent {
  const DashboardRecent({
    required this.books,
    required this.words,
    required this.wordlists,
  });

  final List<RecentItem> books;
  final List<RecentItem> words;
  final List<RecentItem> wordlists;
}

// ============================================
// AT RISK PROVIDER
// ============================================

class AtRiskItem {
  const AtRiskItem({
    required this.title,
    required this.reason,
    required this.route,
    required this.icon,
  });

  final String title;
  final String reason;
  final String route;
  final IconData icon;
}

/// Surfaces entities that are missing required children (empty templates, books
/// with no chapters, etc.) so the operator notices them before students do.
final dashboardAtRiskProvider =
    FutureProvider<List<AtRiskItem>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);

  int countOf(dynamic embedded) {
    if (embedded is List && embedded.isNotEmpty) {
      final first = embedded.first;
      if (first is Map && first['count'] is int) return first['count'] as int;
    }
    return 0;
  }

  final results = await Future.wait([
    supabase
        .from(DbTables.books)
        .select('id, title, chapters(count)')
        .limit(50),
    supabase
        .from(DbTables.learningPathTemplates)
        .select('id, name, learning_path_template_units(count)')
        .limit(50),
    supabase
        .from(DbTables.wordLists)
        .select('id, name, word_list_items(count)')
        .eq('is_system', true)
        .limit(50),
  ]);

  final issues = <AtRiskItem>[];

  for (final book in results[0]) {
    if (countOf(book['chapters']) == 0) {
      issues.add(AtRiskItem(
        title: (book['title'] as String?)?.trim().isNotEmpty == true
            ? book['title'] as String
            : '(isimsiz kitap)',
        reason: 'Bölüm yok',
        route: '/books/${book['id']}',
        icon: Icons.menu_book,
      ));
    }
  }

  for (final t in results[1]) {
    if (countOf(t['learning_path_template_units']) == 0) {
      issues.add(AtRiskItem(
        title: (t['name'] as String?)?.trim().isNotEmpty == true
            ? t['name'] as String
            : '(isimsiz şablon)',
        reason: 'Ünite yok',
        route: '/templates/${t['id']}',
        icon: Icons.route,
      ));
    }
  }

  for (final wl in results[2]) {
    if (countOf(wl['word_list_items']) == 0) {
      issues.add(AtRiskItem(
        title: (wl['name'] as String?)?.trim().isNotEmpty == true
            ? wl['name'] as String
            : '(isimsiz liste)',
        reason: 'Kelime yok',
        route: '/wordlists/${wl['id']}',
        icon: Icons.format_list_bulleted,
      ));
    }
  }

  return issues;
});

final dashboardRecentProvider =
    FutureProvider<DashboardRecent>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);

  // vocabulary_words has no updated_at column — fall back to created_at.
  final results = await Future.wait([
    supabase
        .from(DbTables.books)
        .select('id, title, updated_at')
        .order('updated_at', ascending: false)
        .limit(5),
    supabase
        .from(DbTables.vocabularyWords)
        .select('id, word, created_at')
        .order('created_at', ascending: false)
        .limit(5),
    supabase
        .from(DbTables.wordLists)
        .select('id, name, updated_at')
        .order('updated_at', ascending: false)
        .limit(5),
  ]);

  List<RecentItem> map(
    List<dynamic> rows, {
    required String labelKey,
    required String dateKey,
    required String routePrefix,
  }) {
    return rows
        .map((r) => r as Map<String, dynamic>)
        .map(
          (r) => RecentItem(
            id: r['id'] as String,
            label: (r[labelKey] as String?)?.trim().isNotEmpty == true
                ? r[labelKey] as String
                : '(isimsiz)',
            route: '$routePrefix/${r['id']}',
            updatedAt: DateTime.parse(r[dateKey] as String),
          ),
        )
        .toList();
  }

  return DashboardRecent(
    books: map(
      results[0],
      labelKey: 'title',
      dateKey: 'updated_at',
      routePrefix: '/books',
    ),
    words: map(
      results[1],
      labelKey: 'word',
      dateKey: 'created_at',
      routePrefix: '/vocabulary',
    ),
    wordlists: map(
      results[2],
      labelKey: 'name',
      dateKey: 'updated_at',
      routePrefix: '/wordlists',
    ),
  );
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
    final recentAsync = ref.watch(dashboardRecentProvider);
    final atRiskAsync = ref.watch(dashboardAtRiskProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Genel Bakış')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(dashboardRecentProvider);
          ref.invalidate(dashboardAtRiskProvider);
          await Future.wait([
            ref.read(dashboardStatsProvider.future),
            ref.read(dashboardRecentProvider.future),
            ref.read(dashboardAtRiskProvider.future),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
              const SizedBox(height: 24),
              const _QuickActionsBar(),
              const SizedBox(height: 32),
              _StatsGrid(stats: stats),
              const SizedBox(height: 32),
              _AtRiskSection(asyncAtRisk: atRiskAsync),
              const SizedBox(height: 32),
              _RecentSection(asyncRecent: recentAsync),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// QUICK ACTIONS
// ============================================

class _QuickActionsBar extends StatelessWidget {
  const _QuickActionsBar();

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickAction>[
      _QuickAction(
        label: 'Yeni Kitap',
        icon: Icons.menu_book,
        route: '/books/new',
        color: const Color(0xFF4F46E5),
      ),
      _QuickAction(
        label: 'Yeni Kelime',
        icon: Icons.abc,
        route: '/vocabulary/new',
        color: const Color(0xFF059669),
      ),
      _QuickAction(
        label: 'Yeni Kelime Listesi',
        icon: Icons.format_list_bulleted,
        route: '/wordlists/new',
        color: const Color(0xFF10B981),
      ),
      _QuickAction(
        label: 'Yeni Şablon',
        icon: Icons.route,
        route: '/templates/new',
        color: const Color(0xFFEA580C),
      ),
      _QuickAction(
        label: 'Yeni Atama',
        icon: Icons.assignment_add,
        route: '/learning-path-assignments/new',
        color: const Color(0xFF0891B2),
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final a in actions)
          _QuickActionButton(action: a),
      ],
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.route,
    required this.color,
  });

  final String label;
  final IconData icon;
  final String route;
  final Color color;
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => context.go(action.route),
      icon: Icon(action.icon, size: 18),
      label: Text(action.label),
      style: ElevatedButton.styleFrom(
        backgroundColor: action.color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

// ============================================
// STATS GRID
// ============================================

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final Map<String, int> stats;

  @override
  Widget build(BuildContext context) {
    final tiles = <_StatTileData>[
      _StatTileData(label: 'Kitap', valueKey: 'books', route: '/books', color: const Color(0xFF4F46E5)),
      _StatTileData(label: 'Okul', valueKey: 'schools', route: '/schools', color: const Color(0xFFE11D48)),
      _StatTileData(label: 'Sınıf', valueKey: 'classes', route: '/classes', color: const Color(0xFFDB2777)),
      _StatTileData(label: 'Kullanıcı', valueKey: 'users', route: '/users', color: const Color(0xFF7C3AED)),
      _StatTileData(label: 'Rozet', valueKey: 'badges', route: '/badges', color: const Color(0xFFF59E0B)),
      _StatTileData(label: 'Kelime', valueKey: 'words', route: '/vocabulary', color: const Color(0xFF059669)),
      _StatTileData(label: 'Kelime Listesi', valueKey: 'wordlists', route: '/wordlists', color: const Color(0xFF10B981)),
      _StatTileData(label: 'Yol Şablonu', valueKey: 'templates', route: '/templates', color: const Color(0xFFEA580C)),
      _StatTileData(label: 'Atama', valueKey: 'assignments', route: '/assignments', color: const Color(0xFF0891B2)),
      _StatTileData(label: 'Aktif Quest', valueKey: 'quests', route: '/quests', color: const Color(0xFFF97316)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 1200
            ? 5
            : constraints.maxWidth > 800
                ? 4
                : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.8,
          children: [
            for (final t in tiles)
              _StatTile(
                label: t.label,
                value: stats[t.valueKey],
                color: t.color,
                route: t.route,
              ),
          ],
        );
      },
    );
  }
}

class _StatTileData {
  const _StatTileData({
    required this.label,
    required this.valueKey,
    required this.route,
    required this.color,
  });

  final String label;
  final String valueKey;
  final String route;
  final Color color;
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.route,
  });

  final String label;
  final int? value;
  final Color color;
  final String route;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: Colors.grey.shade400,
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
      ),
    );
  }
}

// ============================================
// RECENT SECTION
// ============================================

class _RecentSection extends StatelessWidget {
  const _RecentSection({required this.asyncRecent});

  final AsyncValue<DashboardRecent> asyncRecent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Son Düzenlenenler',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        asyncRecent.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Son etkinlikler yüklenemedi: $e',
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
          data: (recent) => LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              final columns = <Widget>[
                Expanded(
                  child: _RecentColumn(
                    title: 'Kitaplar',
                    icon: Icons.menu_book,
                    items: recent.books,
                    emptyText: 'Henüz kitap düzenlenmedi.',
                  ),
                ),
                Expanded(
                  child: _RecentColumn(
                    title: 'Kelimeler',
                    icon: Icons.abc,
                    items: recent.words,
                    emptyText: 'Henüz kelime düzenlenmedi.',
                  ),
                ),
                Expanded(
                  child: _RecentColumn(
                    title: 'Kelime Listeleri',
                    icon: Icons.format_list_bulleted,
                    items: recent.wordlists,
                    emptyText: 'Henüz kelime listesi düzenlenmedi.',
                  ),
                ),
              ];

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < columns.length; i++) ...[
                      columns[i],
                      if (i < columns.length - 1) const SizedBox(width: 16),
                    ],
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < columns.length; i++) ...[
                    // Wrap each Expanded in a Container that shrinks for narrow layout
                    SizedBox(
                      width: double.infinity,
                      child: (columns[i] as Expanded).child,
                    ),
                    if (i < columns.length - 1) const SizedBox(height: 16),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecentColumn extends StatelessWidget {
  const _RecentColumn({
    required this.title,
    required this.icon,
    required this.items,
    required this.emptyText,
  });

  final String title;
  final IconData icon;
  final List<RecentItem> items;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                emptyText,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                ),
              ),
            )
          else
            for (final item in items) _RecentRow(item: item),
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.item});

  final RecentItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go(item.route),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatRelative(item.updatedAt),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatRelative(DateTime utc) {
    final diff = DateTime.now().toUtc().difference(utc);
    if (diff.inMinutes < 1) return 'şimdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk';
    if (diff.inHours < 24) return '${diff.inHours} sa';
    if (diff.inDays < 7) return '${diff.inDays} gün';
    return '${utc.day}.${utc.month}.${utc.year}';
  }
}

// ============================================
// AT RISK SECTION
// ============================================

class _AtRiskSection extends StatelessWidget {
  const _AtRiskSection({required this.asyncAtRisk});

  final AsyncValue<List<AtRiskItem>> asyncAtRisk;

  @override
  Widget build(BuildContext context) {
    return asyncAtRisk.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber,
                      color: Colors.orange.shade700, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Dikkat Gereken (${items.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Eksik içerik nedeniyle öğrencilere düzgün görünmeyecek kayıtlar',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade800,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in items)
                    InkWell(
                      onTap: () => context.go(item.route),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(item.icon,
                                size: 14, color: Colors.orange.shade700),
                            const SizedBox(width: 6),
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.reason,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
