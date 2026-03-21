import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase_client.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentAdminUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kontrol Paneli'),
        actions: [
          // User menu
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
                  if (context.mounted) {
                    context.go('/login');
                  }
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
            // Welcome section
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

            // Quick actions grid
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.5,
                children: [
                  _DashboardCard(
                    icon: Icons.menu_book,
                    title: 'Kitaplar',
                    description: 'Kitap ve bölüm yönetimi',
                    color: const Color(0xFF4F46E5),
                    onTap: () => context.go('/books'),
                  ),
                  _DashboardCard(
                    icon: Icons.school,
                    title: 'Okullar & Sınıflar',
                    description: 'Okul ve sınıf yönetimi',
                    color: const Color(0xFFE11D48),
                    onTap: () => context.go('/schools'),
                  ),
                  _DashboardCard(
                    icon: Icons.people,
                    title: 'Kullanıcılar',
                    description: 'Öğrenci ve öğretmen yönetimi',
                    color: const Color(0xFF7C3AED),
                    onTap: () => context.go('/users'),
                  ),
                  _DashboardCard(
                    icon: Icons.emoji_events,
                    title: 'Rozetler',
                    description: 'Başarı rozeti yönetimi',
                    color: const Color(0xFFF59E0B),
                    onTap: () => context.go('/badges'),
                  ),
                  _DashboardCard(
                    icon: Icons.abc,
                    title: 'Kelime Havuzu',
                    description: 'Kelimeler ve kelime listeleri',
                    color: const Color(0xFF059669),
                    onTap: () => context.go('/vocabulary'),
                  ),
                  _DashboardCard(
                    icon: Icons.route,
                    title: 'Öğrenme Yolu Şablonları',
                    description: 'Tekrar kullanılabilir öğrenme yolları oluştur',
                    color: const Color(0xFFEA580C),
                    onTap: () => context.go('/templates'),
                  ),
                  _DashboardCard(
                    icon: Icons.school,
                    title: 'Öğrenme Yolu Ataması',
                    description: 'Şablonları okul ve sınıflara ata',
                    color: const Color(0xFF1565C0),
                    onTap: () => context.go('/learning-path-assignments'),
                  ),
                  _DashboardCard(
                    icon: Icons.assignment,
                    title: 'Ödevler',
                    description: 'Öğretmen ödevlerini görüntüle',
                    color: const Color(0xFFDB2777),
                    onTap: () => context.go('/assignments'),
                  ),
                  _DashboardCard(
                    icon: Icons.style,
                    title: 'Mitoloji Kartları',
                    description: 'Mitoloji kartı yönetimi',
                    color: const Color(0xFFD97706),
                    onTap: () => context.go('/cards'),
                  ),
                  _DashboardCard(
                    icon: Icons.settings,
                    title: 'Ayarlar',
                    description: 'XP, oyun ve uygulama ayarları',
                    color: const Color(0xFF6B7280),
                    onTap: () => context.go('/settings'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

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
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
