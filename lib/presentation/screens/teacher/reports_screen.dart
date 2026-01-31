import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/extensions/context_extensions.dart';
import '../../providers/teacher_provider.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Quick Stats Summary
          _QuickStatsCard(ref: ref),

          const SizedBox(height: 24),

          // Report Types
          Text(
            'Available Reports',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          _ReportTypeCard(
            title: 'Class Overview',
            description: 'View performance summary for each class',
            icon: Icons.groups,
            color: Colors.blue,
            onTap: () => context.push('/teacher/reports/class-overview'),
          ),

          _ReportTypeCard(
            title: 'Reading Progress',
            description: 'Track book completion across all students',
            icon: Icons.menu_book,
            color: Colors.green,
            onTap: () => context.push('/teacher/reports/reading-progress'),
          ),

          _ReportTypeCard(
            title: 'Assignment Performance',
            description: 'Analyze assignment completion rates',
            icon: Icons.assignment_turned_in,
            color: Colors.orange,
            onTap: () => context.push('/teacher/reports/assignments'),
          ),

          _ReportTypeCard(
            title: 'Student Leaderboard',
            description: 'Top performers by XP and achievements',
            icon: Icons.leaderboard,
            color: Colors.purple,
            onTap: () => context.push('/teacher/reports/leaderboard'),
          ),
        ],
      ),
    );
  }
}

class _QuickStatsCard extends StatelessWidget {
  const _QuickStatsCard({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(teacherStatsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: context.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Quick Stats',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            statsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Error loading stats'),
              data: (stats) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                    value: '${stats.totalStudents}',
                    label: 'Students',
                    icon: Icons.people,
                    color: Colors.blue,
                  ),
                  _StatItem(
                    value: '${stats.totalClasses}',
                    label: 'Classes',
                    icon: Icons.class_,
                    color: Colors.green,
                  ),
                  _StatItem(
                    value: '${stats.activeAssignments}',
                    label: 'Active Tasks',
                    icon: Icons.assignment,
                    color: Colors.orange,
                  ),
                  _StatItem(
                    value: '${stats.avgProgress.toStringAsFixed(0)}%',
                    label: 'Avg Progress',
                    icon: Icons.trending_up,
                    color: Colors.purple,
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

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

class _ReportTypeCard extends StatelessWidget {
  const _ReportTypeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: context.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
