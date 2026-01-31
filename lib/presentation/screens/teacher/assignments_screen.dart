import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/extensions/context_extensions.dart';
import '../../../domain/repositories/teacher_repository.dart';
import '../../providers/teacher_provider.dart';

class AssignmentsScreen extends ConsumerWidget {
  const AssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(teacherAssignmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              context.push('/teacher/assignments/create');
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
          error: (error, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: context.colorScheme.error),
                const SizedBox(height: 16),
                Text('Error loading assignments', style: context.textTheme.bodyLarge),
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
                    const SizedBox(height: 8),
                    Text(
                      'Create your first assignment to get started',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () {
                        context.push('/teacher/assignments/create');
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Create Assignment'),
                    ),
                  ],
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
                if (active.isNotEmpty) ...[
                  _SectionHeader(title: 'Active', count: active.length),
                  ...active.map((a) => _AssignmentCard(
                    assignment: a,
                    onTap: () => context.push('/teacher/assignments/${a.id}'),
                  )),
                  const SizedBox(height: 16),
                ],
                if (upcoming.isNotEmpty) ...[
                  _SectionHeader(title: 'Upcoming', count: upcoming.length),
                  ...upcoming.map((a) => _AssignmentCard(
                    assignment: a,
                    onTap: () => context.push('/teacher/assignments/${a.id}'),
                  )),
                  const SizedBox(height: 16),
                ],
                if (overdue.isNotEmpty) ...[
                  _SectionHeader(title: 'Past Due', count: overdue.length),
                  ...overdue.map((a) => _AssignmentCard(
                    assignment: a,
                    onTap: () => context.push('/teacher/assignments/${a.id}'),
                  )),
                ],
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/teacher/assignments/create');
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
