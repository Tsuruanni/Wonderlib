import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/extensions/context_extensions.dart';
import '../../../../domain/repositories/teacher_repository.dart';
import '../../../providers/teacher_provider.dart';
import '../../../widgets/common/stat_item.dart';

class AssignmentReportScreen extends ConsumerWidget {
  const AssignmentReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(teacherAssignmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignment Performance'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(teacherAssignmentsProvider);
        },
        child: assignmentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: context.colorScheme.error),
                const SizedBox(height: 16),
                Text('Error loading data', style: context.textTheme.bodyLarge),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.invalidate(teacherAssignmentsProvider),
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
                Card(
                  color: context.colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
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
                ...assignments.map((assignment) => _AssignmentReportCard(
                  assignment: assignment,
                  onTap: () => context.push('/teacher/assignments/${assignment.id}'),
                )),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Type icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getTypeColor(assignment.type).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getTypeIcon(assignment.type),
                      color: _getTypeColor(assignment.type),
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
                  _StatusBadge(assignment: assignment),
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: assignment.completionRate / 100,
                            backgroundColor: context.colorScheme.surfaceContainerHighest,
                            color: _getCompletionColor(assignment.completionRate),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Completion percentage
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getCompletionColor(assignment.completionRate).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${assignment.completionRate.toStringAsFixed(0)}%',
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _getCompletionColor(assignment.completionRate),
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
        ),
      ),
    );
  }

  IconData _getTypeIcon(AssignmentType type) {
    switch (type) {
      case AssignmentType.book:
        return Icons.menu_book;
      case AssignmentType.vocabulary:
        return Icons.abc;
      case AssignmentType.mixed:
        return Icons.library_books;
    }
  }

  Color _getTypeColor(AssignmentType type) {
    switch (type) {
      case AssignmentType.book:
        return Colors.blue;
      case AssignmentType.vocabulary:
        return Colors.purple;
      case AssignmentType.mixed:
        return Colors.teal;
    }
  }

  Color _getCompletionColor(double rate) {
    if (rate >= 80) return Colors.green;
    if (rate >= 50) return Colors.orange;
    return Colors.red;
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
      color = Colors.blue;
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
