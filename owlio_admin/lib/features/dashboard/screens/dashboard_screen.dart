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
