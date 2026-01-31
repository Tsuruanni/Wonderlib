import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter/foundation.dart';

import '../../../app/router.dart';
import '../../../core/utils/extensions/context_extensions.dart';
import '../../providers/auth_provider.dart';
import '../../providers/teacher_provider.dart';

class TeacherDashboardScreen extends ConsumerWidget {
  const TeacherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);
    final user = authState.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push(AppRoutes.profile),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(teacherStatsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome header
              _WelcomeHeader(userName: user?.firstName ?? 'Teacher'),
              const SizedBox(height: 24),

              // Stats cards
              const _StatsGrid(),
              const SizedBox(height: 24),

              // Quick actions
              Text(
                'Quick Actions',
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const _QuickActionsRow(),
              const SizedBox(height: 24),

              // Recent activity
              Text(
                'Recent Activity',
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const _RecentActivityList(),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.colorScheme.primary,
            context.colorScheme.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting,',
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userName,
                  style: context.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.school,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends ConsumerWidget {
  const _StatsGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(teacherStatsProvider);
    final userId = ref.watch(currentUserIdProvider);

    // Debug: show user ID if stats are loading/error
    debugPrint('Dashboard stats - userId: $userId, state: ${statsAsync.runtimeType}');

    return statsAsync.when(
      loading: () => GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.4,
        children: const [
          _StatCard(icon: Icons.groups, label: 'Total Students', value: '...', color: Colors.blue),
          _StatCard(icon: Icons.class_, label: 'My Classes', value: '...', color: Colors.green),
          _StatCard(icon: Icons.assignment, label: 'Active Assignments', value: '...', color: Colors.orange),
          _StatCard(icon: Icons.trending_up, label: 'Avg Progress', value: '...', color: Colors.purple),
        ],
      ),
      error: (_, __) => const Center(child: Text('Error loading stats')),
      data: (stats) => GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.4,
        children: [
          _StatCard(
            icon: Icons.groups,
            label: 'Total Students',
            value: '${stats.totalStudents}',
            color: Colors.blue,
          ),
          _StatCard(
            icon: Icons.class_,
            label: 'My Classes',
            value: '${stats.totalClasses}',
            color: Colors.green,
          ),
          _StatCard(
            icon: Icons.assignment,
            label: 'Active Assignments',
            value: '${stats.activeAssignments}',
            color: Colors.orange,
          ),
          _StatCard(
            icon: Icons.trending_up,
            label: 'Avg Progress',
            value: '${stats.avgProgress.toStringAsFixed(0)}%',
            color: Colors.purple,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 28),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: context.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            icon: Icons.add_circle_outline,
            label: 'New Assignment',
            onTap: () => context.push(AppRoutes.teacherCreateAssignment),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.bar_chart,
            label: 'View Reports',
            onTap: () => context.go(AppRoutes.teacherReports),
          ),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: context.textTheme.labelLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentActivityList extends StatelessWidget {
  const _RecentActivityList();

  @override
  Widget build(BuildContext context) {
    // TODO: Replace with actual data
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.history,
            size: 48,
            color: context.colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            'No recent activity',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Student progress will appear here',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
