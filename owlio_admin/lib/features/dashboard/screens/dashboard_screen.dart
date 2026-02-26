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
        title: const Text('Dashboard'),
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
                      user?.email ?? 'Admin',
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
                      Text('Sign Out'),
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
              'Welcome to Owlio Admin',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage books, chapters, and content for your reading platform.',
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
                    title: 'Books',
                    description: 'Manage books and chapters',
                    color: const Color(0xFF4F46E5),
                    onTap: () => context.go('/books'),
                  ),
                  _DashboardCard(
                    icon: Icons.school,
                    title: 'Schools',
                    description: 'Manage schools',
                    color: const Color(0xFFE11D48),
                    onTap: () => context.go('/schools'),
                  ),
                  _DashboardCard(
                    icon: Icons.people,
                    title: 'Users',
                    description: 'Manage students & teachers',
                    color: const Color(0xFF7C3AED),
                    onTap: () => context.go('/users'),
                  ),
                  _DashboardCard(
                    icon: Icons.class_,
                    title: 'Classes',
                    description: 'Manage classes',
                    color: const Color(0xFF0891B2),
                    onTap: () => context.go('/classes'),
                  ),
                  _DashboardCard(
                    icon: Icons.emoji_events,
                    title: 'Badges',
                    description: 'Manage achievements',
                    color: const Color(0xFFF59E0B),
                    onTap: () => context.go('/badges'),
                  ),
                  _DashboardCard(
                    icon: Icons.abc,
                    title: 'Vocabulary',
                    description: 'Manage word dictionary',
                    color: const Color(0xFF059669),
                    onTap: () => context.go('/vocabulary'),
                  ),
                  _DashboardCard(
                    icon: Icons.list_alt,
                    title: 'Word Lists',
                    description: 'Manage word collections',
                    color: const Color(0xFF0D9488),
                    onTap: () => context.go('/wordlists'),
                  ),
                  _DashboardCard(
                    icon: Icons.layers,
                    title: 'Units',
                    description: 'Manage vocabulary units',
                    color: const Color(0xFF2563EB),
                    onTap: () => context.go('/units'),
                  ),
                  _DashboardCard(
                    icon: Icons.assignment_outlined,
                    title: 'Unit Assignments',
                    description: 'Assign word list units to schools & classes',
                    color: const Color(0xFFEA580C),
                    onTap: () => context.go('/curriculum'),
                  ),
                  _DashboardCard(
                    icon: Icons.auto_stories,
                    title: 'Unit Books',
                    description: 'Assign books to units per school',
                    color: const Color(0xFF1565C0),
                    onTap: () => context.go('/unit-books'),
                  ),
                  _DashboardCard(
                    icon: Icons.assignment,
                    title: 'Assignments',
                    description: 'View teacher assignments',
                    color: const Color(0xFFDB2777),
                    onTap: () => context.go('/assignments'),
                  ),
                  _DashboardCard(
                    icon: Icons.style,
                    title: 'Myth Cards',
                    description: 'Manage mythology cards',
                    color: const Color(0xFFD97706),
                    onTap: () => context.go('/cards'),
                  ),
                  _DashboardCard(
                    icon: Icons.settings,
                    title: 'Settings',
                    description: 'App configuration',
                    color: const Color(0xFF6B7280),
                    onTap: () => context.go('/settings'),
                  ),
                  _DashboardCard(
                    icon: Icons.grid_view,
                    title: 'Gallery',
                    description: 'View all screens',
                    color: const Color(0xFF8B5CF6),
                    onTap: () => context.go('/gallery'),
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
