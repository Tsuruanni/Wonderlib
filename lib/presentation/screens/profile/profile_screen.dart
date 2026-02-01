import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/extensions/context_extensions.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use userControllerProvider for profile data (XP, streak, level)
    final userAsync = ref.watch(userControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // TODO: Navigate to settings
            },
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
              children: [
                // Avatar
                CircleAvatar(
                  radius: 50,
                  backgroundColor: context.colorScheme.primaryContainer,
                  child: Text(
                    user.initials,
                    style: context.textTheme.headlineLarge?.copyWith(
                      color: context.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Name
                Text(
                  user.fullName,
                  style: context.textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),

                // Role badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    user.role.name.toUpperCase(),
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Stats
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _StatRow(
                          label: 'Total XP',
                          value: user.xp.toString(),
                          icon: Icons.star,
                        ),
                        const Divider(),
                        _StatRow(
                          label: 'Level',
                          value: '${user.level} (${user.userLevel.title})',
                          icon: Icons.trending_up,
                        ),
                        const Divider(),
                        _StatRow(
                          label: 'Current Streak',
                          value: '${user.currentStreak} days',
                          icon: Icons.local_fire_department,
                        ),
                        const Divider(),
                        _StatRow(
                          label: 'Longest Streak',
                          value: '${user.longestStreak} days',
                          icon: Icons.emoji_events,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Logout button
                OutlinedButton.icon(
                  onPressed: () async {
                    final confirmed = await context.showConfirmDialog(
                      title: 'Sign Out',
                      message: 'Are you sure you want to sign out?',
                      confirmText: 'Sign Out',
                      isDestructive: true,
                    );

                    if (confirmed ?? false) {
                      await ref.read(authControllerProvider.notifier).signOut();
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatRow extends StatelessWidget {

  const _StatRow({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.colorScheme.outline),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(
            value,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
