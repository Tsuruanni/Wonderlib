import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/utils/extensions/context_extensions.dart';
import '../../providers/auth_provider.dart';
import '../../providers/teacher_provider.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/common/animated_game_button.dart';
import '../../widgets/common/asset_icon.dart';
import '../../widgets/common/responsive_layout.dart';

class TeacherDashboardScreen extends ConsumerWidget {
  const TeacherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);
    final user = authState.valueOrNull;

    final isWide = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: false,
        actions: [
          if (!isWide)
            IconButton(
              icon: const Icon(Icons.person_outline),
              tooltip: 'Profile',
              onPressed: () => context.push(AppRoutes.profile),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(teacherStatsProvider);
          ref.invalidate(recentSchoolActivityProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isWide)
                // Wide: 2-column layout
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left column: Welcome + Quick Actions + Stats
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome Back!',
                            style: context.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _WelcomeHeader(userName: user?.firstName ?? 'Teacher'),
                          const SizedBox(height: 24),
                          Text(
                            'Quick Actions',
                            style: context.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const _QuickActionsRow(),
                          const SizedBox(height: 24),
                          Text(
                            'Overview',
                            style: context.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const _StatsGrid(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Right column: Recent Student Activities
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recent Student Activities',
                            style: context.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const _RecentActivityList(),
                        ],
                      ),
                    ),
                  ],
                )
              else
                // Narrow: single column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WelcomeHeader(userName: user?.firstName ?? 'Teacher'),
                    const SizedBox(height: 24),
                    Text(
                      'Quick Actions',
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _QuickActionsRow(),
                    const SizedBox(height: 24),
                    Text(
                      'Overview',
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _StatsGrid(),
                    const SizedBox(height: 24),
                    Text(
                      'Recent Student Activities',
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _RecentActivityList(),
                  ],
                ),
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
    final greeting = GreetingHelper.getGreeting();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryDark, width: 2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.primaryDark,
            offset: Offset(0, 4),
          ),
        ],
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

    return statsAsync.when(
      loading: () => const ResponsiveGrid(
        minItemWidth: 160,
        maxColumns: 4,
        childAspectRatio: 1.2,
        children: [
          _StatCard(icon: Icons.groups, label: 'Total Students', value: '...', color: Colors.blue),
          _StatCard(icon: Icons.class_, label: 'Manage Classes', value: '...', color: Colors.green),
          _StatCard(icon: Icons.assignment, label: 'Active Assignments', value: '...', color: Colors.orange),
          _StatCard(icon: Icons.trending_up, label: 'Avg Progress', value: '...', color: Colors.purple),
        ],
      ),
      error: (_, __) => const Center(child: Text('Error loading stats')),
      data: (stats) => ResponsiveGrid(
        minItemWidth: 160,
        maxColumns: 4,
        childAspectRatio: 1.2,
        children: [
          _StatCard(
            icon: Icons.groups,
            label: 'Total Students',
            value: '${stats.totalStudents}',
            color: Colors.blue,
          ),
          _StatCard(
            icon: Icons.class_,
            label: 'Manage Classes',
            value: '${stats.totalClasses}',
            color: Colors.green,
          ),
          _StatCard(
            assetPath: AppIcons.clipboard,
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
    this.icon,
    this.assetPath,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData? icon;
  final String? assetPath;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral, width: 2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.neutral,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: assetPath != null
                ? AssetIcon(assetPath!, size: 24)
                : Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              Text(
                label,
                style: context.textTheme.bodySmall?.copyWith(
                  color: AppColors.neutralText,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
    return ResponsiveWrap(
      minItemWidth: 120,
      children: [
        AnimatedGameButton(
          label: 'New Assignment',
          icon: const Icon(Icons.add_circle_outline),
          variant: GameButtonVariant.primary,
          fullWidth: true,
          onPressed: () => context.push(AppRoutes.teacherCreateAssignment),
        ),
        AnimatedGameButton(
          label: 'Reports',
          icon: const Icon(Icons.bar_chart),
          variant: GameButtonVariant.secondary,
          fullWidth: true,
          onPressed: () => context.go(AppRoutes.teacherReports),
        ),
        AnimatedGameButton(
          label: 'Manage Classes',
          icon: const Icon(Icons.groups),
          variant: GameButtonVariant.neutral,
          fullWidth: true,
          onPressed: () => context.go(AppRoutes.teacherClasses),
        ),
        AnimatedGameButton(
          label: 'Leaderboard',
          icon: const AssetIcon(AppIcons.trophy, size: 20),
          variant: GameButtonVariant.wasp,
          fullWidth: true,
          onPressed: () => context.push(AppRoutes.teacherReportLeaderboard),
        ),
      ],
    );
  }
}

class _RecentActivityList extends ConsumerWidget {
  const _RecentActivityList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(recentSchoolActivityProvider);

    return activitiesAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (_, __) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: Text('Error loading activity')),
      ),
      data: (activities) {
        if (activities.isEmpty) {
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
                  color: context.colorScheme.outline.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 8),
                Text(
                  'No recent activity',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.outline,
                  ),
                ),
                Text(
                  'Student progress will appear here',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.outline.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          );
        }

        // Filter out noisy XP entries, then take 10
        final filtered = activities
            .where((a) =>
                a.activityType != 'activity' &&
                a.activityType != 'manual' &&
                !a.description.toLowerCase().contains('xp awarded'),)
            .take(10)
            .toList();

        if (filtered.isEmpty) {
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
                  color: context.colorScheme.outline.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 8),
                Text(
                  'No recent activity',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.outline,
                  ),
                ),
              ],
            ),
          );
        }

        return DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.neutral, width: 2),
            boxShadow: const [
              BoxShadow(
                color: AppColors.neutral,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
          children: filtered.map((activity) {
            return InkWell(
              onTap: () => context.push(
                AppRoutes.teacherStudentProfilePath(activity.studentId),
              ),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.neutral, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    // Student avatar
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: context.colorScheme.primaryContainer,
                      child: Text(
                        activity.studentFirstName.isNotEmpty
                            ? activity.studentFirstName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: context.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Activity info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity.studentFullName,
                            style: context.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            activity.description,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.colorScheme.outline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // XP and time
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AssetIcon(AppIcons.xp, size: 14),
                            const SizedBox(width: 2),
                            Text(
                              '+${activity.xpAmount}',
                              style: context.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade700,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          TimeFormatter.formatTimeAgo(activity.createdAt),
                          style: context.textTheme.labelSmall?.copyWith(
                            color: context.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
            ),
          ),
        );
      },
    );
  }

}
