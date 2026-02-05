import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/extensions/context_extensions.dart';
import '../../../domain/entities/student_assignment.dart';
import '../../providers/student_assignment_provider.dart';
import '../../utils/ui_helpers.dart';
import '../../providers/student_assignment_provider.dart';

class StudentAssignmentsScreen extends ConsumerWidget {
  const StudentAssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(studentAssignmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Assignments'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(studentAssignmentsProvider);
        },
        child: assignmentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: context.colorScheme.error),
                const SizedBox(height: 16),
                Text('Error loading assignments', style: context.textTheme.bodyLarge),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.invalidate(studentAssignmentsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (assignments) {
            if (assignments.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      size: 64,
                      color: context.colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No assignments yet',
                      style: context.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your teacher will assign tasks here',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Group by status
            final active = assignments.where((a) =>
              a.status == StudentAssignmentStatus.pending ||
              a.status == StudentAssignmentStatus.inProgress,
            ).toList();

            final overdue = assignments.where((a) =>
              a.status == StudentAssignmentStatus.overdue,
            ).toList();

            final completed = assignments.where((a) =>
              a.status == StudentAssignmentStatus.completed,
            ).toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // To Do (first - active tasks)
                if (active.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'To Do',
                    count: active.length,
                    color: Colors.blue,
                  ),
                  ...active.map((a) => _AssignmentCard(
                    assignment: a,
                    onTap: () => _navigateToAssignment(context, a),
                  ),),
                  const SizedBox(height: 16),
                ],

                // Completed (middle)
                if (completed.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Completed',
                    count: completed.length,
                    color: Colors.green,
                  ),
                  ...completed.map((a) => _AssignmentCard(
                    assignment: a,
                    onTap: () => _navigateToAssignment(context, a),
                  ),),
                  const SizedBox(height: 16),
                ],

                // Overdue (last)
                if (overdue.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Overdue',
                    count: overdue.length,
                    color: Colors.red,
                  ),
                  ...overdue.map((a) => _AssignmentCard(
                    assignment: a,
                    onTap: () => _navigateToAssignment(context, a),
                  ),),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  void _navigateToAssignment(BuildContext context, StudentAssignment assignment) {
    context.push('/assignments/${assignment.assignmentId}');
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.color,
  });

  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
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
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: context.textTheme.labelSmall?.copyWith(
                color: color,
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

  final StudentAssignment assignment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d');
    final isCompleted = assignment.status == StudentAssignmentStatus.completed;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Type icon with status
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: StudentAssignmentColors.getTypeColor(assignment.type).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      StudentAssignmentColors.getTypeIcon(assignment.type),
                      color: StudentAssignmentColors.getTypeColor(assignment.type),
                      size: 24,
                    ),
                  ),
                  if (isCompleted)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignment.title,
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: assignment.isOverdue
                              ? Colors.red
                              : context.colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          assignment.isOverdue
                              ? 'Overdue'
                              : 'Due ${dateFormat.format(assignment.dueDate)}',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: assignment.isOverdue
                                ? Colors.red
                                : context.colorScheme.outline,
                          ),
                        ),
                        if (assignment.teacherName != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.person,
                            size: 12,
                            color: context.colorScheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              assignment.teacherName!,
                              style: context.textTheme.bodySmall?.copyWith(
                                color: context.colorScheme.outline,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (!isCompleted && assignment.progress > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: assignment.progress / 100,
                                backgroundColor: context.colorScheme.surfaceContainerHighest,
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${assignment.progress.toStringAsFixed(0)}%',
                            style: context.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Score or action
              if (isCompleted && assignment.score != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: ScoreColors.getScoreColor(assignment.score!).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${assignment.score!.toStringAsFixed(0)}%',
                    style: context.textTheme.titleSmall?.copyWith(
                      color: ScoreColors.getScoreColor(assignment.score!),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ] else ...[
                Icon(
                  Icons.chevron_right,
                  color: context.colorScheme.outline,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

}
