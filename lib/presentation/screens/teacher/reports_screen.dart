import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/utils/extensions/context_extensions.dart';
import '../../providers/teacher_provider.dart';
import '../../widgets/common/asset_icon.dart';
import '../../widgets/common/playful_card.dart';
import '../../widgets/common/responsive_layout.dart';
import '../../widgets/common/stat_item.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Quick Stats Summary
          const ResponsiveConstraint(
            maxWidth: 900,
            child: _QuickStatsCard(),
          ),

          const SizedBox(height: 24),

          // Report Types
          Text(
            'Available Reports',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          ResponsiveWrap(
            minItemWidth: 300,
            children: [
              _ReportTypeCard(
                title: 'Class Overview',
                description: 'View performance summary for each class',
                assetPath: AppIcons.library,
                color: Colors.blue,
                onTap: () => context.push(AppRoutes.teacherReportClassOverview),
              ),
              _ReportTypeCard(
                title: 'Reading Progress',
                description: 'Track book completion across all students',
                assetPath: AppIcons.book,
                color: Colors.green,
                onTap: () => context.push(AppRoutes.teacherReportReadingProgress),
              ),
              _ReportTypeCard(
                title: 'Assignment Performance',
                description: 'Analyze assignment completion rates',
                assetPath: AppIcons.clipboard,
                color: Colors.orange,
                onTap: () => context.push(AppRoutes.teacherReportAssignments),
              ),
              _ReportTypeCard(
                title: 'My School',
                description: 'School-wide stats compared to the platform',
                assetPath: AppIcons.xp,
                color: Colors.teal,
                onTap: () => context.push(AppRoutes.teacherReportMySchool),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickStatsCard extends ConsumerWidget {
  const _QuickStatsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(teacherStatsProvider);

    return PlayfulCard(
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
                StatItem(
                  value: '${stats.totalStudents}',
                  label: 'Students',
                  icon: Icons.people,
                  color: Colors.blue,
                ),
                StatItem(
                  value: '${stats.totalClasses}',
                  label: 'Classes',
                  icon: Icons.class_,
                  color: Colors.green,
                ),
                StatItem(
                  value: '${stats.activeAssignments}',
                  label: 'Active Tasks',
                  assetPath: AppIcons.clipboard,
                ),
                StatItem(
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
    );
  }
}

class _ReportTypeCard extends StatelessWidget {
  const _ReportTypeCard({
    required this.title,
    required this.description,
    required this.assetPath,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String description;
  final String assetPath;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PlayfulCard(
      margin: const EdgeInsets.only(bottom: 8),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: AssetIcon(assetPath, size: 32),
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
    );
  }
}
