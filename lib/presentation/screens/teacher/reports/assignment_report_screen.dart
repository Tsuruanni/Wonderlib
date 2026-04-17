import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router.dart';
import '../../../../core/utils/extensions/context_extensions.dart';
import '../../../../domain/repositories/teacher_repository.dart';
import '../../../providers/teacher_provider.dart';
import '../../../utils/ui_helpers.dart';
import '../../../widgets/common/app_progress_bar.dart';
import '../../../widgets/common/asset_icon.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/playful_card.dart';
import '../../../widgets/common/responsive_layout.dart';
import '../../../widgets/common/stat_item.dart';

class AssignmentReportScreen extends ConsumerWidget {
  const AssignmentReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(teacherAssignmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignment Performance'),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(teacherAssignmentsProvider);
        },
        child: assignmentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ErrorStateWidget(
            message: 'Error loading data',
            onRetry: () => ref.invalidate(teacherAssignmentsProvider),
          ),
          data: (assignments) {
            if (assignments.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const AssetIcon(AppIcons.clipboard, size: 80),
                    const SizedBox(height: 16),
                    Text(
                      'No assignments yet',
                      style: context.textTheme.titleMedium,
                    ),
                  ],
                ),
              );
            }

            // Calculate overall stats
            final totalAssignments = assignments.length;
            final totalStudents = assignments.fold<int>(0, (sum, a) => sum + a.totalStudents);
            final totalCompleted = assignments.fold<int>(0, (sum, a) => sum + a.completedStudents);
            final avgCompletionRate = totalStudents > 0
                ? (totalCompleted / totalStudents) * 100
                : 0.0;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Overall stats
                ResponsiveConstraint(
                  maxWidth: 900,
                  child: PlayfulCard(
                  color: context.colorScheme.primaryContainer,
                  child: Column(
                    children: [
                      Text(
                        'Overall Performance',
                        style: context.textTheme.titleSmall?.copyWith(
                          color: context.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          StatItem(
                            value: '$totalAssignments',
                            label: 'Assignments',
                            valueStyle: context.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: context.colorScheme.onPrimaryContainer,
                            ),
                            labelStyle: context.textTheme.bodySmall?.copyWith(
                              color: context.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                            ),
                          ),
                          StatItem(
                            value: '$totalCompleted/$totalStudents',
                            label: 'Completed',
                            valueStyle: context.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: context.colorScheme.onPrimaryContainer,
                            ),
                            labelStyle: context.textTheme.bodySmall?.copyWith(
                              color: context.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                            ),
                          ),
                          StatItem(
                            value: '${avgCompletionRate.toStringAsFixed(0)}%',
                            label: 'Avg Rate',
                            valueStyle: context.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: context.colorScheme.onPrimaryContainer,
                            ),
                            labelStyle: context.textTheme.bodySmall?.copyWith(
                              color: context.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Assignment Details',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Assignment cards
                ResponsiveWrap(
                  minItemWidth: 240,
                  children: assignments
                      .map(
                        (assignment) => _AssignmentReportCard(
                          assignment: assignment,
                          onTap: () => context.push(
                            AppRoutes.teacherAssignmentDetailPath(assignment.id),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AssignmentReportCard extends StatelessWidget {
  const _AssignmentReportCard({
    required this.assignment,
    required this.onTap,
  });

  final Assignment assignment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d');

    return PlayfulCard(
      margin: const EdgeInsets.only(bottom: 8),
      onTap: onTap,
      child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Type icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AssignmentColors.getTypeColor(assignment.type).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      AssignmentColors.getTypeIcon(assignment.type),
                      color: AssignmentColors.getTypeColor(assignment.type),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assignment.title,
                          style: context.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (assignment.className != null)
                          Text(
                            assignment.className!,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.colorScheme.outline,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Status badge
                  AssignmentStatusBadge(assignment: assignment),
                ],
              ),

              const SizedBox(height: 12),

              // Progress section
              Row(
                children: [
                  // Completion stats
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${assignment.completedStudents}',
                              style: context.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            Text(
                              ' / ${assignment.totalStudents}',
                              style: context.textTheme.titleMedium?.copyWith(
                                color: context.colorScheme.outline,
                              ),
                            ),
                            Text(
                              ' completed',
                              style: context.textTheme.bodySmall?.copyWith(
                                color: context.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        AppProgressBar(
                          progress: assignment.completionRate / 100,
                          fillColor: ScoreColors.getCompletionColor(assignment.completionRate),
                          fillShadow: ScoreColors.getCompletionColor(assignment.completionRate).withValues(alpha: 0.6),
                          backgroundColor: context.colorScheme.surfaceContainerHighest,
                          height: 8,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Completion percentage
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ScoreColors.getCompletionColor(assignment.completionRate).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${assignment.completionRate.toStringAsFixed(0)}%',
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: ScoreColors.getCompletionColor(assignment.completionRate),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Date info
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: context.colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Due: ${dateFormat.format(assignment.dueDate)}',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: assignment.isOverdue
                          ? context.colorScheme.error
                          : context.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ],
          ),
    );
  }

}

