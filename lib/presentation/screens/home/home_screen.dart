import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/utils/extensions/context_extensions.dart';
import '../../providers/auth_provider.dart';
import '../../providers/book_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateChangesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ReadEng'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.go(AppRoutes.profile),
          ),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome header
                Text(
                  'Welcome back, ${user.firstName}!',
                  style: context.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Keep up your reading streak!',
                  style: context.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),

                // Stats row
                Row(
                  children: [
                    _StatCard(
                      icon: Icons.star,
                      label: 'XP',
                      value: user.xp.toString(),
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      icon: Icons.local_fire_department,
                      label: 'Streak',
                      value: '${user.currentStreak} days',
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      icon: Icons.trending_up,
                      label: 'Level',
                      value: user.level.toString(),
                      color: Colors.purple,
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Continue Reading
                _ContinueReadingSection(),
                const SizedBox(height: 32),

                // Quick actions
                Text(
                  'Quick Actions',
                  style: context.textTheme.titleLarge,
                ),
                const SizedBox(height: 16),

                _QuickActionCard(
                  icon: Icons.library_books,
                  title: 'Browse Library',
                  subtitle: 'Discover new books',
                  onTap: () => context.go(AppRoutes.library),
                ),
                const SizedBox(height: 12),

                _QuickActionCard(
                  icon: Icons.abc,
                  title: 'Vocabulary Practice',
                  subtitle: 'Review your words',
                  onTap: () => context.go(AppRoutes.vocabulary),
                ),
                const SizedBox(height: 12),

                // Teacher-only action
                if (user.role.canManageStudents)
                  _QuickActionCard(
                    icon: Icons.dashboard,
                    title: 'Teacher Dashboard',
                    subtitle: 'Manage your classes',
                    onTap: () => context.go(AppRoutes.teacherDashboard),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ContinueReadingSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final continueReadingAsync = ref.watch(continueReadingProvider);

    return continueReadingAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (books) {
        if (books.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Continue Reading',
              style: context.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: books.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final book = books[index];
                  return GestureDetector(
                    onTap: () => context.go('/book/${book.id}'),
                    child: SizedBox(
                      width: 130,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: context.colorScheme.surfaceContainerHighest,
                                image: book.coverUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(book.coverUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: book.coverUrl == null
                                  ? Center(
                                      child: Icon(
                                        Icons.book,
                                        size: 40,
                                        color: context.colorScheme.onSurfaceVariant,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            book.title,
                            style: context.textTheme.bodyMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                value,
                style: context.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: context.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: context.colorScheme.primaryContainer,
          child: Icon(icon, color: context.colorScheme.onPrimaryContainer),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
