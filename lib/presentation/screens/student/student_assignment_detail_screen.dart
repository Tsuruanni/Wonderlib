import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/extensions/context_extensions.dart';
import '../../../domain/repositories/student_assignment_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_assignment_provider.dart';

class StudentAssignmentDetailScreen extends ConsumerWidget {
  const StudentAssignmentDetailScreen({
    super.key,
    required this.assignmentId,
  });

  final String assignmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentAsync = ref.watch(studentAssignmentDetailProvider(assignmentId));

    return Scaffold(
      body: assignmentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: context.colorScheme.error),
              const SizedBox(height: 16),
              Text('Error loading assignment', style: context.textTheme.bodyLarge),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(studentAssignmentDetailProvider(assignmentId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (assignment) {
          if (assignment == null) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Assignment not found')),
            );
          }

          return _AssignmentDetailContent(assignment: assignment);
        },
      ),
    );
  }
}

class _AssignmentDetailContent extends ConsumerWidget {
  const _AssignmentDetailContent({required this.assignment});

  final StudentAssignment assignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('EEEE, MMMM d, y');
    final isCompleted = assignment.status == StudentAssignmentStatus.completed;

    return CustomScrollView(
      slivers: [
        // Header
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getTypeColor(assignment.type),
                    _getTypeColor(assignment.type).withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getTypeIcon(assignment.type),
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              assignment.type.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Title
                      Text(
                        assignment.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      if (assignment.teacherName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'From ${assignment.teacherName}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Status and progress
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(16),
            color: context.colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                // Status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status',
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            _getStatusIcon(assignment.status),
                            size: 18,
                            color: _getStatusColor(assignment.status),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            assignment.status.displayName,
                            style: context.textTheme.titleSmall?.copyWith(
                              color: _getStatusColor(assignment.status),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Progress
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Progress',
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: assignment.progress / 100,
                                backgroundColor: context.colorScheme.surface,
                                minHeight: 8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${assignment.progress.toStringAsFixed(0)}%',
                            style: context.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Score (if completed)
                if (isCompleted && assignment.score != null) ...[
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _getScoreColor(assignment.score!).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${assignment.score!.toStringAsFixed(0)}%',
                          style: context.textTheme.titleLarge?.copyWith(
                            color: _getScoreColor(assignment.score!),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Score',
                          style: context.textTheme.labelSmall?.copyWith(
                            color: _getScoreColor(assignment.score!),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Due date section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.event,
                      color: assignment.isOverdue
                          ? Colors.red
                          : context.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Due Date',
                            style: context.textTheme.labelSmall?.copyWith(
                              color: context.colorScheme.outline,
                            ),
                          ),
                          Text(
                            dateFormat.format(assignment.dueDate),
                            style: context.textTheme.titleSmall?.copyWith(
                              color: assignment.isOverdue ? Colors.red : null,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isCompleted) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: assignment.isOverdue
                              ? Colors.red.withValues(alpha: 0.1)
                              : context.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          assignment.isOverdue
                              ? 'Overdue'
                              : '${assignment.daysRemaining} days left',
                          style: context.textTheme.labelMedium?.copyWith(
                            color: assignment.isOverdue
                                ? Colors.red
                                : context.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),

        // Description
        if (assignment.description != null) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instructions',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        assignment.description!,
                        style: context.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // Content to complete
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What to Do',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (assignment.type == StudentAssignmentType.book ||
                    assignment.type == StudentAssignmentType.mixed) ...[
                  _ContentCard(
                    icon: Icons.menu_book,
                    title: 'Read assigned chapters',
                    subtitle: assignment.bookId != null
                        ? '${assignment.chapterIds.length} chapters'
                        : 'Book reading assignment',
                    color: Colors.blue,
                    onTap: assignment.bookId != null
                        ? () => _startReading(context, ref, assignment)
                        : null,
                  ),
                ],
                if (assignment.type == StudentAssignmentType.vocabulary ||
                    assignment.type == StudentAssignmentType.mixed) ...[
                  _ContentCard(
                    icon: Icons.abc,
                    title: 'Complete vocabulary practice',
                    subtitle: 'Learn and review words',
                    color: Colors.purple,
                    onTap: () {
                      // Navigate to vocabulary
                      context.go('/vocabulary');
                    },
                  ),
                ],
              ],
            ),
          ),
        ),

        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }

  void _startReading(BuildContext context, WidgetRef ref, StudentAssignment assignment) async {
    if (assignment.bookId == null) return;

    // Start the assignment if not started
    if (assignment.status == StudentAssignmentStatus.pending) {
      final userId = ref.read(currentUserIdProvider);
      if (userId != null) {
        final repo = ref.read(studentAssignmentRepositoryProvider);
        await repo.startAssignment(userId, assignment.assignmentId);
        ref.invalidate(studentAssignmentDetailProvider(assignment.assignmentId));
        ref.invalidate(studentAssignmentsProvider);
      }
    }

    // Navigate to book detail
    if (context.mounted) {
      context.push('/library/book/${assignment.bookId}');
    }
  }

  IconData _getTypeIcon(StudentAssignmentType type) {
    switch (type) {
      case StudentAssignmentType.book:
        return Icons.menu_book;
      case StudentAssignmentType.vocabulary:
        return Icons.abc;
      case StudentAssignmentType.mixed:
        return Icons.library_books;
    }
  }

  Color _getTypeColor(StudentAssignmentType type) {
    switch (type) {
      case StudentAssignmentType.book:
        return Colors.blue;
      case StudentAssignmentType.vocabulary:
        return Colors.purple;
      case StudentAssignmentType.mixed:
        return Colors.teal;
    }
  }

  IconData _getStatusIcon(StudentAssignmentStatus status) {
    switch (status) {
      case StudentAssignmentStatus.pending:
        return Icons.schedule;
      case StudentAssignmentStatus.inProgress:
        return Icons.play_circle;
      case StudentAssignmentStatus.completed:
        return Icons.check_circle;
      case StudentAssignmentStatus.overdue:
        return Icons.warning;
    }
  }

  Color _getStatusColor(StudentAssignmentStatus status) {
    switch (status) {
      case StudentAssignmentStatus.pending:
        return Colors.grey;
      case StudentAssignmentStatus.inProgress:
        return Colors.blue;
      case StudentAssignmentStatus.completed:
        return Colors.green;
      case StudentAssignmentStatus.overdue:
        return Colors.red;
    }
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

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
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
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
                    Text(
                      subtitle,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.arrow_forward,
                  color: color,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
