import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router.dart';
import '../../../core/utils/extensions/context_extensions.dart';
import '../../../domain/repositories/teacher_repository.dart';
import '../../providers/teacher_provider.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/error_state_widget.dart';
import '../../widgets/common/playful_card.dart';
import '../../widgets/common/responsive_layout.dart';

class AssignmentsScreen extends ConsumerWidget {
  const AssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(teacherAssignmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignments'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              context.push(AppRoutes.teacherCreateAssignment);
            },
            tooltip: 'Create Assignment',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(teacherAssignmentsProvider);
        },
        child: assignmentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ErrorStateWidget(
            message: 'Error loading assignments',
            onRetry: () => ref.invalidate(teacherAssignmentsProvider),
          ),
          data: (assignments) {
            if (assignments.isEmpty) {
              return EmptyStateWidget(
                icon: Icons.assignment_outlined,
                title: 'No assignments yet',
                subtitle: 'Create your first assignment to get started',
                action: FilledButton.icon(
                  onPressed: () {
                    context.push(AppRoutes.teacherCreateAssignment);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create Assignment'),
                ),
              );
            }

            // Group assignments by status
            final active = assignments.where((a) => a.isActive).toList();
            final upcoming = assignments.where((a) => a.isUpcoming).toList();
            final overdue = assignments.where((a) => a.isOverdue).toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ResponsiveConstraint(
                  maxWidth: 900,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                if (active.isNotEmpty) ...[
                  _SectionHeader(title: 'Active', count: active.length),
                  ResponsiveWrap(
                    minItemWidth: 280,
                    children: active
                        .map(
                          (a) => _AssignmentCard(
                            assignment: a,
                            onTap: () => context.push(
                              AppRoutes.teacherAssignmentDetailPath(a.id),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                if (upcoming.isNotEmpty) ...[
                  _SectionHeader(title: 'Upcoming', count: upcoming.length),
                  ResponsiveWrap(
                    minItemWidth: 280,
                    children: upcoming
                        .map(
                          (a) => _AssignmentCard(
                            assignment: a,
                            onTap: () => context.push(
                              AppRoutes.teacherAssignmentDetailPath(a.id),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                if (overdue.isNotEmpty) ...[
                  _SectionHeader(title: 'Past Due', count: overdue.length),
                  ResponsiveWrap(
                    minItemWidth: 280,
                    children: overdue
                        .map(
                          (a) => _AssignmentCard(
                            assignment: a,
                            onTap: () => context.push(
                              AppRoutes.teacherAssignmentDetailPath(a.id),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_new_assignment',
        onPressed: () {
          context.push(AppRoutes.teacherCreateAssignment);
        },
        icon: const Icon(Icons.add),
        label: const Text('New Assignment'),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
  });

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: context.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.assignment,
    required this.onTap,
  });

  final Assignment assignment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, y');

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

              // Title and class
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
                    if (assignment.className != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        assignment.className!,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.outline,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Status indicator
              _StatusBadge(assignment: assignment),
            ],
          ),

          const SizedBox(height: 12),

          // Progress bar and stats
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: assignment.completionRate / 100,
                        backgroundColor: context.colorScheme.surfaceContainerHighest,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${assignment.completedStudents}/${assignment.totalStudents} completed',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Due date
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Due',
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colorScheme.outline,
                    ),
                  ),
                  Text(
                    dateFormat.format(assignment.dueDate),
                    style: context.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: assignment.isOverdue
                          ? context.colorScheme.error
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.assignment});

  final Assignment assignment;

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;

    if (assignment.isOverdue) {
      color = Colors.red;
      text = 'Overdue';
    } else if (assignment.isUpcoming) {
      color = Colors.orange;
      text = 'Upcoming';
    } else {
      color = Colors.green;
      text = 'Active';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: context.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
