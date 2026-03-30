import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    final userAsync = ref.watch(currentAdminUserProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);
    final stats = statsAsync.valueOrNull ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kontrol Paneli'),
        actions: [
          userAsync.when(
            data: (user) => PopupMenuButton<String>(
              offset: const Offset(0, 40),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF4F46E5),
                      child: Text(
                        (user?.email?.substring(0, 1) ?? 'A').toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      user?.email ?? 'Yönetici',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
              onSelected: (value) async {
                if (value == 'logout') {
                  await ref.read(supabaseClientProvider).auth.signOut();
                  if (context.mounted) context.go('/login');
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 20),
                      SizedBox(width: 8),
                      Text('Çıkış Yap'),
                    ],
                  ),
                ),
              ],
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
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
              'Okuma platformunuz için kitap, bölüm ve içerik yönetimi.',
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
                          : constraints.maxWidth > 500
                              ? 3
                              : 2;
                  return GridView.count(
                crossAxisCount: columns,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _DashboardCard(
                    icon: Icons.menu_book,
                    title: 'Kitaplar',
                    description: 'Kitap ve bölüm yönetimi',
                    color: const Color(0xFF4F46E5),
                    stat: stats['books'],
                    onTap: () => context.go('/books'),
                  ),
                  _DashboardCard(
                    icon: Icons.school,
                    title: 'Okullar & Sınıflar',
                    description: 'Okul ve sınıf yönetimi',
                    color: const Color(0xFFE11D48),
                    stat: stats['schools'],
                    onTap: () => context.go('/schools'),
                  ),
                  _DashboardCard(
                    icon: Icons.class_,
                    title: 'Sınıflar',
                    description: 'Sınıf ve öğrenci listesi yönetimi',
                    color: const Color(0xFFDB2777),
                    stat: stats['classes'],
                    onTap: () => context.go('/classes'),
                  ),
                  _DashboardCard(
                    icon: Icons.people,
                    title: 'Kullanıcılar',
                    description: 'Öğrenci ve öğretmen yönetimi',
                    color: const Color(0xFF7C3AED),
                    stat: stats['users'],
                    onTap: () => context.go('/users'),
                  ),
                  _DashboardCard(
                    icon: Icons.emoji_events,
                    title: 'Koleksiyon',
                    description: 'Rozetler ve mitoloji kartları',
                    color: const Color(0xFFF59E0B),
                    stat: stats['badges'],
                    onTap: () => context.go('/collectibles'),
                  ),
                  _DashboardCard(
                    icon: Icons.abc,
                    title: 'Kelime Havuzu',
                    description: 'Kelimeler ve kelime listeleri',
                    color: const Color(0xFF059669),
                    stat: stats['words'],
                    statSuffix: stats['wordlists'] != null
                        ? ' · ${stats['wordlists']} liste'
                        : null,
                    onTap: () => context.go('/vocabulary'),
                  ),
                  _DashboardCard(
                    icon: Icons.grid_view_rounded,
                    title: 'Üniteler',
                    description: 'Kelime üniteleri ve tile tema atamaları',
                    color: const Color(0xFF7C3AED),
                    onTap: () => context.go('/units'),
                  ),
                  _DashboardCard(
                    icon: Icons.route,
                    title: 'Öğrenme Yolları',
                    description: 'Şablonlar ve okul/sınıf atamaları',
                    color: const Color(0xFFEA580C),
                    stat: stats['templates'],
                    statSuffix: stats['assignments'] != null
                        ? ' · ${stats['assignments']} atama'
                        : null,
                    onTap: () => context.go('/learning-paths'),
                  ),
                  _DashboardCard(
                    icon: Icons.timeline,
                    title: 'Son Etkinlikler',
                    description: 'Son eklenen içerikler ve kullanıcı aktivitesi',
                    color: const Color(0xFF0891B2),
                    onTap: () => context.go('/recent-activity'),
                  ),
                  _DashboardCard(
                    icon: Icons.bolt,
                    title: 'Daily Quests',
                    description: 'Quest goals, rewards, and completion stats',
                    color: const Color(0xFFF97316),
                    stat: stats['quests'],
                    onTap: () => context.go('/quests'),
                  ),
                  _DashboardCard(
                    icon: Icons.notifications_active,
                    title: 'Notifications',
                    description: 'Notification types and preview',
                    color: const Color(0xFF6366F1),
                    onTap: () => context.go('/notifications'),
                  ),
                  _DashboardCard(
                    icon: Icons.face,
                    title: 'Avatar Yönetimi',
                    description: 'Hayvanlar, kategoriler ve aksesuarlar',
                    color: const Color(0xFF8B5CF6),
                    onTap: () => context.go('/avatars'),
                  ),
                  _DashboardCard(
                    icon: Icons.map,
                    title: 'Tile Temaları',
                    description: 'Harita tile görünümleri ve node pozisyonları',
                    color: const Color(0xFF2E7D32),
                    onTap: () => context.go('/tiles'),
                  ),
                  _DashboardCard(
                    icon: Icons.settings,
                    title: 'Ayarlar',
                    description: 'XP, oyun ve uygulama ayarları',
                    color: const Color(0xFF6B7280),
                    onTap: () => context.go('/settings'),
                  ),
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
// DASHBOARD CARD
// ============================================

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
    this.stat,
    this.statSuffix,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;
  final int? stat;
  final String? statSuffix;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const Spacer(),
                  if (stat != null)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$stat${statSuffix ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
